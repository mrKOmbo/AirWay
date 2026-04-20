"use client";

import { useEffect, useRef, useState } from "react";
import mapboxgl from "mapbox-gl";
import polyline from "@mapbox/polyline";
import "mapbox-gl/dist/mapbox-gl.css";
import { MAPBOX_STYLE, MAPBOX_TOKEN } from "@/lib/mapbox";
import type { AirHeatmap, RouteOptimal } from "@/lib/api/schemas";
import { aqiMeta } from "@/lib/aqi";
import { cn } from "@/lib/utils";

mapboxgl.accessToken = MAPBOX_TOKEN;

interface AirwayMapProps {
  center: { lat: number; lon: number } | null;
  heatmap?: AirHeatmap;
  routes?: Array<{
    id: string;
    label: string;
    color: string;
    route: RouteOptimal;
  }>;
  destination?: { lat: number; lon: number } | null;
  className?: string;
}

export function AirwayMap({
  center,
  heatmap,
  routes,
  destination,
  className,
}: AirwayMapProps) {
  const mapContainer = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapboxgl.Map | null>(null);
  const markersRef = useRef<mapboxgl.Marker[]>([]);
  const [mapReady, setMapReady] = useState(false);
  const [tokenMissing] = useState(!MAPBOX_TOKEN);

  // ---- Initialize map (once center is available) ----
  useEffect(() => {
    if (!mapContainer.current || mapRef.current || tokenMissing || !center)
      return;

    const map = new mapboxgl.Map({
      container: mapContainer.current,
      style: MAPBOX_STYLE,
      center: [center.lon, center.lat],
      zoom: 11.4,
      pitch: 38,
      bearing: -12,
      antialias: true,
      attributionControl: false,
      cooperativeGestures: true, // requires ctrl+wheel to zoom, keeps page scroll smooth
    });
    mapRef.current = map;

    // Extra safety: disable wheel zoom entirely, keep +/- controls for zooming.
    map.scrollZoom.disable();

    map.addControl(
      new mapboxgl.NavigationControl({ showCompass: false, visualizePitch: true }),
      "top-right",
    );

    map.on("load", () => {
      setMapReady(true);
      map.setFog({
        color: "rgba(255, 255, 255, 0.9)",
        "horizon-blend": 0.1,
        "high-color": "#dbeafe",
        "space-color": "#f1f5f9",
      });
      // Ensure canvas syncs with final container size after layout settles
      requestAnimationFrame(() => map.resize());
      setTimeout(() => map.resize(), 300);
    });

    // Observe container size changes and keep map in sync
    const resizeObserver = new ResizeObserver(() => {
      if (mapRef.current) mapRef.current.resize();
    });
    resizeObserver.observe(mapContainer.current);

    return () => {
      resizeObserver.disconnect();
      map.remove();
      mapRef.current = null;
      setMapReady(false);
    };
    // Re-run when center first becomes available — the mapRef guard above
    // prevents re-initialization on subsequent center updates.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tokenMissing, Boolean(center)]);

  // ---- Recenter when center changes ----
  useEffect(() => {
    if (!mapRef.current || !center || !mapReady) return;
    mapRef.current.flyTo({
      center: [center.lon, center.lat],
      zoom: 11.4,
      duration: 1600,
      essential: true,
    });
  }, [center, mapReady]);

  // ---- Heatmap layer ----
  useEffect(() => {
    if (!mapRef.current || !mapReady || !heatmap?.points.length) return;
    const map = mapRef.current;
    const sourceId = "aqi-heatmap-src";
    const circleLayerId = "aqi-heatmap-circles";
    const heatmapLayerId = "aqi-heatmap-layer";

    const geojson: GeoJSON.FeatureCollection = {
      type: "FeatureCollection",
      features: heatmap.points.map((p) => ({
        type: "Feature",
        geometry: { type: "Point", coordinates: [p.lon, p.lat] },
        properties: { aqi: p.aqi },
      })),
    };

    if (map.getSource(sourceId)) {
      (map.getSource(sourceId) as mapboxgl.GeoJSONSource).setData(geojson);
    } else {
      map.addSource(sourceId, { type: "geojson", data: geojson });

      map.addLayer({
        id: heatmapLayerId,
        type: "heatmap",
        source: sourceId,
        maxzoom: 15,
        paint: {
          "heatmap-weight": [
            "interpolate",
            ["linear"],
            ["get", "aqi"],
            0,
            0,
            50,
            0.25,
            100,
            0.6,
            200,
            0.9,
            300,
            1,
          ],
          "heatmap-intensity": ["interpolate", ["linear"], ["zoom"], 0, 1, 15, 3],
          "heatmap-color": [
            "interpolate",
            ["linear"],
            ["heatmap-density"],
            0,
            "rgba(0, 230, 118, 0)",
            0.2,
            "rgba(0, 230, 118, 0.5)",
            0.4,
            "rgba(255, 212, 0, 0.65)",
            0.6,
            "rgba(255, 143, 0, 0.75)",
            0.8,
            "rgba(255, 61, 61, 0.85)",
            1,
            "rgba(156, 39, 176, 0.9)",
          ],
          "heatmap-radius": ["interpolate", ["linear"], ["zoom"], 0, 6, 15, 70],
          "heatmap-opacity": 0.75,
        },
      });

      map.addLayer({
        id: circleLayerId,
        type: "circle",
        source: sourceId,
        minzoom: 12,
        paint: {
          "circle-radius": ["interpolate", ["linear"], ["zoom"], 12, 4, 16, 12],
          "circle-color": [
            "interpolate",
            ["linear"],
            ["get", "aqi"],
            0,
            "#00e676",
            50,
            "#ffd400",
            100,
            "#ff8f00",
            150,
            "#ff3d3d",
            200,
            "#9c27b0",
            300,
            "#6b0022",
          ],
          "circle-stroke-color": "#ffffff",
          "circle-stroke-width": 1.5,
          "circle-opacity": 0.9,
        },
      });
    }
  }, [heatmap, mapReady]);

  // ---- Routes layer ----
  useEffect(() => {
    if (!mapRef.current || !mapReady) return;
    const map = mapRef.current;

    // Clean previous route sources/layers
    ["cleanest", "fastest", "balanced"].forEach((id) => {
      if (map.getLayer(`route-${id}-shadow`)) map.removeLayer(`route-${id}-shadow`);
      if (map.getLayer(`route-${id}-main`)) map.removeLayer(`route-${id}-main`);
      if (map.getSource(`route-${id}-src`)) map.removeSource(`route-${id}-src`);
    });

    if (!routes?.length) return;

    routes.forEach(({ id, color, route }) => {
      const decoded = polyline.decode(route.route.polyline);
      const coords = decoded.map(([lat, lon]) => [lon, lat]);
      const geojson: GeoJSON.Feature<GeoJSON.LineString> = {
        type: "Feature",
        geometry: { type: "LineString", coordinates: coords },
        properties: { id },
      };
      map.addSource(`route-${id}-src`, { type: "geojson", data: geojson });

      // Shadow
      map.addLayer({
        id: `route-${id}-shadow`,
        type: "line",
        source: `route-${id}-src`,
        layout: { "line-cap": "round", "line-join": "round" },
        paint: {
          "line-color": "rgba(10, 29, 77, 0.2)",
          "line-width": 10,
          "line-blur": 4,
        },
      });

      // Main
      map.addLayer({
        id: `route-${id}-main`,
        type: "line",
        source: `route-${id}-src`,
        layout: { "line-cap": "round", "line-join": "round" },
        paint: {
          "line-color": color,
          "line-width": 5,
          "line-opacity": 0.95,
        },
      });
    });

    // Fit bounds around union of first route
    if (routes[0]) {
      const decoded = polyline.decode(routes[0].route.route.polyline);
      if (decoded.length > 1) {
        const bounds = decoded.reduce(
          (b, [lat, lon]) => b.extend([lon, lat]),
          new mapboxgl.LngLatBounds(),
        );
        map.fitBounds(bounds, { padding: 80, duration: 1200, pitch: 40 });
      }
    }
  }, [routes, mapReady]);

  // ---- Origin + destination markers ----
  useEffect(() => {
    if (!mapRef.current || !mapReady) return;
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    if (center) {
      const el = buildMarker("origin");
      markersRef.current.push(
        new mapboxgl.Marker({ element: el })
          .setLngLat([center.lon, center.lat])
          .addTo(mapRef.current),
      );
    }
    if (destination) {
      const el = buildMarker("destination");
      markersRef.current.push(
        new mapboxgl.Marker({ element: el })
          .setLngLat([destination.lon, destination.lat])
          .addTo(mapRef.current),
      );
    }
  }, [center, destination, mapReady]);

  if (tokenMissing) {
    return (
      <div
        className={cn(
          "relative w-full h-full min-h-[420px] rounded-[inherit] overflow-hidden flex items-center justify-center",
          "bg-gradient-to-br from-white via-aw-bg to-[#e8f0fa]",
          className,
        )}
      >
        <div className="text-center max-w-md p-6">
          <div className="aw-eyebrow">Mapbox offline</div>
          <p className="mt-2 text-sm text-aw-ink-soft">
            Falta <code className="aw-number">NEXT_PUBLIC_MAPBOX_TOKEN</code> en{" "}
            <code>.env.local</code>. El resto del dashboard funciona sin el mapa.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className={cn("relative w-full h-full", className)}>
      <div
        ref={mapContainer}
        className="w-full h-full rounded-[inherit] overflow-hidden"
      />
      {/* Fade-in overlay while map loads */}
      {!mapReady && (
        <div className="absolute inset-0 grid place-items-center bg-white/60 backdrop-blur-sm rounded-[inherit] pointer-events-none">
          <div className="aw-eyebrow">Cargando mapa…</div>
        </div>
      )}
    </div>
  );
}

function buildMarker(kind: "origin" | "destination") {
  const el = document.createElement("div");
  el.className = "airway-marker";
  const color = kind === "origin" ? "#0099ff" : "#0a1d4d";
  el.innerHTML = `
    <div style="
      position: relative;
      width: 20px; height: 20px;
      border-radius: 50%;
      background: ${color};
      box-shadow: 0 0 0 4px rgba(255,255,255,0.9), 0 6px 14px rgba(10,29,77,0.35);
    ">
      <div style="
        position: absolute; inset: -10px;
        border-radius: 50%;
        background: ${color};
        opacity: 0.25;
        animation: awPingOrigin 1.8s ease-out infinite;
      "></div>
    </div>
    <style>
      @keyframes awPingOrigin {
        0% { transform: scale(0.6); opacity: 0.5; }
        100% { transform: scale(2); opacity: 0; }
      }
    </style>
  `;
  // placeholder for possible tooltip; aqi-meta import retained for future use
  void aqiMeta;
  return el;
}
