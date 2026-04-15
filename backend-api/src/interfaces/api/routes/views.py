# backend/interfaces/api/routes/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status as http_status
from datetime import datetime, timezone

from adapters.router.osrm_client import OSRMClient
from adapters.air.openaq_grid_provider import OpenAQGridProvider
from adapters.air.openmeteo_provider import OpenMeteoProvider
from application.routes.exposure import ExposureService
from application.air.aggregator import AirQualityAggregator
from adapters.ai.llm_service import LLMService


def _aqi_category(aqi: int) -> tuple:
    """Retorna (categoría, color) según el AQI."""
    if aqi <= 50:
        return "Bueno", "#00e400"
    elif aqi <= 100:
        return "Moderado", "#ffff00"
    elif aqi <= 150:
        return "Dañino para grupos sensibles", "#ff7e00"
    elif aqi <= 200:
        return "Dañino", "#ff0000"
    elif aqi <= 300:
        return "Muy dañino", "#8f3f97"
    else:
        return "Peligroso", "#7e0023"


class HealthCheckView(APIView):
    """Health check endpoint for Docker."""
    def get(self, request):
        return Response({"status": "healthy"}, status=http_status.HTTP_200_OK)


class CurrentAQIView(APIView):
    """
    Devuelve el AQI actual de una ubicación específica.
    GET /api/v1/air/current?lat=19.4326&lon=-99.1332
    """
    def get(self, request):
        try:
            lat = float(request.query_params.get("lat"))
            lon = float(request.query_params.get("lon"))
        except (TypeError, ValueError):
            return Response(
                {"error": "Parámetros inválidos. Usa 'lat' y 'lon'."},
                status=http_status.HTTP_400_BAD_REQUEST
            )

        air = OpenAQGridProvider()
        when = datetime.now(timezone.utc)
        
        try:
            data = air.get_aqi_cell(lat, lon, when)
            aqi = data.get("aqi", 0)
            category, color = _aqi_category(aqi)

            return Response({
                "location": {
                    "lat": lat,
                    "lon": lon
                },
                "timestamp": when.isoformat(),
                "aqi": aqi,
                "category": category,
                "color": color,
                "pollutants": {
                    "pm25": data.get("pm25"),
                    "o3": data.get("o3"),
                    "no2": data.get("no2"),
                }
            })
        except Exception as e:
            return Response(
                {"error": f"Error al obtener datos de calidad del aire: {str(e)}"},
                status=http_status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AirAnalysisView(APIView):
    """
    Análisis completo de calidad del aire con múltiples fuentes + IA.
    GET /api/v1/air/analysis?lat=19.4326&lon=-99.1332&mode=bike
    """
    def get(self, request):
        try:
            lat = float(request.query_params.get("lat"))
            lon = float(request.query_params.get("lon"))
        except (TypeError, ValueError):
            return Response(
                {"error": "Parámetros inválidos. Usa 'lat' y 'lon'."},
                status=http_status.HTTP_400_BAD_REQUEST,
            )

        mode = request.query_params.get("mode", "walk")
        if mode not in ("walk", "run", "bike"):
            return Response(
                {"error": "Modo inválido. Usa 'walk', 'run' o 'bike'."},
                status=http_status.HTTP_400_BAD_REQUEST,
            )

        try:
            # Paso 1: Agregar datos de múltiples fuentes
            aggregator = AirQualityAggregator()
            combined = aggregator.get_combined(lat, lon)

            # Paso 2: Obtener pronóstico de Open-Meteo
            meteo = OpenMeteoProvider()
            forecast = meteo.get_forecast(lat, lon, hours=24)

            # Paso 3: Análisis con IA
            llm = LLMService()
            ai_analysis = llm.analyze(combined, mode=mode, forecast=forecast)

            # Paso 4: Categoría AQI
            aqi = combined.get("combined_aqi", 0)
            category, color = _aqi_category(aqi)

            return Response({
                "location": {"lat": lat, "lon": lon},
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "combined_aqi": aqi,
                "category": category,
                "color": color,
                "confidence": combined.get("confidence", 0),
                "dominant_pollutant": combined.get("dominant_pollutant"),
                "sources": combined.get("sources", {}),
                "pollutants": combined.get("pollutants", {}),
                "ai_analysis": ai_analysis,
                "forecast": forecast[:12],
            })

        except Exception as e:
            return Response(
                {"error": f"Error en análisis de calidad del aire: {str(e)}"},
                status=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class OptimalRouteView(APIView):
    """
    Devuelve una única ruta óptima: balance entre distancia y contaminación del aire.
    Usa el agregador multi-fuente para datos de AQI más confiables.
    """
    def get(self, request):
        try:
            lat1 = float(request.query_params.get("origin_lat"))
            lon1 = float(request.query_params.get("origin_lon"))
            lat2 = float(request.query_params.get("dest_lat"))
            lon2 = float(request.query_params.get("dest_lon"))
        except (TypeError, ValueError):
            return Response({"error": "Parámetros inválidos. Usa origin_lat, origin_lon, dest_lat, dest_lon."}, status=400)

        mode = request.query_params.get("mode", "bike")
        alpha = float(request.query_params.get("alpha", 0.5))  # peso distancia
        beta  = float(request.query_params.get("beta", 0.5))   # peso contaminación
        depart_at = datetime.now(timezone.utc)

        # Clientes — ahora con agregador multi-fuente
        router = OSRMClient()
        aggregator = AirQualityAggregator()
        exposure = ExposureService(aggregator)

        # Obtener rutas alternativas
        routes = router.route([(lon1, lat1), (lon2, lat2)], profile=mode, alternatives=3)
        if not routes:
            return Response({"error": "No se encontraron rutas alternativas."}, status=404)

        evaluations = []
        for r in routes:
            exp, max_aqi, segs = exposure.score_polyline(r["geometry"], mode, depart_at)
            avg_aqi = sum(s["aqi"] for s in segs) / len(segs) if segs else 0
            evaluations.append({
                "polyline": r["geometry"],
                "distance": r["distance"],
                "duration": r["duration"],
                "exposure_index": exp,
                "avg_aqi": avg_aqi,
            })

        # Normalización
        max_dist = max(e["distance"] for e in evaluations)
        max_exp = max(e["exposure_index"] for e in evaluations)
        min_dist = min(e["distance"] for e in evaluations)
        min_exp = min(e["exposure_index"] for e in evaluations)

        for e in evaluations:
            norm_dist = (e["distance"] - min_dist) / (max_dist - min_dist + 1e-9)
            norm_exp  = (e["exposure_index"] - min_exp) / (max_exp - min_exp + 1e-9)
            e["score"] = alpha * norm_dist + beta * norm_exp

        # Seleccionar la ruta con menor score combinado
        optimal = min(evaluations, key=lambda x: x["score"])

        # Análisis IA para la ruta óptima
        try:
            mid_lat = (lat1 + lat2) / 2
            mid_lon = (lon1 + lon2) / 2
            combined_air = aggregator.get_combined(mid_lat, mid_lon)
            llm = LLMService()
            ai_analysis = llm.analyze(combined_air, mode=mode)
        except Exception:
            ai_analysis = None

        return Response({
            "origin": [lon1, lat1],
            "destination": [lon2, lat2],
            "route": {
                "distance_km": round(optimal["distance"]/1000, 2),
                "duration_min": round(optimal["duration"]/60, 1),
                "exposure_index": round(optimal["exposure_index"], 1),
                "avg_aqi": round(optimal["avg_aqi"], 1),
                "score": round(optimal["score"], 3),
                "polyline": optimal["polyline"],
            },
            "weights": {"alpha_distance": alpha, "beta_air": beta},
            "air_quality": {
                "combined_aqi": combined_air.get("combined_aqi", 0) if ai_analysis else None,
                "confidence": combined_air.get("confidence", 0) if ai_analysis else None,
                "sources_count": combined_air.get("source_count", 0) if ai_analysis else None,
            },
            "ai_analysis": ai_analysis,
            "explanation": (
                "Ruta óptima entre distancia y aire limpio "
                f"(α={alpha}, β={beta}). "
                f"Datos de {combined_air.get('source_count', 0) if ai_analysis else 1} fuentes."
            ),
        })