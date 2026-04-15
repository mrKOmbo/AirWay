# backend/interfaces/api/ppi/urls.py
from django.urls import path
from .views import PPIContextView

urlpatterns = [
    path("ppi/context", PPIContextView.as_view(), name="ppi-context"),
]
