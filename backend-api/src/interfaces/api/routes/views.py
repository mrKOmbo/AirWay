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
from application.air.prediction_service import PredictionService
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

            # Paso 2: Obtener pronóstico y weather actual de Open-Meteo
            meteo = OpenMeteoProvider()
            forecast = meteo.get_forecast(lat, lon, hours=24)
            weather = meteo.get_current_weather(lat, lon)

            # Paso 3: Predicción ML (PM2.5 futuro)
            ml_prediction = None
            try:
                predictor = PredictionService()
                if predictor.is_available:
                    ml_prediction = predictor.predict(combined, weather, lat, lon)
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning(f"ML prediction error: {e}")

            # Paso 4: Análisis con IA (ahora incluye predicción ML)
            llm = LLMService()
            ai_analysis = llm.analyze(
                combined, mode=mode, forecast=forecast,
                ml_prediction=ml_prediction,
            )

            # Paso 5: Categoría AQI
            aqi = combined.get("combined_aqi", 0)
            category, color = _aqi_category(aqi)

            return Response({
                "location": {
                    "lat": lat,
                    "lon": lon,
                    "elevation_m": combined.get("user_elevation_m", 0),
                },
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "combined_aqi": aqi,
                "aqi_range": combined.get("aqi_range", {}),
                "category": category,
                "color": color,
                "confidence": combined.get("confidence", 0),
                "dominant_pollutant": combined.get("dominant_pollutant"),
                "sources": combined.get("sources", {}),
                "station_count": combined.get("station_count", 0),
                "stations": combined.get("stations", []),
                "pollutants": combined.get("pollutants", {}),
                "ml_prediction": ml_prediction,
                "ai_analysis": ai_analysis,
                "forecast": forecast[:12],
            })

        except Exception as e:
            return Response(
                {"error": f"Error en análisis de calidad del aire: {str(e)}"},
                status=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class AirHeatmapView(APIView):
    """
    Mapa de calor AQI: grilla de puntos con AQI interpolado.
    GET /api/v1/air/heatmap?lat=19.43&lon=-99.13&radius_km=8&resolution=15
    """
    def get(self, request):
        try:
            center_lat = float(request.query_params.get("lat"))
            center_lon = float(request.query_params.get("lon"))
        except (TypeError, ValueError):
            return Response(
                {"error": "Parámetros inválidos. Usa 'lat' y 'lon'."},
                status=http_status.HTTP_400_BAD_REQUEST,
            )

        radius_km = float(request.query_params.get("radius_km", 8))
        resolution = int(request.query_params.get("resolution", 15))
        resolution = min(resolution, 25)  # Cap para no sobrecargar

        try:
            # Obtener estaciones reales una sola vez
            aggregator = AirQualityAggregator()
            combined = aggregator.get_combined(center_lat, center_lon)
            stations = combined.get("stations", [])

            if not stations:
                return Response({"error": "Sin datos de estaciones"}, status=404)

            # Predicción ML para tendencia
            predictor = PredictionService()
            pred_1h_factor = 1.0
            if predictor.is_available:
                try:
                    meteo = OpenMeteoProvider()
                    weather = meteo.get_current_weather(center_lat, center_lon)
                    ml_pred = predictor.predict(combined, weather, center_lat, center_lon)
                    current = ml_pred.get("current_aqi", 1) or 1
                    pred_1h = ml_pred.get("predictions", {}).get("1h", {}).get("aqi", current)
                    pred_1h_factor = pred_1h / current if current > 0 else 1.0
                except Exception:
                    pass

            # Generar grilla
            import math
            deg_per_km = 1 / 111.0  # ~111 km por grado
            half = radius_km * deg_per_km
            step_lat = (2 * half) / resolution
            step_lon = (2 * half) / resolution

            grid = []
            for i in range(resolution):
                for j in range(resolution):
                    pt_lat = (center_lat - half) + i * step_lat + step_lat / 2
                    pt_lon = (center_lon - half) + j * step_lon + step_lon / 2

                    # IDW rápido usando las estaciones ya obtenidas
                    aqi = self._quick_idw(pt_lat, pt_lon, stations)
                    if aqi <= 0:
                        continue

                    predicted_1h = int(aqi * pred_1h_factor)
                    cat, color = _aqi_category(aqi)

                    grid.append({
                        "lat": round(pt_lat, 5),
                        "lon": round(pt_lon, 5),
                        "aqi": aqi,
                        "predicted_1h": predicted_1h,
                        "color": color,
                    })

            return Response({
                "center": {"lat": center_lat, "lon": center_lon},
                "radius_km": radius_km,
                "resolution": resolution,
                "grid_points": len(grid),
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "trend_factor": round(pred_1h_factor, 3),
                "grid": grid,
            })

        except Exception as e:
            return Response(
                {"error": f"Error generando heatmap: {str(e)}"},
                status=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    def _quick_idw(self, lat, lon, stations, power=2):
        """IDW rápido sin API calls — usa estaciones ya obtenidas."""
        from math import radians, sin, cos, atan2, sqrt
        numerator = 0.0
        denominator = 0.0

        for s in stations:
            aqi = s.get("aqi", 0)
            if aqi <= 0:
                continue

            # Haversine rápido
            R = 6371000
            dlat = radians(lat - s.get("lat", 0))
            dlon = radians(lon - s.get("lon", 0))
            a = sin(dlat/2)**2 + cos(radians(lat)) * cos(radians(s.get("lat", 0))) * sin(dlon/2)**2
            dist = max(2 * R * atan2(sqrt(a), sqrt(1-a)), 100)

            w = 1.0 / (dist ** power)
            w *= s.get("altitude_factor", 1.0)
            w *= s.get("wind_factor", 1.0)
            if s.get("is_outlier"):
                w *= 0.2
            if s.get("source_type") == "model":
                w *= 0.3

            numerator += aqi * w
            denominator += w

        return round(numerator / denominator) if denominator > 0 else 0


class BestTimeView(APIView):
    """
    Mejor hora para salir según predicción ML + forecast.
    GET /api/v1/air/best-time?lat=19.43&lon=-99.13&mode=bike&hours=12
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
        hours = min(int(request.query_params.get("hours", 12)), 24)

        try:
            # Forecast de Open-Meteo (hasta 5 días)
            meteo = OpenMeteoProvider()
            forecast = meteo.get_forecast(lat, lon, hours=hours)

            if not forecast:
                return Response(
                    {"error": "Sin datos de pronóstico disponibles"},
                    status=http_status.HTTP_404_NOT_FOUND,
                )

            # Clasificar cada hora
            hourly = []
            for entry in forecast[:hours]:
                aqi = entry.get("aqi", 0)
                cat, color = _aqi_category(aqi)

                if aqi <= 50:
                    rec = "ideal"
                elif aqi <= 75:
                    rec = "bueno"
                elif aqi <= 100:
                    rec = "aceptable"
                elif aqi <= 150:
                    rec = "precaución"
                else:
                    rec = "evitar"

                # Ajustar por modo de transporte
                if mode in ("run", "bike") and aqi > 100:
                    rec = "evitar"
                elif mode in ("run", "bike") and aqi > 75:
                    rec = "precaución"

                hourly.append({
                    "time": entry.get("time", ""),
                    "aqi": aqi,
                    "category": cat,
                    "color": color,
                    "recommendation": rec,
                })

            # Encontrar mejor y peor ventana (ventana de 2 horas)
            best_window = None
            worst_window = None
            best_avg = 999
            worst_avg = 0

            for i in range(len(hourly) - 1):
                window_avg = (hourly[i]["aqi"] + hourly[i + 1]["aqi"]) / 2
                if window_avg < best_avg:
                    best_avg = window_avg
                    best_window = {
                        "start": hourly[i]["time"],
                        "end": hourly[i + 1]["time"],
                        "avg_aqi": round(window_avg),
                        "risk_level": "bajo" if window_avg <= 50 else "moderado" if window_avg <= 100 else "alto",
                    }
                if window_avg > worst_avg:
                    worst_avg = window_avg
                    worst_window = {
                        "start": hourly[i]["time"],
                        "end": hourly[i + 1]["time"],
                        "avg_aqi": round(window_avg),
                        "risk_level": "bajo" if window_avg <= 50 else "moderado" if window_avg <= 100 else "alto",
                    }

            # Resumen
            ideal_hours = [h["time"].split("T")[1][:5] if "T" in h["time"] else h["time"] for h in hourly if h["recommendation"] in ("ideal", "bueno")]
            avoid_hours = [h["time"].split("T")[1][:5] if "T" in h["time"] else h["time"] for h in hourly if h["recommendation"] == "evitar"]

            mode_label = {"walk": "caminar", "run": "correr", "bike": "bicicleta"}.get(mode, mode)
            summary = f"Para {mode_label}: "
            if ideal_hours:
                summary += f"mejores horas {ideal_hours[0]}-{ideal_hours[-1]}. "
            if avoid_hours:
                summary += f"Evitar {avoid_hours[0]}-{avoid_hours[-1]}."
            if not ideal_hours and not avoid_hours:
                summary += "condiciones aceptables todo el periodo."

            return Response({
                "location": {"lat": lat, "lon": lon},
                "mode": mode,
                "hours_analyzed": len(hourly),
                "best_window": best_window,
                "worst_window": worst_window,
                "summary": summary,
                "hourly": hourly,
            })

        except Exception as e:
            return Response(
                {"error": f"Error calculando mejor hora: {str(e)}"},
                status=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class AirPredictionView(APIView):
    """
    Predicción de calidad del aire con ML.
    GET /api/v1/air/prediction?lat=19.4326&lon=-99.1332&mode=bike
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

        try:
            # Datos actuales
            aggregator = AirQualityAggregator()
            combined = aggregator.get_combined(lat, lon)

            # Weather actual
            meteo = OpenMeteoProvider()
            weather = meteo.get_current_weather(lat, lon)

            # Predicción ML
            predictor = PredictionService()
            if not predictor.is_available:
                return Response({
                    "error": "Modelo de predicción no disponible",
                    "current_aqi": combined.get("combined_aqi", 0),
                }, status=http_status.HTTP_503_SERVICE_UNAVAILABLE)

            prediction = predictor.predict(combined, weather, lat, lon)

            # Categorías para cada horizonte
            for key, pred in prediction.get("predictions", {}).items():
                cat, color = _aqi_category(pred["aqi"])
                pred["category"] = cat
                pred["color"] = color

            # Análisis IA de la predicción
            llm = LLMService()
            ai_analysis = llm.analyze(
                combined, mode=mode, ml_prediction=prediction,
            )

            current_aqi = combined.get("combined_aqi", 0)
            current_cat, current_color = _aqi_category(current_aqi)

            return Response({
                "location": {"lat": lat, "lon": lon},
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "current": {
                    "aqi": current_aqi,
                    "category": current_cat,
                    "color": current_color,
                    "pm25": prediction.get("current_pm25"),
                },
                "prediction": prediction,
                "mode": mode,
                "ai_analysis": ai_analysis,
            })

        except Exception as e:
            return Response(
                {"error": f"Error en predicción: {str(e)}"},
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
        depart_in_min = int(request.query_params.get("depart_in", 0))
        depart_at = datetime.now(timezone.utc)

        # Clientes
        router = OSRMClient()
        aggregator = AirQualityAggregator()
        exposure = ExposureService(aggregator)

        # Predicción ML para AQI futuro
        predictor = PredictionService()
        ml_available = predictor.is_available

        # Obtener rutas alternativas
        routes = router.route([(lon1, lat1), (lon2, lat2)], profile=mode, alternatives=3)
        if not routes:
            return Response({"error": "No se encontraron rutas alternativas."}, status=404)

        evaluations = []
        for r in routes:
            exp, max_aqi, segs = exposure.score_polyline(r["geometry"], mode, depart_at)
            avg_aqi = sum(s["aqi"] for s in segs) / len(segs) if segs else 0

            # Predicción: estimar AQI al llegar al destino
            arrival_aqi = avg_aqi
            duration_min = r["duration"] / 60
            total_travel_min = depart_in_min + duration_min

            if ml_available and total_travel_min > 10:
                try:
                    mid_lat = (lat1 + lat2) / 2
                    mid_lon = (lon1 + lon2) / 2
                    mid_combined = aggregator.get_combined(mid_lat, mid_lon)
                    meteo = OpenMeteoProvider()
                    weather = meteo.get_current_weather(mid_lat, mid_lon)
                    pred = predictor.predict(mid_combined, weather, mid_lat, mid_lon)
                    preds = pred.get("predictions", {})

                    # Interpolar predicción según tiempo de viaje
                    if total_travel_min <= 60 and "1h" in preds:
                        frac = total_travel_min / 60
                        arrival_aqi = int(avg_aqi * (1 - frac) + preds["1h"]["aqi"] * frac)
                    elif total_travel_min <= 180 and "3h" in preds:
                        frac = total_travel_min / 180
                        arrival_aqi = int(avg_aqi * (1 - frac) + preds["3h"]["aqi"] * frac)
                    elif "6h" in preds:
                        frac = min(total_travel_min / 360, 1.0)
                        arrival_aqi = int(avg_aqi * (1 - frac) + preds["6h"]["aqi"] * frac)
                except Exception:
                    pass  # Fallback a avg_aqi actual

            evaluations.append({
                "polyline": r["geometry"],
                "distance": r["distance"],
                "duration": r["duration"],
                "exposure_index": exp,
                "avg_aqi": avg_aqi,
                "predicted_arrival_aqi": arrival_aqi,
            })

        # Normalización — usar AQI predicho para el scoring
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

        # Análisis IA para la ruta óptima con predicción
        combined_air = None
        ml_prediction = None
        try:
            mid_lat = (lat1 + lat2) / 2
            mid_lon = (lon1 + lon2) / 2
            combined_air = aggregator.get_combined(mid_lat, mid_lon)

            if ml_available:
                meteo = OpenMeteoProvider()
                weather = meteo.get_current_weather(mid_lat, mid_lon)
                ml_prediction = predictor.predict(combined_air, weather, mid_lat, mid_lon)

            llm = LLMService()
            ai_analysis = llm.analyze(combined_air, mode=mode, ml_prediction=ml_prediction)
        except Exception:
            ai_analysis = None

        return Response({
            "origin": [lon1, lat1],
            "destination": [lon2, lat2],
            "route": {
                "distance_km": round(optimal["distance"]/1000, 2),
                "duration_min": round(optimal["duration"]/60, 1),
                "exposure_index": round(optimal["exposure_index"], 1),
                "avg_aqi_now": round(optimal["avg_aqi"], 1),
                "predicted_arrival_aqi": round(optimal.get("predicted_arrival_aqi", optimal["avg_aqi"]), 1),
                "score": round(optimal["score"], 3),
                "polyline": optimal["polyline"],
            },
            "weights": {"alpha_distance": alpha, "beta_air": beta},
            "air_quality": {
                "combined_aqi": combined_air.get("combined_aqi", 0) if combined_air else None,
                "confidence": combined_air.get("confidence", 0) if combined_air else None,
                "sources_count": combined_air.get("source_count", 0) if combined_air else None,
            },
            "ml_prediction": ml_prediction,
            "ai_analysis": ai_analysis,
            "explanation": (
                "Ruta óptima entre distancia y aire limpio "
                f"(α={alpha}, β={beta}). "
                f"AQI actual={round(optimal['avg_aqi'], 1)}, "
                f"predicho al llegar={round(optimal.get('predicted_arrival_aqi', optimal['avg_aqi']), 1)}."
            ),
        })