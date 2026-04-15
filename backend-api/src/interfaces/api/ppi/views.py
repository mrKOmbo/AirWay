# backend/interfaces/api/ppi/views.py
#
# PPI Context Endpoint
#
# Provides air quality context enriched with estimated biometric impact
# based on dose-response relationships from epidemiological literature.
#
# Scientific basis for dose-response coefficients:
#   SpO2:  ~0.01 pp drop per 1 µg/m³ PM2.5 (Steubenville Cohort, PMC3987810)
#   HRV:   ~0.09% SDNN decrease per 1 µg/m³ PM2.5 (Meta-analysis, 33 panel studies)
#   HR:    ~0.084 bpm increase per 1 µg/m³ PM2.5 (PMC11796267)
#   Resp:  ~0.035% increase per 1 µg/m³ PM2.5 (AI-Respire, arXiv:2505.10556)
#

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status as http_status
from datetime import datetime, timezone

from application.air.aggregator import AirQualityAggregator
from adapters.ai.llm_service import LLMService


# Dose-response coefficients (per 1 µg/m³ PM2.5)
DOSE_RESPONSE = {
    "spo2_drop_per_pm25": 0.010,     # percentage points
    "hrv_decrease_pct_per_pm25": 0.09,  # percent
    "hr_increase_per_pm25": 0.084,    # bpm
    "resp_increase_pct_per_pm25": 0.035,  # percent
}

# Additional pollutant contributions (per 1 ppb)
NO2_HR_INCREASE_PER_PPB = 0.35
O3_HR_INCREASE_PER_PPB = 0.41
O3_HRV_DECREASE_PCT_PER_PPB = 0.33

# Risk level thresholds for estimated PPI
PPI_RISK_THRESHOLDS = {
    "low": (0, 25),
    "moderate": (25, 50),
    "high": (50, 75),
    "very_high": (75, 100),
}


def _estimate_biometric_impact(pollutants: dict, aqi: int) -> dict:
    """
    Estimate expected biometric deviations from baseline given current
    pollutant concentrations. Based on peer-reviewed dose-response data.
    """
    pm25 = pollutants.get("pm25", {}).get("value", 0) or 0
    no2 = pollutants.get("no2", {}).get("value", 0) or 0
    o3 = pollutants.get("o3", {}).get("value", 0) or 0

    # SpO2 drop: primarily from PM2.5
    spo2_drop = pm25 * DOSE_RESPONSE["spo2_drop_per_pm25"]

    # HRV decrease: PM2.5 + O3 contributions
    hrv_decrease = (
        pm25 * DOSE_RESPONSE["hrv_decrease_pct_per_pm25"]
        + o3 * O3_HRV_DECREASE_PCT_PER_PPB
    )

    # HR increase: PM2.5 + NO2 + O3
    hr_increase = (
        pm25 * DOSE_RESPONSE["hr_increase_per_pm25"]
        + no2 * NO2_HR_INCREASE_PER_PPB
        + o3 * O3_HR_INCREASE_PER_PPB
    )

    # Respiratory rate increase: primarily from PM2.5
    resp_increase = pm25 * DOSE_RESPONSE["resp_increase_pct_per_pm25"]

    return {
        "spo2_drop_estimate_pp": round(spo2_drop, 2),
        "hrv_decrease_estimate_pct": round(hrv_decrease, 1),
        "hr_increase_estimate_bpm": round(hr_increase, 1),
        "resp_increase_estimate_pct": round(resp_increase, 1),
    }


def _estimate_ppi_range(impact: dict) -> dict:
    """
    Estimate what PPI score range to expect for a healthy adult
    given the estimated biometric impact.
    """
    # Rough mapping using sigmoid midpoints from the mobile app
    spo2_contribution = min(100, max(0, impact["spo2_drop_estimate_pp"] / 3.0 * 50)) * 0.35
    hrv_contribution = min(100, max(0, impact["hrv_decrease_estimate_pct"] / 25.0 * 50)) * 0.30
    hr_contribution = min(100, max(0, impact["hr_increase_estimate_bpm"] / 12.0 * 50)) * 0.20
    resp_contribution = min(100, max(0, impact["resp_increase_estimate_pct"] / 20.0 * 50)) * 0.15

    estimated = spo2_contribution + hrv_contribution + hr_contribution + resp_contribution
    estimated = min(100, max(0, estimated))

    # Determine risk level
    risk_level = "low"
    for level, (low, high) in PPI_RISK_THRESHOLDS.items():
        if low <= estimated < high:
            risk_level = level
            break

    return {
        "estimated_ppi_healthy": round(estimated),
        "estimated_ppi_asthmatic": round(min(100, estimated * 1.5)),
        "estimated_ppi_copd": round(min(100, estimated * 1.8)),
        "estimated_ppi_cvd": round(min(100, estimated * 1.5)),
        "risk_level": risk_level,
    }


def _ppi_recommendation(aqi: int, risk_level: str) -> str:
    """Generate a human-readable recommendation in Spanish."""
    if risk_level == "low":
        return (
            "Calidad del aire aceptable. Tu cuerpo no debería mostrar "
            "efectos significativos. Actividades normales recomendadas."
        )
    elif risk_level == "moderate":
        return (
            "Impacto moderado esperado. Personas con condiciones respiratorias "
            "podrían notar efectos leves. Considera reducir actividad intensa al aire libre."
        )
    elif risk_level == "high":
        return (
            "Impacto alto esperado. Se recomienda limitar la exposición prolongada. "
            "Grupos sensibles deberían evitar actividad física al exterior."
        )
    else:
        return (
            "Impacto muy alto esperado. Todos deberían minimizar la exposición exterior. "
            "Personas con condiciones respiratorias o cardiovasculares: permanecer en interiores."
        )


class PPIContextView(APIView):
    """
    GET /api/v1/ppi/context?lat=19.4326&lon=-99.1332

    Returns air quality context enriched with estimated biometric impact
    based on dose-response relationships from epidemiological literature.

    Used by the Apple Watch PPI engine to correlate expected vs. actual
    biometric deviations: if your actual SpO2 drop is 3x the expected,
    your body is responding more than average → higher PPI score.
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

        try:
            # Get multi-source aggregated air quality
            aggregator = AirQualityAggregator()
            combined = aggregator.get_combined(lat, lon)

            aqi = combined.get("combined_aqi", 0)
            pollutants = combined.get("pollutants", {})
            dominant = combined.get("dominant_pollutant", "pm25")
            confidence = combined.get("confidence", 0)
            elevation = combined.get("user_elevation_m", 0)

            # Calculate estimated biometric impact
            impact = _estimate_biometric_impact(pollutants, aqi)

            # Estimate PPI ranges for different populations
            ppi_estimates = _estimate_ppi_range(impact)

            # Generate recommendation
            recommendation = _ppi_recommendation(aqi, ppi_estimates["risk_level"])

            # Check for thermal inversion risk (high altitude + calm conditions)
            thermal_inversion_risk = False
            stations = combined.get("stations", [])
            if stations and elevation:
                elevations = [s.get("elevation_m", 0) for s in stations if s.get("elevation_m")]
                if elevations:
                    max_elev_diff = max(abs(e - elevation) for e in elevations)
                    thermal_inversion_risk = max_elev_diff > 200

            # Get AQI trend from forecast if available
            try:
                from adapters.air.openmeteo_provider import OpenMeteoProvider
                meteo = OpenMeteoProvider()
                forecast = meteo.get_forecast(lat, lon, hours=6)
                if forecast and len(forecast) >= 2:
                    current_aqi = forecast[0].get("aqi", aqi)
                    future_aqi = forecast[-1].get("aqi", aqi)
                    if future_aqi > current_aqi * 1.15:
                        trend = "worsening"
                    elif future_aqi < current_aqi * 0.85:
                        trend = "improving"
                    else:
                        trend = "stable"
                else:
                    trend = "unknown"
            except Exception:
                trend = "unknown"

            return Response({
                "location": {"lat": lat, "lon": lon},
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "air_quality": {
                    "aqi": aqi,
                    "dominant_pollutant": dominant,
                    "confidence": confidence,
                    "pollutants": {
                        k: {"value": round(v.get("value", 0), 1), "unit": v.get("unit", "")}
                        for k, v in pollutants.items()
                        if v.get("value") is not None
                    },
                },
                "expected_biometric_impact": impact,
                "ppi_estimates": ppi_estimates,
                "risk_factors": {
                    "altitude_m": elevation,
                    "thermal_inversion_risk": thermal_inversion_risk,
                    "trend": trend,
                },
                "recommendation": recommendation,
                "dose_response_sources": {
                    "spo2": "Steubenville Cohort (PMC3987810)",
                    "hrv": "Meta-analysis of 33 panel studies (Springer 2020)",
                    "hr": "COPD Resting HR Study (PMC11796267)",
                    "resp": "AI-Respire Framework (arXiv:2505.10556)",
                },
            })

        except Exception as e:
            return Response(
                {"error": f"Error en contexto PPI: {str(e)}"},
                status=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
