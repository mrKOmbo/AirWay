"use client";

import { useEffect, useState } from "react";

export interface GeolocationState {
  coords: { lat: number; lon: number } | null;
  status: "idle" | "requesting" | "granted" | "denied" | "unavailable" | "error";
  error?: string;
  source: "gps" | "fallback" | null;
}

/** CDMX fallback (Zócalo) used when geolocation unavailable or denied */
export const CDMX_FALLBACK = { lat: 19.4326, lon: -99.1332 };

export function useGeolocation(options?: { autoRequest?: boolean }) {
  const autoRequest = options?.autoRequest ?? true;
  const [state, setState] = useState<GeolocationState>({
    coords: null,
    status: "idle",
    source: null,
  });

  useEffect(() => {
    if (!autoRequest) return;
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) {
      setState({
        coords: CDMX_FALLBACK,
        status: "unavailable",
        source: "fallback",
      });
      return;
    }

    setState((s) => ({ ...s, status: "requesting" }));

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setState({
          coords: { lat: pos.coords.latitude, lon: pos.coords.longitude },
          status: "granted",
          source: "gps",
        });
      },
      (err) => {
        setState({
          coords: CDMX_FALLBACK,
          status: err.code === err.PERMISSION_DENIED ? "denied" : "error",
          error: err.message,
          source: "fallback",
        });
      },
      { enableHighAccuracy: true, timeout: 8_000, maximumAge: 60_000 },
    );
  }, [autoRequest]);

  return state;
}
