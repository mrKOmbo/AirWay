# application/air/aggregator.py
"""
Agregador multi-fuente de calidad del aire.
Consulta OpenAQ, Open-Meteo y WAQI en paralelo,
pondera por confianza y devuelve un resultado combinado.
"""
import logging
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

from adapters.air.openaq_grid_provider import OpenAQGridProvider
from adapters.air.openmeteo_provider import OpenMeteoProvider
from adapters.air.waqi_provider import WAQIProvider

logger = logging.getLogger(__name__)

# Pesos de confianza por tipo de fuente
# Estaciones reales > modelos atmosféricos
WEIGHTS = {
    "openaq": 0.45,     # Estación real, red abierta
    "waqi": 0.35,       # Estación real, red global
    "open-meteo": 0.20, # Modelo atmosférico (CAMS)
}


class AirQualityAggregator:
    """
    Consulta múltiples fuentes de calidad del aire en paralelo
    y devuelve un resultado combinado con nivel de confianza.
    """

    def __init__(self):
        self.providers = {
            "openaq": OpenAQGridProvider(),
            "open-meteo": OpenMeteoProvider(),
            "waqi": WAQIProvider(),
        }

    def get_combined(self, lat: float, lon: float, when: datetime = None) -> dict:
        """
        Consulta todas las fuentes en paralelo y devuelve resultado combinado.

        Retorna:
        {
            "combined_aqi": int,
            "confidence": float (0-1),
            "sources": { nombre: {data, status, weight} },
            "pollutants": { pm25, no2, o3, ... },
            "dominant_pollutant": str,
            "source_count": int,
        }
        """
        when = when or datetime.now(timezone.utc)
        results = {}

        # Consultar todas las fuentes en paralelo
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = {
                executor.submit(self._safe_fetch, name, provider, lat, lon, when): name
                for name, provider in self.providers.items()
            }

            for future in as_completed(futures):
                name = futures[future]
                try:
                    data = future.result()
                    if data and data.get("aqi", 0) > 0:
                        results[name] = data
                        logger.info(f"[{name}] AQI={data['aqi']}")
                    else:
                        logger.warning(f"[{name}] sin datos válidos")
                except Exception as e:
                    logger.error(f"[{name}] error: {e}")

        if not results:
            logger.error("Ninguna fuente devolvió datos")
            return self._empty_result(lat, lon)

        return self._aggregate(results, lat, lon)

    def _safe_fetch(self, name: str, provider, lat: float, lon: float, when: datetime) -> dict:
        """Envuelve la llamada al proveedor con manejo de errores."""
        try:
            return provider.get_aqi_cell(lat, lon, when)
        except Exception as e:
            logger.error(f"[{name}] fetch error: {e}")
            return None

    def _aggregate(self, results: dict, lat: float, lon: float) -> dict:
        """Combina resultados ponderados de múltiples fuentes."""

        # --- AQI combinado (media ponderada) ---
        total_weight = 0
        weighted_aqi = 0
        source_details = {}

        for name, data in results.items():
            w = WEIGHTS.get(name, 0.1)
            aqi = data.get("aqi", 0)
            weighted_aqi += aqi * w
            total_weight += w

            source_details[name] = {
                "aqi": aqi,
                "status": "ok",
                "weight": w,
                "source_type": data.get("source_type", "unknown"),
                "station_name": data.get("station_name"),
            }

        combined_aqi = round(weighted_aqi / total_weight) if total_weight > 0 else 0

        # --- Contaminantes combinados (promedio de fuentes disponibles) ---
        pollutants = self._combine_pollutants(results)

        # --- Confianza ---
        confidence = self._calculate_confidence(results)

        # --- Contaminante dominante ---
        dominant = self._dominant_pollutant(pollutants)

        return {
            "combined_aqi": combined_aqi,
            "confidence": confidence,
            "sources": source_details,
            "pollutants": pollutants,
            "dominant_pollutant": dominant,
            "source_count": len(results),
            "location": {"lat": lat, "lon": lon},
        }

    def _combine_pollutants(self, results: dict) -> dict:
        """Promedia los valores de contaminantes de todas las fuentes."""
        pollutant_keys = ["pm25", "pm10", "no2", "o3", "so2", "co"]
        combined = {}

        for key in pollutant_keys:
            values = []
            for data in results.values():
                v = data.get(key)
                if v is not None:
                    values.append(v)

            if values:
                combined[key] = {
                    "value": round(sum(values) / len(values), 2),
                    "unit": "µg/m³",
                    "sources_reporting": len(values),
                }
            else:
                combined[key] = None

        return combined

    def _calculate_confidence(self, results: dict) -> float:
        """
        Calcula nivel de confianza (0-1) basado en:
        - Número de fuentes que respondieron
        - Concordancia entre ellas (desviación estándar)
        - Presencia de estaciones reales vs modelos
        """
        aqis = [d.get("aqi", 0) for d in results.values() if d.get("aqi", 0) > 0]

        if not aqis:
            return 0.0

        # Factor 1: cobertura de fuentes (0-0.4)
        coverage = min(len(aqis) / 3.0, 1.0) * 0.4

        # Factor 2: concordancia entre fuentes (0-0.4)
        if len(aqis) >= 2:
            mean = sum(aqis) / len(aqis)
            variance = sum((x - mean) ** 2 for x in aqis) / len(aqis)
            std_dev = variance ** 0.5
            # Si la desviación estándar es < 20 puntos AQI, alta concordancia
            agreement = max(0, 1 - std_dev / 50) * 0.4
        else:
            agreement = 0.15  # Solo una fuente, concordancia neutral

        # Factor 3: presencia de estaciones reales (0-0.2)
        has_station = any(
            d.get("source_type") == "station"
            for d in results.values()
            if d.get("aqi", 0) > 0
        )
        station_bonus = 0.2 if has_station else 0.05

        confidence = round(coverage + agreement + station_bonus, 2)
        return min(confidence, 1.0)

    def _dominant_pollutant(self, pollutants: dict) -> str:
        """Determina el contaminante dominante."""
        # Umbrales de referencia (µg/m³) para normalización
        thresholds = {
            "pm25": 35.4,
            "pm10": 154.0,
            "no2": 100.0,
            "o3": 70.0,
            "so2": 75.0,
            "co": 9400.0,
        }

        worst = None
        worst_ratio = 0

        for key, threshold in thresholds.items():
            entry = pollutants.get(key)
            if entry and entry.get("value") is not None:
                ratio = entry["value"] / threshold
                if ratio > worst_ratio:
                    worst_ratio = ratio
                    worst = key

        return worst

    def _empty_result(self, lat: float, lon: float) -> dict:
        return {
            "combined_aqi": 0,
            "confidence": 0.0,
            "sources": {},
            "pollutants": {},
            "dominant_pollutant": None,
            "source_count": 0,
            "location": {"lat": lat, "lon": lon},
        }
