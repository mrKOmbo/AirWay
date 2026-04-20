"use client";

import { useQuery } from "@tanstack/react-query";
import {
  compareTrip,
  getFuelPrices,
  searchFuelCatalog,
} from "@/lib/api/client";

export function useTripCompare(
  origin: { lat: number; lon: number } | null,
  destination: { lat: number; lon: number } | null,
  vehicle?: Record<string, unknown>,
) {
  return useQuery({
    queryKey: ["trip", "compare", origin, destination, vehicle],
    queryFn: () =>
      compareTrip({
        origin: origin!,
        destination: destination!,
        vehicle,
        include_ai_insight: true,
      }),
    enabled: !!origin && !!destination,
    staleTime: 10 * 60_000,
  });
}

export function useFuelPrices() {
  return useQuery({
    queryKey: ["fuel", "prices"],
    queryFn: getFuelPrices,
    staleTime: 30 * 60_000,
    refetchInterval: 30 * 60_000,
  });
}

export function useVehicleSearch(query: string, limit = 8) {
  return useQuery({
    queryKey: ["fuel", "catalog", "search", query, limit],
    queryFn: () => searchFuelCatalog({ q: query, limit }),
    enabled: query.length >= 2,
    staleTime: 5 * 60_000,
  });
}
