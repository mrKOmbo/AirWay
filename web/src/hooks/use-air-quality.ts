"use client";

import { useQuery } from "@tanstack/react-query";
import {
  getAirAnalysis,
  getAirCurrent,
  getAirHeatmap,
  getBestTime,
  getContingencyForecast,
  getPPIContext,
} from "@/lib/api/client";

export function useAirCurrent(coords: { lat: number; lon: number } | null) {
  return useQuery({
    queryKey: ["air", "current", coords],
    queryFn: () => getAirCurrent(coords!),
    enabled: !!coords,
    staleTime: 5 * 60_000,
  });
}

export function useAirAnalysis(
  coords: { lat: number; lon: number } | null,
  mode: "walk" | "run" | "bike" = "walk",
) {
  return useQuery({
    queryKey: ["air", "analysis", coords, mode],
    queryFn: () => getAirAnalysis({ ...coords!, mode }),
    enabled: !!coords,
    staleTime: 5 * 60_000,
  });
}

export function useAirHeatmap(
  coords: { lat: number; lon: number } | null,
  radius_km = 8,
  resolution = 15,
) {
  return useQuery({
    queryKey: ["air", "heatmap", coords, radius_km, resolution],
    queryFn: () => getAirHeatmap({ ...coords!, radius_km, resolution }),
    enabled: !!coords,
    staleTime: 10 * 60_000,
  });
}

export function useBestTime(
  coords: { lat: number; lon: number } | null,
  mode: "walk" | "run" | "bike" = "walk",
  hours = 12,
) {
  return useQuery({
    queryKey: ["air", "best-time", coords, mode, hours],
    queryFn: () => getBestTime({ ...coords!, mode, hours }),
    enabled: !!coords,
    staleTime: 15 * 60_000,
  });
}

export function useContingencyForecast(
  coords: { lat: number; lon: number } | null,
) {
  return useQuery({
    queryKey: ["contingency", coords],
    queryFn: () => getContingencyForecast(coords!),
    enabled: !!coords,
    staleTime: 30 * 60_000,
  });
}

export function usePPIContext(coords: { lat: number; lon: number } | null) {
  return useQuery({
    queryKey: ["ppi", coords],
    queryFn: () => getPPIContext(coords!),
    enabled: !!coords,
    staleTime: 5 * 60_000,
  });
}
