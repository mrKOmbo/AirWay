# backend/interfaces/api/routes/urls.py
from django.urls import path
from .views import OptimalRouteView, CurrentAQIView, AirAnalysisView, HealthCheckView

urlpatterns = [
    path("routes/optimal", OptimalRouteView.as_view(), name="routes-optimal"),
    path("air/current", CurrentAQIView.as_view(), name="air-current"),
    path("air/analysis", AirAnalysisView.as_view(), name="air-analysis"),
    path("healthz", HealthCheckView.as_view(), name="health-check"),
]
