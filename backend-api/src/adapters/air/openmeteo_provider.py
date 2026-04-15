# adapters/air/openmeteo_provider.py
"""
Proveedor de calidad del aire usando Open-Meteo.
- Sin API key, sin registro
- Cobertura global por coordenadas (modelo CAMS europeo/global)
- Pronóstico de 5 días + datos actuales
- Resolución ~11km (Europa) / ~45km (global)
"""
import requests
import logging
from datetime import datetime, timezone
from django.core.cache import cache

logger = logging.getLogger(__name__)

OPENMETEO_AQ_URL = "https://air-quality-api.open-meteo.com/v1/air-quality"


class OpenMeteoProvider:
    """Obtiene AQI actual desde Open-Meteo (modelo atmosférico CAMS)."""

    def __init__(self, ttl=300):
        self.ttl = ttl

    def get_aqi_cell(self, lat: float, lon: float, when: datetime) -> dict:
        when = (when or datetime.now(timezone.utc)).astimezone(timezone.utc)
        when = when.replace(minute=0, second=0, microsecond=0)

        key = f"openmeteo:{lat:.3f}:{lon:.3f}:{when.isoformat()}"
        cached = cache.get(key)
        if cached:
            logger.info(f"Open-Meteo cache hit: {key}")
            return cached

        try:
            params = {
                "latitude": lat,
                "longitude": lon,
                "current": "us_aqi,pm2_5,pm10,nitrogen_dioxide,ozone,sulphur_dioxide,carbon_monoxide",
                "timezone": "UTC",
            }

            logger.info(f"Open-Meteo request: {params}")
            r = requests.get(OPENMETEO_AQ_URL, params=params, timeout=10)
            r.raise_for_status()
            data = r.json()

            current = data.get("current", {})
            logger.info(f"Open-Meteo current data: {current}")

            payload = {
                "aqi": int(current.get("us_aqi") or 0),
                "pm25": current.get("pm2_5"),
                "pm10": current.get("pm10"),
                "no2": current.get("nitrogen_dioxide"),
                "o3": current.get("ozone"),
                "so2": current.get("sulphur_dioxide"),
                "co": current.get("carbon_monoxide"),
                "source": "open-meteo",
                "source_type": "model",
            }

            cache.set(key, payload, timeout=self.ttl)
            return payload

        except requests.exceptions.RequestException as e:
            logger.error(f"Open-Meteo API error: {e}")
            return {"aqi": 0, "pm25": None, "o3": None, "no2": None, "source": "open-meteo", "source_type": "model"}

    def get_forecast(self, lat: float, lon: float, hours: int = 24) -> list:
        """Obtiene pronóstico horario de calidad del aire (hasta 5 días)."""
        try:
            params = {
                "latitude": lat,
                "longitude": lon,
                "hourly": "us_aqi,pm2_5,pm10,nitrogen_dioxide,ozone",
                "forecast_days": min(hours // 24 + 1, 5),
                "timezone": "UTC",
            }

            r = requests.get(OPENMETEO_AQ_URL, params=params, timeout=10)
            r.raise_for_status()
            data = r.json()

            hourly = data.get("hourly", {})
            times = hourly.get("time", [])[:hours]
            forecast = []

            for i, t in enumerate(times):
                forecast.append({
                    "time": t,
                    "aqi": int(hourly.get("us_aqi", [0])[i] or 0),
                    "pm25": hourly.get("pm2_5", [None])[i],
                    "no2": hourly.get("nitrogen_dioxide", [None])[i],
                    "o3": hourly.get("ozone", [None])[i],
                })

            return forecast

        except requests.exceptions.RequestException as e:
            logger.error(f"Open-Meteo forecast error: {e}")
            return []
