"""
MultimodalRouter: compara auto vs Metro+caminata vs Uber vs bici para un trayecto.

Stack:
- Auto: OSRM (ya integrado) + FuelService (Fase 1)
- Metro/transit: heurística de distancia + tarifa CDMX. Fase 4.5: Mapbox transit API.
- Uber: fórmula tarifaria aprox (base + km + min). Sin API oficial.
- Bici: OSRM profile bike + factor inhalación.

Todos los costos en MXN. Exposición PM2.5 en gramos (negativa para bici porque inhala más).
"""
import logging
from typing import Optional

from adapters.router.osrm_client import OSRMClient
from application.fuel import FuelService, VehicleProfile
from application.fuel.physics_model import estimate_pesos_cost, DEFAULT_FUEL_PRICES_MXN_PER_L

logger = logging.getLogger(__name__)


# ── Constantes CDMX 2026 ────────────────────────────────────────────────────
METRO_FARE_MXN = 5.0
METROBUS_FARE_MXN = 6.0
CABLEBUS_FARE_MXN = 7.0
SUBURBANO_FARE_BASE = 18.0

# Uber CDMX tarifa aprox (2026)
UBER_BASE_FARE = 13.0
UBER_PER_KM = 8.20
UBER_PER_MIN = 1.15
UBER_MIN_FARE = 30.0

# Factores de emisión (kg CO2 por km)
METRO_CO2_PER_KM = 0.022   # incluye operación CFE
UBER_CO2_PER_KM = 0.22     # Uber CDMX SEDEMA promedio (auto + detour)
BIKE_CO2_PER_KM = 0.0

# Exposición PM2.5 (g por minuto) — ciclista respira ~2x vs peatón
BIKE_PM25_G_PER_MIN = 0.00020
WALK_PM25_G_PER_MIN = 0.00010
METRO_PM25_G_PER_MIN = 0.00014   # andén + vagón (polvo hierro)

# Depreciación + seguro + parking (MXN por km) — auto privado CDMX
CAR_HIDDEN_COST_PER_KM = 2.50


# ── Utilidades ──────────────────────────────────────────────────────────────
def _mode_result(
    mode: str,
    duration_min: float,
    distance_km: float,
    direct_cost: float,
    hidden_cost: float = 0.0,
    co2_kg: float = 0.0,
    pm25_g: float = 0.0,
    calories: int = 0,
    extra: Optional[dict] = None,
) -> dict:
    return {
        "mode": mode,
        "duration_min": round(duration_min, 1),
        "distance_km": round(distance_km, 2),
        "direct_cost_mxn": round(direct_cost, 2),
        "hidden_cost_mxn": round(hidden_cost, 2),
        "total_cost_mxn": round(direct_cost + hidden_cost, 2),
        "co2_kg": round(co2_kg, 3),
        "pm25_exposure_g": round(pm25_g, 4),
        "calories_burned": calories,
        **(extra or {}),
    }


# ── Router principal ────────────────────────────────────────────────────────
class MultimodalRouter:
    """Devuelve estimación para 4 modos de transporte."""

    def __init__(self, osrm_client=None, fuel_service=None):
        self.osrm = osrm_client or OSRMClient()
        self.fuel_service = fuel_service

    def compute_all(self, origin: tuple, dest: tuple, vehicle: Optional[VehicleProfile] = None) -> dict:
        """
        origin/dest: (lat, lon)
        vehicle: opcional. Si None, se usa un Nissan Versa 2019 por defecto.
        """
        logger.info("multimodal.compute_all origin=%s dest=%s vehicle=%s",
                    origin, dest, vehicle.display_name if vehicle else "default")

        if vehicle is None:
            vehicle = VehicleProfile(
                make="Nissan", model="Versa", year=2019,
                conuee_km_per_l=15.1, engine_cc=1600,
            )
            logger.debug("multimodal using default vehicle (Nissan Versa 2019)")

        car_r = self._route_safe([origin, dest], "car")
        bike_r = self._route_safe([origin, dest], "bike")

        if car_r:
            logger.debug("multimodal car route: %.2fkm %.1fmin",
                         car_r["distance"]/1000, car_r["duration"]/60)
        if bike_r:
            logger.debug("multimodal bike route: %.2fkm %.1fmin",
                         bike_r["distance"]/1000, bike_r["duration"]/60)

        result = {
            "origin": {"lat": origin[0], "lon": origin[1]},
            "destination": {"lat": dest[0], "lon": dest[1]},
            "modes": {
                "auto": self._score_car(car_r, vehicle),
                "metro": self._score_transit(car_r),  # fallback a distancia car
                "uber": self._score_uber(car_r),
                "bici": self._score_bike(bike_r),
            },
            "recommendation": self._build_recommendation(car_r, bike_r, vehicle),
        }

        logger.info(
            "multimodal result auto=$%.0f/%dmin metro=$%.0f/%dmin uber=$%.0f bici=%dmin/%dkcal rec=%s",
            result["modes"]["auto"].get("total_cost_mxn", 0),
            result["modes"]["auto"].get("duration_min", 0),
            result["modes"]["metro"].get("total_cost_mxn", 0),
            result["modes"]["metro"].get("duration_min", 0),
            result["modes"]["uber"].get("total_cost_mxn", 0),
            result["modes"]["bici"].get("duration_min", 0),
            result["modes"]["bici"].get("calories_burned", 0),
            result["recommendation"].get("mode_suggested", "?"),
        )
        return result

    # ── Score per-mode ───────────────────────────────────────────────────────
    def _score_car(self, route: dict, vehicle: VehicleProfile) -> dict:
        if not route:
            return _mode_result("auto", 0, 0, 0)

        distance_km = route["distance"] / 1000
        duration_min = route["duration"] / 60

        # Fuel cost via FuelService
        fuel_data = None
        try:
            service = self.fuel_service or FuelService()
            fuel_data = service.score_polyline(
                encoded_polyline=route["geometry"],
                vehicle=vehicle,
                duration_min=duration_min,
            )
        except Exception as exc:
            logger.debug("fuel service failed in multimodal: %s", exc)

        if fuel_data:
            direct = fuel_data["pesos_cost"]
            co2 = fuel_data["co2_kg"]
            pm25 = fuel_data.get("pm25_g", 0)
            liters = fuel_data["liters"]
        else:
            # Fallback rápido sin FuelService
            liters = distance_km / max(vehicle.conuee_km_per_l, 1)
            direct = estimate_pesos_cost(liters, vehicle.fuel_type)
            co2 = liters * 2.39
            pm25 = liters * 0.012

        tolls = self._estimate_tolls(route)
        parking = self._estimate_parking(route)
        depreciation = distance_km * CAR_HIDDEN_COST_PER_KM
        hidden = tolls + parking + depreciation

        return _mode_result(
            mode="auto",
            duration_min=duration_min,
            distance_km=distance_km,
            direct_cost=direct,
            hidden_cost=hidden,
            co2_kg=co2,
            pm25_g=pm25,
            calories=0,
            extra={
                "liters": round(liters, 2),
                "vehicle_display": vehicle.display_name,
                "tolls_mxn": round(tolls, 2),
                "parking_mxn": round(parking, 2),
                "depreciation_mxn": round(depreciation, 2),
            },
        )

    def _score_transit(self, car_route: dict) -> dict:
        """Aproximación: transit ~1.7x el tiempo en auto + 800m caminata."""
        if not car_route:
            return _mode_result("metro", 0, 0, 0)

        distance_km = car_route["distance"] / 1000
        # Transit tarda ~1.7x auto en CDMX en hora pico, ~1.3x fuera de hora
        transit_duration_min = (car_route["duration"] / 60) * 1.5
        walking_m = 800
        walking_min = walking_m / 83.33  # 5 km/h

        # Fare combinada: Metro + Metrobús típico
        fare = METRO_FARE_MXN + METROBUS_FARE_MXN

        return _mode_result(
            mode="metro",
            duration_min=transit_duration_min + walking_min,
            distance_km=distance_km,
            direct_cost=fare,
            hidden_cost=0,
            co2_kg=distance_km * METRO_CO2_PER_KM,
            pm25_g=(transit_duration_min * METRO_PM25_G_PER_MIN
                    + walking_min * WALK_PM25_G_PER_MIN),
            calories=int(walking_m * 0.05),
            extra={
                "walking_m": int(walking_m),
                "transit_transfers": 1,
                "fare_breakdown": {"metro": METRO_FARE_MXN, "metrobus": METROBUS_FARE_MXN},
            },
        )

    def _score_uber(self, car_route: dict) -> dict:
        if not car_route:
            return _mode_result("uber", 0, 0, 0)

        distance_km = car_route["distance"] / 1000
        duration_min = car_route["duration"] / 60

        price = UBER_BASE_FARE + (distance_km * UBER_PER_KM) + (duration_min * UBER_PER_MIN)
        price = max(price, UBER_MIN_FARE)

        return _mode_result(
            mode="uber",
            duration_min=duration_min,
            distance_km=distance_km,
            direct_cost=price,
            hidden_cost=0,
            co2_kg=distance_km * UBER_CO2_PER_KM,
            pm25_g=distance_km * 0.008,
            calories=0,
            extra={"surge_assumed": 1.0, "fare_note": "estimado, varía con demanda"},
        )

    def _score_bike(self, bike_route: dict) -> dict:
        if not bike_route:
            return _mode_result("bici", 0, 0, 0)

        distance_km = bike_route["distance"] / 1000
        duration_min = bike_route["duration"] / 60

        return _mode_result(
            mode="bici",
            duration_min=duration_min,
            distance_km=distance_km,
            direct_cost=0.0,
            hidden_cost=distance_km * 0.30,   # desgaste llantas + mantenimiento
            co2_kg=0.0,
            pm25_g=duration_min * BIKE_PM25_G_PER_MIN,
            calories=int(duration_min * 8),
            extra={
                "ecobici_available": True,
                "health_note": "Ciclista inhala 2× PM2.5 vs peatón",
            },
        )

    # ── Helpers ──────────────────────────────────────────────────────────────
    def _route_safe(self, coords, profile):
        """Intenta OSRM; si falla, usa Haversine como fallback."""
        logger.debug("multimodal._route_safe osrm profile=%s", profile)
        try:
            routes = self.osrm.route(coords, profile=profile, alternatives=0)
            if routes:
                return routes[0]
        except Exception as exc:
            logger.warning("multimodal.osrm %s failed: %s", profile, exc)

        # Fallback heurístico cuando OSRM no disponible (Render no lo tiene)
        logger.warning("multimodal using Haversine fallback for profile=%s", profile)
        dist_m = self._haversine_m(coords[0], coords[-1])
        # Factor por tipo de ruta (urbano CDMX)
        if profile == "bike":
            dist_m *= 1.3   # rutas ciclistas con desvíos
            speed_kmh = 15.0
        else:  # car
            dist_m *= 1.35  # rutas vehiculares con vueltas
            speed_kmh = 28.0
        duration_s = (dist_m / 1000) / speed_kmh * 3600
        return {
            "distance": dist_m,
            "duration": duration_s,
            "geometry": self._encode_polyline(coords),
        }

    @staticmethod
    def _haversine_m(a, b):
        import math
        R = 6371000
        lat1, lon1 = math.radians(a[0]), math.radians(a[1])
        lat2, lon2 = math.radians(b[0]), math.radians(b[1])
        dlat, dlon = lat2 - lat1, lon2 - lon1
        h = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
        return 2 * R * math.atan2(math.sqrt(h), math.sqrt(1 - h))

    @staticmethod
    def _encode_polyline(coords):
        import polyline
        return polyline.encode(coords, precision=5)

    @staticmethod
    def _estimate_tolls(route: dict) -> float:
        """Heurística muy simple: rutas >25 km en autopista asumen peaje."""
        km = route.get("distance", 0) / 1000
        if km > 30:
            return 30.0
        if km > 15:
            return 10.0
        return 0.0

    @staticmethod
    def _estimate_parking(route: dict) -> float:
        """Heurística: destino urbano = parking $25 MXN."""
        return 25.0

    # ── Recomendación narrativa ──────────────────────────────────────────────
    def _build_recommendation(self, car_route, bike_route, vehicle) -> dict:
        """Texto corto estilo 'Gemini light' sin depender del LLM."""
        km = (car_route or {}).get("distance", 0) / 1000
        min_car = (car_route or {}).get("duration", 0) / 60
        if km == 0:
            return {"mode_suggested": "unknown", "reason": "No se pudo calcular ruta"}

        if km < 3:
            return {
                "mode_suggested": "bici",
                "reason": f"Solo {km:.1f} km. La bici es más sana y gratis.",
            }
        if km < 8 and min_car > 25:
            return {
                "mode_suggested": "metro",
                "reason": f"El auto tomará {int(min_car)} min por tráfico; Metro es más barato.",
            }
        return {
            "mode_suggested": "auto",
            "reason": f"Auto razonable para {km:.1f} km. Revisa alternativas en tráfico pico.",
        }
