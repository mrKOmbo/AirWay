# application/air/aggregator.py
"""
Agregador multi-fuente de calidad del aire con IDW.
Consulta OpenAQ, Open-Meteo y WAQI en paralelo,
obtiene MÚLTIPLES estaciones por fuente, y aplica
Inverse Distance Weighting para interpolar el AQI
en el punto exacto del usuario.
"""
import logging
from math import radians, sin, cos, atan2, sqrt
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

from adapters.air.openaq_grid_provider import OpenAQGridProvider
from adapters.air.openmeteo_provider import OpenMeteoProvider
from adapters.air.waqi_provider import WAQIProvider
from adapters.air.elevation_service import ElevationService

# Para cálculo de bearing (dirección estación→usuario)
from math import atan2, degrees

logger = logging.getLogger(__name__)

# Radio por defecto para buscar estaciones (metros)
DEFAULT_RADIUS_KM = 10


def _haversine_m(lat1, lon1, lat2, lon2):
    """Distancia en metros entre dos puntos."""
    R = 6371000
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    return 2 * R * atan2(sqrt(a), sqrt(1 - a))


class AirQualityAggregator:
    """
    Agrega datos de múltiples fuentes y estaciones usando IDW.
    """

    def __init__(self):
        self.openaq = OpenAQGridProvider()
        self.openmeteo = OpenMeteoProvider()
        self.waqi = WAQIProvider()
        self.elevation = ElevationService()

    def get_combined(self, lat: float, lon: float, when: datetime = None) -> dict:
        """
        1. Obtiene estaciones cercanas de WAQI y OpenAQ en paralelo
        2. Obtiene dato de modelo de Open-Meteo
        3. Deduplica estaciones por proximidad
        4. Aplica IDW para interpolar AQI en el punto del usuario
        5. Calcula confianza, rango, y metadata
        """
        when = when or datetime.now(timezone.utc)

        # --- Paso 1: Obtener datos de todas las fuentes en paralelo ---
        waqi_stations = []
        openaq_stations = []
        meteo_data = None
        weather_data = None

        with ThreadPoolExecutor(max_workers=4) as executor:
            f_waqi = executor.submit(self._safe_call, self.waqi.get_stations_nearby, lat, lon, DEFAULT_RADIUS_KM)
            f_openaq = executor.submit(self._safe_call, self.openaq.get_stations_nearby, lat, lon, DEFAULT_RADIUS_KM * 1000)
            f_meteo = executor.submit(self._safe_call, self.openmeteo.get_aqi_cell, lat, lon, when)
            f_weather = executor.submit(self._safe_call, self.openmeteo.get_current_weather, lat, lon)

            waqi_stations = f_waqi.result() or []
            openaq_stations = f_openaq.result() or []
            meteo_data = f_meteo.result()
            weather_data = f_weather.result() or {}

        # --- Paso 2: Unificar todas las estaciones ---
        all_stations = []
        for s in waqi_stations:
            all_stations.append(s)
        for s in openaq_stations:
            all_stations.append(s)

        # --- Paso 3: Deduplicar por proximidad (<500m = misma estación) ---
        all_stations = self._deduplicate(all_stations)

        # --- Paso 4: Agregar Open-Meteo como estación virtual ---
        if meteo_data and meteo_data.get("aqi", 0) > 0:
            all_stations.append({
                "aqi": meteo_data["aqi"],
                "lat": lat,
                "lon": lon,
                "name": "Open-Meteo CAMS (modelo)",
                "distance_m": 0,
                "source": "open-meteo",
                "source_type": "model",
                "pm25": meteo_data.get("pm25"),
                "pm10": meteo_data.get("pm10"),
                "no2": meteo_data.get("no2"),
                "o3": meteo_data.get("o3"),
                "so2": meteo_data.get("so2"),
                "co": meteo_data.get("co"),
            })

        if not all_stations:
            return self._empty_result(lat, lon)

        # --- Paso 5: Enriquecer con altitud ---
        user_elevation = 0.0
        try:
            user_elevation, all_stations = self.elevation.enrich_stations_with_elevation(
                all_stations, lat, lon
            )
            # Calcular factor altitudinal para cada estación
            for s in all_stations:
                s["altitude_factor"] = self._altitude_weight(
                    user_elevation, s.get("elevation_m", 0)
                )
            logger.info(f"User elevation: {user_elevation}m, stations enriched")
        except Exception as e:
            logger.warning(f"Elevation enrichment failed, continuing without: {e}")
            for s in all_stations:
                s["elevation_m"] = 0.0
                s["altitude_factor"] = 1.0

        # --- Paso 6: Detectar outliers ---
        self._detect_outliers(all_stations)

        # --- Paso 6.5: Calcular factor eólico por estación ---
        wind_dir = weather_data.get("wind_direction_10m", None)
        wind_speed = weather_data.get("wind_speed_10m", 0)
        for s in all_stations:
            s["wind_factor"] = self._wind_factor(
                lat, lon, s.get("lat", 0), s.get("lon", 0),
                wind_dir, wind_speed,
            )

        # --- Paso 7: IDW con corrección altitudinal + eólica + outliers ---
        idw_aqi = self._idw_interpolate(all_stations, lat, lon)

        # --- Paso 8: Rango de confianza ---
        station_aqis = [s["aqi"] for s in all_stations if s.get("aqi", 0) > 0]
        aqi_range = {
            "low": min(station_aqis),
            "high": max(station_aqis),
            "spread": max(station_aqis) - min(station_aqis),
        }

        # --- Paso 9: Confianza ---
        confidence = self._calculate_confidence(all_stations, aqi_range)

        # --- Paso 9: Contaminantes (IDW por contaminante) ---
        pollutants = self._interpolate_pollutants(all_stations, lat, lon)

        # --- Paso 10: Contaminante dominante ---
        dominant = self._dominant_pollutant(pollutants)

        # --- Paso 11: Fuentes resumidas ---
        sources = self._summarize_sources(all_stations)

        return {
            "combined_aqi": idw_aqi,
            "aqi_range": aqi_range,
            "confidence": confidence,
            "sources": sources,
            "pollutants": pollutants,
            "dominant_pollutant": dominant,
            "source_count": len(sources),
            "station_count": len(all_stations),
            "stations": all_stations,
            "user_elevation_m": round(user_elevation),
            "location": {"lat": lat, "lon": lon},
            "weather": {
                "wind_speed": weather_data.get("wind_speed_10m", 0),
                "wind_direction": weather_data.get("wind_direction_10m", 0),
                "temperature": weather_data.get("temperature_2m", 0),
                "humidity": weather_data.get("relative_humidity_2m", 0),
            },
        }

    # ── IDW ──────────────────────────────────────────────────

    def _idw_interpolate(self, stations: list, target_lat: float, target_lon: float, power: float = 2) -> int:
        """
        Inverse Distance Weighting con corrección altitudinal.

        w_i = (1 / dist_i^p) × altitude_factor × source_factor

        - altitude_factor: reduce peso de estaciones en altitud muy diferente
        - source_factor: modelos atmosféricos pesan 0.3x vs estaciones reales
        """
        numerator = 0.0
        denominator = 0.0

        for s in stations:
            aqi = s.get("aqi", 0)
            if aqi <= 0:
                continue

            dist = s.get("distance_m", 0)
            if dist == 0:
                dist = _haversine_m(target_lat, target_lon, s.get("lat", 0), s.get("lon", 0))
            dist = max(dist, 100)

            w = 1.0 / (dist ** power)

            # Factor de altitud (Fase 2)
            w *= s.get("altitude_factor", 1.0)

            # Factor eólico: estaciones upwind pesan más
            w *= s.get("wind_factor", 1.0)

            # Factor de outlier (Fase 3) — no eliminar, solo reducir
            if s.get("is_outlier"):
                w *= 0.2

            # Factor de tipo de fuente
            if s.get("source_type") == "model":
                w *= 0.3

            numerator += aqi * w
            denominator += w

        if denominator == 0:
            return 0

        return round(numerator / denominator)

    def _interpolate_pollutants(self, stations: list, lat: float, lon: float) -> dict:
        """IDW con corrección altitudinal para cada contaminante."""
        pollutant_keys = ["pm25", "pm10", "no2", "o3", "so2", "co"]
        result = {}

        for key in pollutant_keys:
            numerator = 0.0
            denominator = 0.0
            count = 0

            for s in stations:
                val = s.get(key)
                if val is None:
                    continue

                dist = max(s.get("distance_m", 100), 100)
                w = 1.0 / (dist ** 2)
                w *= s.get("altitude_factor", 1.0)
                w *= s.get("wind_factor", 1.0)
                if s.get("is_outlier"):
                    w *= 0.2
                if s.get("source_type") == "model":
                    w *= 0.3

                numerator += val * w
                denominator += w
                count += 1

            if denominator > 0:
                result[key] = {
                    "value": round(numerator / denominator, 2),
                    "unit": "µg/m³",
                    "sources_reporting": count,
                }
            else:
                result[key] = None

        return result

    # ── Factor eólico ─────────────────────────────────────────

    def _wind_factor(self, user_lat, user_lon, station_lat, station_lon,
                     wind_dir, wind_speed):
        """
        Calcula factor eólico: estaciones upwind (viento sopla DESDE ella
        hacia el usuario) son más relevantes.

        wind_factor = 1.0 + 0.5 × cos(wind_direction - bearing_station_to_user)

        Rango: 0.5 (downwind, menos relevante) a 1.5 (upwind, más relevante)
        Con viento bajo (<2 m/s), el factor tiende a 1.0 (irrelevante).
        """
        if wind_dir is None or wind_speed < 1.5:
            return 1.0  # Sin viento significativo, factor neutral

        # Bearing de estación → usuario (dirección geográfica)
        dlat = radians(user_lat - station_lat)
        dlon = radians(user_lon - station_lon)
        x = sin(dlon) * cos(radians(user_lat))
        y = cos(radians(station_lat)) * sin(radians(user_lat)) - \
            sin(radians(station_lat)) * cos(radians(user_lat)) * cos(dlon)
        bearing = (degrees(atan2(x, y)) + 360) % 360

        # Diferencia angular entre dirección del viento y bearing
        angle_diff = radians(wind_dir - bearing)

        # cos(0) = 1.0: viento sopla en la misma dirección que station→user (upwind)
        # cos(180) = -1.0: viento sopla en dirección opuesta (downwind)
        alignment = cos(angle_diff)

        # Escalar por velocidad del viento (más viento = más efecto)
        # Normalizar: 5 m/s = efecto completo, <2 = poco efecto
        speed_factor = min(wind_speed / 5.0, 1.0)

        return 1.0 + 0.5 * alignment * speed_factor

    # ── Corrección altitudinal ─────────────────────────────────

    def _altitude_weight(self, user_elev: float, station_elev: float) -> float:
        """
        Reduce peso de estaciones con altitud muy diferente al usuario.

        La capa de inversión térmica en ciudades como CDMX divide
        la atmósfera en estratos con calidad del aire radicalmente diferente.
        Una estación por encima de la inversión (~2500m en CDMX) mide
        aire limpio que no es representativo del valle.

        Factores:
          ≤50m diff  → 1.0 (misma altitud, peso completo)
          ≤150m diff → 0.85 (similar, ligera reducción)
          ≤300m diff → 0.5 (diferente, reducción moderada)
          ≤500m diff → 0.25 (estrato diferente, reducción fuerte)
          >500m diff → 0.1 (otro mundo atmosférico)
        """
        if user_elev == 0 and station_elev == 0:
            return 1.0  # Sin datos de altitud, no penalizar

        diff = abs(user_elev - station_elev)

        if diff <= 50:
            return 1.0
        elif diff <= 150:
            return 0.85
        elif diff <= 300:
            return 0.5
        elif diff <= 500:
            return 0.25
        else:
            return 0.1

    # ── Detección de outliers ───────────────────────────────

    def _detect_outliers(self, stations: list):
        """
        Detecta estaciones con lecturas anómalas usando IQR.
        NO las elimina — les reduce el peso (0.2x) y las marca
        con is_outlier=True para que Gemini lo explique.

        Con menos de 4 estaciones no hay suficientes datos para IQR.
        """
        aqis = [s.get("aqi", 0) for s in stations if s.get("aqi", 0) > 0 and s.get("source_type") != "model"]

        if len(aqis) < 4:
            for s in stations:
                s["is_outlier"] = False
            return

        sorted_aqis = sorted(aqis)
        n = len(sorted_aqis)
        q1 = sorted_aqis[n // 4]
        q3 = sorted_aqis[3 * n // 4]
        iqr = q3 - q1

        # Límites: más permisivos que el estándar (1.5) porque
        # la variación espacial del AQI es naturalmente alta
        lower = q1 - 2.0 * iqr
        upper = q3 + 2.0 * iqr

        for s in stations:
            aqi = s.get("aqi", 0)
            if s.get("source_type") == "model":
                s["is_outlier"] = False
                continue

            if aqi < lower or aqi > upper:
                s["is_outlier"] = True
                logger.info(f"Outlier detectado: {s.get('name')} AQI={aqi} (rango={lower:.0f}-{upper:.0f})")
            else:
                s["is_outlier"] = False

    # ── Deduplicación ────────────────────────────────────────

    def _deduplicate(self, stations: list, min_distance_m: float = 500) -> list:
        """
        Elimina estaciones duplicadas (misma estación reportada por WAQI y OpenAQ).
        Si dos estaciones están a <500m, queda la que tiene más datos.
        """
        if len(stations) <= 1:
            return stations

        unique = []
        for s in stations:
            is_dup = False
            for u in unique:
                dist = _haversine_m(s.get("lat", 0), s.get("lon", 0), u.get("lat", 0), u.get("lon", 0))
                if dist < min_distance_m:
                    # Quedarse con la que tiene más datos de contaminantes
                    s_data = sum(1 for k in ["pm25", "no2", "o3"] if s.get(k) is not None)
                    u_data = sum(1 for k in ["pm25", "no2", "o3"] if u.get(k) is not None)
                    if s_data > u_data:
                        unique.remove(u)
                        unique.append(s)
                    is_dup = True
                    break
            if not is_dup:
                unique.append(s)

        return unique

    # ── Confianza ────────────────────────────────────────────

    def _calculate_confidence(self, stations: list, aqi_range: dict) -> float:
        """
        Confianza basada en:
        - Número de estaciones (más = mejor)
        - Spread del rango AQI (menor = más concordancia)
        - Presencia de estaciones reales
        """
        n = len(stations)
        if n == 0:
            return 0.0

        # Factor 1: Cobertura (0-0.35)
        coverage = min(n / 8.0, 1.0) * 0.35

        # Factor 2: Concordancia (0-0.40)
        spread = aqi_range.get("spread", 100)
        if spread <= 15:
            agreement = 0.40
        elif spread <= 30:
            agreement = 0.30
        elif spread <= 50:
            agreement = 0.20
        elif spread <= 80:
            agreement = 0.10
        else:
            agreement = 0.05

        # Factor 3: Estaciones reales cercanas (0-0.25)
        real_nearby = sum(
            1 for s in stations
            if s.get("source_type") == "station" and s.get("distance_m", 99999) < 5000
        )
        station_bonus = min(real_nearby / 3.0, 1.0) * 0.25

        return round(min(coverage + agreement + station_bonus, 1.0), 2)

    # ── Fuentes resumidas ────────────────────────────────────

    def _summarize_sources(self, stations: list) -> dict:
        """Agrupa estaciones por fuente para el resumen."""
        sources = {}
        for s in stations:
            src = s.get("source", "unknown")
            if src not in sources:
                sources[src] = {
                    "station_count": 0,
                    "stations": [],
                    "avg_aqi": 0,
                    "source_type": s.get("source_type", "unknown"),
                }

            sources[src]["station_count"] += 1
            sources[src]["stations"].append({
                "name": s.get("name", "Unknown"),
                "aqi": s.get("aqi", 0),
                "distance_km": round(s.get("distance_m", 0) / 1000, 1),
                "elevation_m": round(s.get("elevation_m", 0)),
                "altitude_factor": s.get("altitude_factor", 1.0),
                "is_outlier": s.get("is_outlier", False),
            })

        # Calcular promedio por fuente
        for src, info in sources.items():
            aqis = [st["aqi"] for st in info["stations"] if st["aqi"] > 0]
            info["avg_aqi"] = round(sum(aqis) / len(aqis)) if aqis else 0

        return sources

    # ── Contaminante dominante ────────────────────────────────

    def _dominant_pollutant(self, pollutants: dict) -> str:
        thresholds = {"pm25": 35.4, "pm10": 154.0, "no2": 100.0, "o3": 70.0, "so2": 75.0, "co": 9400.0}
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

    # ── Utilidades ────────────────────────────────────────────

    def _safe_call(self, fn, *args):
        try:
            return fn(*args)
        except Exception as e:
            logger.error(f"Safe call error: {e}")
            return None

    def _empty_result(self, lat: float, lon: float) -> dict:
        return {
            "combined_aqi": 0,
            "aqi_range": {"low": 0, "high": 0, "spread": 0},
            "confidence": 0.0,
            "sources": {},
            "pollutants": {},
            "dominant_pollutant": None,
            "source_count": 0,
            "station_count": 0,
            "stations": [],
            "location": {"lat": lat, "lon": lon},
        }
