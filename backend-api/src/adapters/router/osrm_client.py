import os
import requests


class OSRMClient:
    """
    Cliente simple para consultar el servicio OSRM (Open Source Routing Machine).
    URL configurable via env var OSRM_BASE_URL (default: servicio local docker).
    """

    def __init__(self, base_url: str | None = None):
        self.base_url = (
            base_url
            or os.getenv("OSRM_BASE_URL")
            or "http://osrm:5000"
        ).rstrip("/")

    def route(self, coords, profile="bike", alternatives=3):
        """
        Consulta OSRM para obtener rutas alternativas.

        Parámetros:
            coords: [(lon1, lat1), (lon2, lat2)]
            profile: "bike", "foot", "car"
            alternatives: número de rutas a considerar

        Retorna:
            Lista de diccionarios con 'geometry', 'distance', 'duration'
        """
        if len(coords) < 2:
            raise ValueError("Se necesitan al menos dos coordenadas (origen y destino)")

        coord_str = ";".join([f"{lon},{lat}" for lon, lat in coords])
        url = f"{self.base_url}/route/v1/{profile}/{coord_str}"
        params = {
            "alternatives": str(alternatives).lower(),
            "overview": "full",
            "geometries": "polyline6",  # codificación compacta
            "steps": "false",  # OSRM es case-sensitive, no admite False
        }

        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
        except Exception as e:
            raise RuntimeError(f"Error al conectar con OSRM: {e}")

        data = response.json()
        if "routes" not in data or not data["routes"]:
            raise RuntimeError("No se encontraron rutas válidas desde OSRM")

        return data["routes"]
