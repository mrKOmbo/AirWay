import { z } from "zod";
import { apiUrl } from "./config";
import {
  AirAnalysisSchema,
  AirCurrentSchema,
  AirHeatmapSchema,
  BestTimeSchema,
  ContingencyForecastSchema,
  FuelPricesSchema,
  PPIContextSchema,
  RouteOptimalSchema,
  TripCompareSchema,
  VehicleSearchSchema,
  type AirAnalysis,
  type AirCurrent,
  type AirHeatmap,
  type BestTime,
  type ContingencyForecast,
  type FuelPrices,
  type PPIContext,
  type RouteOptimal,
  type TripCompare,
  type VehicleSearch,
} from "./schemas";

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly url: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function fetchJson<T>(
  url: string,
  schema: z.ZodType<T>,
  init?: RequestInit,
): Promise<T> {
  const res = await fetch(url, {
    headers: { Accept: "application/json", ...(init?.headers ?? {}) },
    cache: "no-store",
    ...init,
  });

  if (!res.ok) {
    let detail = res.statusText;
    try {
      const body = await res.json();
      detail = body.detail ?? body.error ?? JSON.stringify(body);
    } catch {
      /* ignore */
    }
    throw new ApiError(`[${res.status}] ${detail}`, res.status, url);
  }

  const json = await res.json();
  const parsed = schema.safeParse(json);
  if (!parsed.success) {
    console.error("Schema validation failed:", parsed.error.issues, json);
    throw new ApiError(
      `Invalid response shape from ${url}`,
      200,
      url,
    );
  }
  return parsed.data;
}

/** ============================================================
 *  Air Quality endpoints
 *  ============================================================ */

export interface LatLon {
  lat: number;
  lon: number;
}

export function getAirCurrent(loc: LatLon): Promise<AirCurrent> {
  return fetchJson(apiUrl("/air/current", loc), AirCurrentSchema);
}

export function getAirAnalysis(
  loc: LatLon & { mode?: "walk" | "run" | "bike"; skip_ai?: boolean },
): Promise<AirAnalysis> {
  return fetchJson(apiUrl("/air/analysis", loc), AirAnalysisSchema);
}

export function getAirHeatmap(
  loc: LatLon & { radius_km?: number; resolution?: number },
): Promise<AirHeatmap> {
  return fetchJson(apiUrl("/air/heatmap", loc), AirHeatmapSchema);
}

export function getBestTime(
  loc: LatLon & { mode?: "walk" | "run" | "bike"; hours?: number },
): Promise<BestTime> {
  return fetchJson(apiUrl("/air/best-time", loc), BestTimeSchema);
}

/** ============================================================
 *  Routes
 *  ============================================================ */

export function getOptimalRoute(params: {
  origin_lat: number;
  origin_lon: number;
  dest_lat: number;
  dest_lon: number;
  mode?: "bike" | "walk";
  alpha?: number;
  beta?: number;
  depart_in?: number;
}): Promise<RouteOptimal> {
  return fetchJson(apiUrl("/routes/optimal", params), RouteOptimalSchema);
}

/** ============================================================
 *  Contingency
 *  ============================================================ */

export function getContingencyForecast(
  loc: LatLon & { hologram?: "0" | "00" | "1" | "2" },
): Promise<ContingencyForecast> {
  return fetchJson(
    apiUrl("/contingency/forecast", loc),
    ContingencyForecastSchema,
  );
}

/** ============================================================
 *  PPI (biometric impact)
 *  ============================================================ */

export function getPPIContext(loc: LatLon): Promise<PPIContext> {
  return fetchJson(apiUrl("/ppi/context", loc), PPIContextSchema);
}

/** ============================================================
 *  Trip compare
 *  ============================================================ */

export function compareTrip(body: {
  origin: { lat: number; lon: number };
  destination: { lat: number; lon: number };
  vehicle?: Record<string, unknown>;
  include_ai_insight?: boolean;
}): Promise<TripCompare> {
  return fetchJson(apiUrl("/trip/compare"), TripCompareSchema, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

/** ============================================================
 *  Fuel endpoints
 *  ============================================================ */

export function getFuelPrices(): Promise<FuelPrices> {
  return fetchJson(apiUrl("/fuel/prices"), FuelPricesSchema);
}

export function searchFuelCatalog(params: {
  q: string;
  limit?: number;
}): Promise<VehicleSearch> {
  return fetchJson(apiUrl("/fuel/catalog/search", params), VehicleSearchSchema);
}
