"""
DepartureOptimizer: "mejor momento para salir" multi-objetivo.

Combina 4 dimensiones sobre una ventana temporal:
- Tiempo de viaje (menos mejor)
- Costo en MXN (menos mejor)
- AQI a lo largo de la ruta (menor mejor)
- Exposición personal = AQI * duración * factor_vulnerabilidad

Score final = normalización inversa de cada eje + pesos dinámicos por perfil.

Depende de:
- OSRM (tiempo base)
- FuelService (costo y L)
- PredictionService (PM2.5 forecast por hora)
- Perfil vulnerabilidad (asmático, embarazada, etc.) para ajustar pesos
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from adapters.router.osrm_client import OSRMClient
from application.fuel import VehicleProfile, FuelService
from application.air.aggregator import AirQualityAggregator
from application.air.prediction_service import PredictionService
from adapters.air.openmeteo_provider import OpenMeteoProvider

logger = logging.getLogger(__name__)


DEFAULT_TRAFFIC_FACTORS = {
    # Hora del día → multiplicador de duración OSRM (aproximado CDMX)
    0: 0.85, 1: 0.80, 2: 0.80, 3: 0.80, 4: 0.85, 5: 0.95,
    6: 1.15, 7: 1.45, 8: 1.55, 9: 1.35, 10: 1.10, 11: 1.05,
    12: 1.10, 13: 1.20, 14: 1.25, 15: 1.35, 16: 1.45, 17: 1.60,
    18: 1.75, 19: 1.65, 20: 1.35, 21: 1.15, 22: 1.00, 23: 0.95,
}


class DepartureOptimizer:
    """Simula diferentes horarios de salida y sugiere el óptimo."""

    def __init__(
        self,
        osrm_client=None,
        fuel_service=None,
        air_aggregator=None,
        air_predictor=None,
    ):
        self.osrm = osrm_client or OSRMClient()
        self.fuel_service = fuel_service or FuelService(weather_provider=OpenMeteoProvider())
        self.aggregator = air_aggregator or AirQualityAggregator()
        self.predictor = air_predictor or PredictionService()

    # ── API pública ──────────────────────────────────────────────────────────
    def suggest_windows(
        self,
        origin: tuple,
        destination: tuple,
        vehicle: VehicleProfile,
        earliest: datetime,
        latest: datetime,
        step_min: int = 30,
        user_profile: Optional[dict] = None,
    ) -> dict:
        """
        Evalúa ventanas de salida cada step_min minutos entre earliest y latest.
        Retorna: {
          "windows": [...],
          "best": {...},
          "worst": {...},
          "savings_if_best": {...}
        }
        """
        if latest <= earliest:
            raise ValueError("latest debe ser > earliest")

        profile = user_profile or {}
        vuln_multiplier = self._vulnerability_multiplier(profile)
        weights = self._weights_for_profile(profile)

        logger.info(
            "departure.suggest_windows origin=%s dest=%s vehicle=%s window=%s..%s step=%dmin vuln=%.1f weights=%s",
            origin, destination, vehicle.display_name,
            earliest.isoformat(), latest.isoformat(), step_min, vuln_multiplier, weights,
        )

        # 1. OSRM base: una sola llamada, reutilizable para todas las ventanas
        route = self._route_safe([origin, destination])
        if route:
            base_distance_km = route["distance"] / 1000
            base_duration_min = route["duration"] / 60
            geometry = route["geometry"]
            logger.info("departure.suggest_windows using OSRM route: %.2fkm %.1fmin",
                        base_distance_km, base_duration_min)
        else:
            # Fallback heurístico: Haversine + velocidad promedio urbana CDMX
            logger.warning("departure.suggest_windows OSRM unavailable, using Haversine fallback")
            base_distance_km = self._haversine_km(origin, destination) * 1.35  # factor urbano
            base_duration_min = (base_distance_km / 28.0) * 60  # 28 km/h promedio CDMX
            geometry = self._simple_polyline([origin, destination])

        # 2. AQI actual en midpoint (para predicciones relativas)
        mid_lat, mid_lon = self._midpoint(origin, destination)
        try:
            current_aqi = self.aggregator.get_combined(mid_lat, mid_lon).get("combined_aqi", 75)
        except Exception:
            current_aqi = 75

        # 3. Iterar ventanas
        windows = []
        t = earliest
        while t <= latest:
            win = self._evaluate_window(
                t,
                geometry=geometry,
                base_distance_km=base_distance_km,
                base_duration_min=base_duration_min,
                vehicle=vehicle,
                midpoint=(mid_lat, mid_lon),
                current_aqi=current_aqi,
                vuln_multiplier=vuln_multiplier,
            )
            windows.append(win)
            t += timedelta(minutes=step_min)

        logger.info("departure.suggest_windows generated %d windows", len(windows))

        # 4. Scoring normalizado
        scored = self._normalize_and_score(windows, weights)

        # 5. Mejor y peor
        best = min(scored, key=lambda w: w["rank"])
        worst = max(scored, key=lambda w: w["rank"])
        now_window = scored[0]  # earliest == "ahora"

        savings = {
            "pesos": round(now_window["pesos_cost"] - best["pesos_cost"], 2),
            "minutes": round(now_window["duration_min"] - best["duration_min"], 1),
            "exposure_pct": self._pct_reduction(now_window["exposure_index"],
                                                best["exposure_index"]),
            "co2_kg": round(now_window["co2_kg"] - best["co2_kg"], 3),
        }

        logger.info(
            "departure.best rank=%d at=%s score=%.1f $=%.2f min=%.1f aqi=%d | savings: $%.2f %.1fmin %d%%exp",
            best["rank"], best["depart_at"], best["score"], best["pesos_cost"],
            best["duration_min"], best["aqi_avg"],
            savings["pesos"], savings["minutes"], savings["exposure_pct"],
        )

        return {
            "origin": {"lat": origin[0], "lon": origin[1]},
            "destination": {"lat": destination[0], "lon": destination[1]},
            "vehicle_display": vehicle.display_name,
            "vulnerability_multiplier": vuln_multiplier,
            "weights": weights,
            "windows": scored,
            "best": best,
            "worst": worst,
            "savings_if_best": savings,
            "recommendation": self._narrate_recommendation(best, now_window, savings),
        }

    # ── Internal ─────────────────────────────────────────────────────────────
    def _evaluate_window(
        self, depart_at: datetime, geometry: str,
        base_distance_km: float, base_duration_min: float,
        vehicle: VehicleProfile, midpoint: tuple, current_aqi: float,
        vuln_multiplier: float,
    ) -> dict:
        hour = depart_at.hour
        traffic_factor = DEFAULT_TRAFFIC_FACTORS.get(hour, 1.0)
        duration_min = base_duration_min * traffic_factor

        # Fuel estima con velocidad ajustada por tráfico
        try:
            fuel = self.fuel_service.score_polyline(
                encoded_polyline=geometry,
                vehicle=vehicle,
                duration_min=duration_min,
            )
        except Exception as exc:
            logger.warning("fuel estimate window failed: %s", exc)
            fuel = {"liters": 0, "pesos_cost": 0, "co2_kg": 0}

        # AQI predicho a la hora
        aqi = self._predict_aqi(midpoint, depart_at, current_aqi)
        exposure = aqi * (duration_min / 60) * vuln_multiplier

        return {
            "depart_at": depart_at.isoformat(),
            "hour": hour,
            "duration_min": round(duration_min, 1),
            "distance_km": round(base_distance_km, 2),
            "pesos_cost": round(fuel.get("pesos_cost", 0), 2),
            "liters": round(fuel.get("liters", 0), 2),
            "co2_kg": round(fuel.get("co2_kg", 0), 3),
            "aqi_avg": int(round(aqi)),
            "exposure_index": round(exposure, 1),
            "traffic_factor": round(traffic_factor, 2),
        }

    def _predict_aqi(self, point: tuple, when: datetime, fallback_aqi: float) -> float:
        """Usa PredictionService si disponible; si no, heurística hora-del-día."""
        try:
            if self.predictor and self.predictor.is_available:
                pred = self.predictor.predict_at(point[0], point[1], when=when)
                if pred and pred.get("aqi"):
                    return float(pred["aqi"])
        except Exception:
            pass

        # Heurística: AQI alto en horas pico de tráfico
        hour = when.hour
        hour_factor = 0.9 + (DEFAULT_TRAFFIC_FACTORS.get(hour, 1.0) - 1.0) * 0.3
        return max(10.0, fallback_aqi * hour_factor)

    def _normalize_and_score(self, windows: list, weights: dict) -> list:
        """Calcula score compuesto y rank."""
        if not windows:
            return []

        def norm_inv(values, v):
            """1 si v es el mínimo (mejor), 0 si el máximo."""
            lo = min(values)
            hi = max(values)
            if hi == lo:
                return 0.5
            return 1 - ((v - lo) / (hi - lo))

        durations = [w["duration_min"] for w in windows]
        costs = [w["pesos_cost"] for w in windows]
        aqis = [w["aqi_avg"] for w in windows]
        exposures = [w["exposure_index"] for w in windows]

        for w in windows:
            s_time = norm_inv(durations, w["duration_min"])
            s_cost = norm_inv(costs, w["pesos_cost"])
            s_aqi = norm_inv(aqis, w["aqi_avg"])
            s_exp = norm_inv(exposures, w["exposure_index"])

            score = (
                weights["time"] * s_time
                + weights["cost"] * s_cost
                + weights["aqi"] * s_aqi
                + weights["exposure"] * s_exp
            )
            w["score"] = round(score * 100, 1)
            w["sub_scores"] = {
                "time": round(s_time * 100, 1),
                "cost": round(s_cost * 100, 1),
                "aqi": round(s_aqi * 100, 1),
                "exposure": round(s_exp * 100, 1),
            }

        sorted_windows = sorted(windows, key=lambda x: x["score"], reverse=True)
        for i, w in enumerate(sorted_windows):
            w["rank"] = i + 1
        return sorted_windows

    def _narrate_recommendation(self, best, current, savings) -> str:
        """Genera un texto breve explicando la recomendación."""
        if best["depart_at"] == current["depart_at"]:
            return "Es un buen momento para salir ahora. El pronóstico no mejora significativamente."

        depart = datetime.fromisoformat(best["depart_at"])
        minutes_later = int(savings.get("minutes") or 0)

        parts = [f"Sal a las {depart.strftime('%H:%M')}."]
        if savings["pesos"] > 3:
            parts.append(f"Ahorrarás ${abs(int(savings['pesos']))} MXN")
        if minutes_later < 0:
            parts.append(f"y {abs(minutes_later)} min")
        if savings["exposure_pct"] > 10:
            parts.append(f"y reducirás tu exposición al aire contaminado {savings['exposure_pct']}%.")
        elif savings["exposure_pct"] > 0:
            parts.append(".")
        return " ".join(parts)

    # ── Helpers ──────────────────────────────────────────────────────────────
    def _route_safe(self, coords):
        try:
            routes = self.osrm.route(coords, profile="car", alternatives=0)
            return routes[0] if routes else None
        except Exception as exc:
            logger.warning("OSRM failed: %s", exc)
            return None

    @staticmethod
    def _midpoint(origin, dest):
        return ((origin[0] + dest[0]) / 2, (origin[1] + dest[1]) / 2)

    @staticmethod
    def _haversine_km(origin, dest):
        """Distancia en km entre dos (lat, lon)."""
        import math
        R = 6371
        lat1, lon1 = math.radians(origin[0]), math.radians(origin[1])
        lat2, lon2 = math.radians(dest[0]), math.radians(dest[1])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    @staticmethod
    def _simple_polyline(coords):
        """Codifica lista de (lat, lon) a formato Google Encoded Polyline (precision 5)."""
        import polyline
        return polyline.encode(coords, precision=5)

    @staticmethod
    def _vulnerability_multiplier(profile: dict) -> float:
        """
        Multiplicador de exposición (1.0 normal).
        Asma: 1.8, embarazada: 2.0, EPOC: 2.2, niño: 1.5, adulto mayor: 1.4
        """
        if profile.get("epoc"): return 2.2
        if profile.get("pregnancy"): return 2.0
        if profile.get("asthma"): return 1.8
        age = profile.get("age") or 35
        if age < 12: return 1.5
        if age >= 65: return 1.4
        return 1.0

    @staticmethod
    def _weights_for_profile(profile: dict) -> dict:
        """
        Dinamic weights: si hay vulnerabilidad, dar más peso a exposure/aqi.
        Suman 1.0.
        """
        if profile.get("asthma") or profile.get("epoc") or profile.get("pregnancy"):
            return {"time": 0.15, "cost": 0.15, "aqi": 0.25, "exposure": 0.45}
        return {"time": 0.25, "cost": 0.25, "aqi": 0.2, "exposure": 0.3}

    @staticmethod
    def _pct_reduction(from_val: float, to_val: float) -> int:
        if from_val <= 0:
            return 0
        pct = (from_val - to_val) / from_val * 100
        return int(round(pct))
