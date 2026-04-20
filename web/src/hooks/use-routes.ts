"use client";

import { useQueries } from "@tanstack/react-query";
import { getOptimalRoute } from "@/lib/api/client";

export type RouteFlavor = "cleanest" | "balanced" | "fastest";

export const ROUTE_PROFILES: Record<
  RouteFlavor,
  { alpha: number; beta: number; label: string; color: string }
> = {
  cleanest: {
    alpha: 0.15,
    beta: 0.85,
    label: "Más limpia",
    color: "#00e676",
  },
  balanced: {
    alpha: 0.5,
    beta: 0.5,
    label: "Balanceada",
    color: "#0099ff",
  },
  fastest: {
    alpha: 0.9,
    beta: 0.1,
    label: "Más rápida",
    color: "#ff8f00",
  },
};

export function useAlternativeRoutes(
  origin: { lat: number; lon: number } | null,
  destination: { lat: number; lon: number } | null,
  mode: "bike" | "walk" = "bike",
) {
  const flavors: RouteFlavor[] = ["cleanest", "balanced", "fastest"];

  const queries = useQueries({
    queries: flavors.map((flavor) => {
      const { alpha, beta } = ROUTE_PROFILES[flavor];
      return {
        queryKey: ["route", flavor, origin, destination, mode],
        queryFn: () =>
          getOptimalRoute({
            origin_lat: origin!.lat,
            origin_lon: origin!.lon,
            dest_lat: destination!.lat,
            dest_lon: destination!.lon,
            mode,
            alpha,
            beta,
          }),
        enabled: !!origin && !!destination,
        staleTime: 5 * 60_000,
      };
    }),
  });

  return flavors.map((flavor, i) => ({
    flavor,
    ...ROUTE_PROFILES[flavor],
    ...queries[i],
  }));
}

/** Small offset so we always have a demo destination ~3km NE from origin. */
export function demoDestination(origin: { lat: number; lon: number } | null) {
  if (!origin) return null;
  return {
    lat: origin.lat + 0.025,
    lon: origin.lon + 0.025,
  };
}
