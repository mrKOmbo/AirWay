# adapters/air/waqi_provider.py
"""
Proveedor de calidad del aire usando WAQI (World Air Quality Index).
- Token gratuito (https://aqicn.org/data-platform/token)
- Cobertura global: +11,000 estaciones
- Datos en tiempo real
- Hasta 1000 req/seg
"""
import os
import requests
import logging
from datetime import datetime, timezone
from django.core.cache import cache

logger = logging.getLogger(__name__)

WAQI_API_BASE = "https://api.waqi.info"


class WAQIProvider:
    """Obtiene AQI actual desde WAQI (estaciones de monitoreo reales)."""

    def __init__(self, ttl=300):
        self.ttl = ttl
        self.token = os.environ.get("WAQI_TOKEN", "")

    def get_aqi_cell(self, lat: float, lon: float, when: datetime) -> dict:
        when = (when or datetime.now(timezone.utc)).astimezone(timezone.utc)
        when = when.replace(minute=0, second=0, microsecond=0)

        key = f"waqi:{lat:.3f}:{lon:.3f}:{when.isoformat()}"
        cached = cache.get(key)
        if cached:
            logger.info(f"WAQI cache hit: {key}")
            return cached

        if not self.token:
            logger.warning("WAQI_TOKEN no configurado, saltando proveedor WAQI")
            return {"aqi": 0, "pm25": None, "o3": None, "no2": None, "source": "waqi", "source_type": "station"}

        try:
            # Endpoint por coordenadas geográficas
            url = f"{WAQI_API_BASE}/feed/geo:{lat};{lon}/"
            params = {"token": self.token}

            logger.info(f"WAQI request: geo:{lat};{lon}")
            r = requests.get(url, params=params, timeout=10)
            r.raise_for_status()
            body = r.json()

            if body.get("status") != "ok":
                logger.warning(f"WAQI status not ok: {body.get('status')}")
                return {"aqi": 0, "pm25": None, "o3": None, "no2": None, "source": "waqi", "source_type": "station"}

            data = body.get("data", {})
            iaqi = data.get("iaqi", {})

            # Extraer nombre y distancia de la estación
            city = data.get("city", {})
            station_name = city.get("name", "Unknown")
            station_geo = city.get("geo", [])

            logger.info(f"WAQI station: {station_name}")

            payload = {
                "aqi": int(data.get("aqi") or 0),
                "pm25": _extract(iaqi, "pm25"),
                "pm10": _extract(iaqi, "pm10"),
                "no2": _extract(iaqi, "no2"),
                "o3": _extract(iaqi, "o3"),
                "so2": _extract(iaqi, "so2"),
                "co": _extract(iaqi, "co"),
                "source": "waqi",
                "source_type": "station",
                "station_name": station_name,
                "station_coords": station_geo,
                "dominant_pollutant": data.get("dominentpol"),
            }

            cache.set(key, payload, timeout=self.ttl)
            return payload

        except requests.exceptions.RequestException as e:
            logger.error(f"WAQI API error: {e}")
            return {"aqi": 0, "pm25": None, "o3": None, "no2": None, "source": "waqi", "source_type": "station"}


def _extract(iaqi: dict, param: str):
    """Extrae valor de un contaminante del formato iaqi de WAQI."""
    entry = iaqi.get(param)
    if entry and isinstance(entry, dict):
        return entry.get("v")
    return None
