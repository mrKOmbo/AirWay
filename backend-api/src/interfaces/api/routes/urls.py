# backend/interfaces/api/routes/urls.py
from django.urls import path
from .views import (
    OptimalRouteView, CurrentAQIView, AirAnalysisView,
    AirPredictionView, AirHeatmapView, BestTimeView, HealthCheckView,
)

urlpatterns = [
    path("routes/optimal", OptimalRouteView.as_view(), name="routes-optimal"),
    path("air/current", CurrentAQIView.as_view(), name="air-current"),
    path("air/analysis", AirAnalysisView.as_view(), name="air-analysis"),
    path("air/prediction", AirPredictionView.as_view(), name="air-prediction"),
    path("air/heatmap", AirHeatmapView.as_view(), name="air-heatmap"),
    path("air/best-time", BestTimeView.as_view(), name="air-best-time"),
    path("healthz", HealthCheckView.as_view(), name="health-check"),
]
