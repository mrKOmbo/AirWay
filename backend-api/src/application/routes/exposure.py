import polyline, math
MODE_SPEED_KMH = {"walk": 4.8, "run": 9.0, "bike": 15.0}
MODE_INHAL = {"walk": 1.0, "run": 1.2, "bike": 0.9}

class ExposureService:
    """
    Calcula exposición acumulada a contaminantes a lo largo de una ruta.
    Acepta tanto un provider individual (OpenAQGridProvider) como
    el AirQualityAggregator — ambos implementan get_aqi_cell() o get_combined().
    """
    def __init__(self, grid_provider):
        self.grid = grid_provider
        # Detectar si es el agregador (tiene get_combined) o un provider simple
        self._is_aggregator = hasattr(grid_provider, 'get_combined')

    def _get_aqi(self, lat, lon, when):
        """Obtiene AQI de la fuente configurada."""
        if self._is_aggregator:
            result = self.grid.get_combined(lat, lon, when)
            return result.get("combined_aqi", 0)
        else:
            result = self.grid.get_aqi_cell(lat, lon, when)
            return result.get("aqi", 0)

    def _haversine_m(self, lat1, lon1, lat2, lon2):
        R=6371000; from math import radians, sin, cos, atan2, sqrt
        dlat=radians(lat2-lat1); dlon=radians(lon2-lon1)
        a=sin(dlat/2)**2+cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
        return 2*R*atan2(sqrt(1-a), math.sqrt(a))

    def score_polyline(self, encoded, mode, depart_at):
        pts = polyline.decode(encoded, precision=6)
        speed = MODE_SPEED_KMH[mode]*1000/3600
        exposure=0.0; max_aqi=0; segs=[]
        for (lat1,lon1),(lat2,lon2) in zip(pts[:-1], pts[1:]):
            dist = self._haversine_m(lat1,lon1,lat2,lon2)
            dur_s = max(1.0, dist/speed)
            latc, lonc = (lat1+lat2)/2, (lon1+lon2)/2
            aqi = int(round(self._get_aqi(latc, lonc, depart_at) or 0))
            max_aqi = max(max_aqi, aqi)
            seg_exp = aqi * (dur_s/60.0) * MODE_INHAL[mode]
            exposure += seg_exp
            segs.append({"from":[lon1,lat1],"to":[lon2,lat2],"len_m":int(dist),"dur_s":int(dur_s),
                         "aqi": aqi, "exposure": round(seg_exp,1)})
        return round(exposure,1), max_aqi, segs