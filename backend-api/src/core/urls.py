from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/', include("interfaces.api.routes.urls")),
    path('api/v1/', include("interfaces.api.ppi.urls")),
    path('healthz', include("interfaces.api.routes.urls"))
]
