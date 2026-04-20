import { z } from "zod";

/** ============================================================
 *  Shared primitives
 *  ============================================================ */

export const LocationSchema = z.object({
  lat: z.number(),
  lon: z.number(),
  elevation_m: z.number().optional().nullable(),
});

/**
 * Some endpoints return pollutants as flat numbers (e.g. /air/current)
 * while others return rich objects (/air/analysis, /ppi/context).
 * Accept both; callers normalize via pollutantValue() helper.
 */
export const PollutantSchema = z.union([
  z.number(),
  z.object({
    value: z.number(),
    unit: z.string().optional(),
    sources_reporting: z.number().optional(),
  }),
]);

export const PollutantsSchema = z.record(z.string(), PollutantSchema);

export function pollutantValue(
  p: z.infer<typeof PollutantSchema> | undefined,
): number | undefined {
  if (p === undefined || p === null) return undefined;
  if (typeof p === "number") return p;
  return p.value;
}

export function pollutantUnit(
  p: z.infer<typeof PollutantSchema> | undefined,
): string | undefined {
  if (p === undefined || p === null) return undefined;
  if (typeof p === "number") return undefined;
  return p.unit;
}

/** ============================================================
 *  /air/current
 *  ============================================================ */

export const AirCurrentSchema = z.object({
  aqi: z.number(),
  category: z.string().optional(),
  color: z.string().optional(),
  dominant_pollutant: z.string().optional(),
  pollutants: PollutantsSchema.optional(),
  timestamp: z.string().optional(),
  location: LocationSchema.optional(),
});

export type AirCurrent = z.infer<typeof AirCurrentSchema>;

/** ============================================================
 *  /air/analysis
 *  ============================================================ */

export const ForecastPointSchema = z.object({
  time: z.string(),
  aqi: z.number(),
});

export const MLPredictionWindowSchema = z.object({
  aqi: z.number(),
  pm25: z.number().optional(),
  category: z.string().optional(),
  color: z.string().optional(),
  risk_level: z.string().optional(),
  confidence_interval: z
    .object({
      lower_pm25: z.number().optional(),
      upper_pm25: z.number().optional(),
      lower_aqi: z.number().optional(),
      upper_aqi: z.number().optional(),
    })
    .optional(),
});

export const MLPredictionSchema = z.object({
  current_aqi: z.number().optional(),
  current_pm25: z.number().optional(),
  trend: z.string().optional(),
  model_available: z.boolean().optional(),
  predictions: z
    .object({
      "1h": MLPredictionWindowSchema.optional(),
      "3h": MLPredictionWindowSchema.optional(),
      "6h": MLPredictionWindowSchema.optional(),
    })
    .optional(),
});

export const AIAnalysisSchema = z.object({
  summary: z.string().optional(),
  recommendation: z.string().optional(),
  affected_groups: z.array(z.string()).optional(),
  activity_recommendation: z.string().optional(),
});

export const AirAnalysisSchema = z.object({
  location: LocationSchema,
  timestamp: z.string(),
  combined_aqi: z.number(),
  aqi_range: z
    .object({
      low: z.number(),
      high: z.number(),
      spread: z.number(),
    })
    .optional(),
  category: z.string().optional(),
  color: z.string().optional(),
  confidence: z.number().optional(),
  dominant_pollutant: z.string().optional(),
  station_count: z.number().optional(),
  pollutants: PollutantsSchema.optional(),
  ml_prediction: MLPredictionSchema.optional().nullable(),
  ai_analysis: AIAnalysisSchema.optional().nullable(),
  forecast: z.array(ForecastPointSchema).optional(),
  sources: z.record(z.string(), z.any()).optional(),
});

export type AirAnalysis = z.infer<typeof AirAnalysisSchema>;

/** ============================================================
 *  /air/heatmap
 *  ============================================================ */

export const HeatmapPointSchema = z.object({
  lat: z.number(),
  lon: z.number(),
  aqi: z.number(),
  color: z.string().optional(),
  predicted_1h: z.number().optional().nullable(),
  prediction_1h: z.number().optional().nullable(),
});

/**
 * Backend returns points under `grid`; we keep a computed `points` alias.
 */
export const AirHeatmapSchema = z
  .object({
    center: LocationSchema.optional(),
    radius_km: z.number().optional(),
    resolution: z.number().optional(),
    grid_points: z.number().optional(),
    trend_factor: z.number().optional(),
    timestamp: z.string().optional(),
    grid: z.array(HeatmapPointSchema).optional(),
    points: z.array(HeatmapPointSchema).optional(),
  })
  .transform((d) => ({
    ...d,
    points: d.points ?? d.grid ?? [],
  }));

export type AirHeatmap = z.infer<typeof AirHeatmapSchema>;

/** ============================================================
 *  /air/best-time
 *  ============================================================ */

export const BestTimeHourSchema = z.object({
  time: z.string(),
  aqi: z.number(),
  category: z.string().optional(),
  color: z.string().optional(),
  recommendation: z.string().optional(),
  recommended: z.boolean().optional(),
});

const WindowSchema = z.object({
  start: z.string(),
  end: z.string(),
  avg_aqi: z.number(),
  risk_level: z.string().optional(),
});

export const BestTimeSchema = z.object({
  location: LocationSchema.optional(),
  mode: z.string().optional(),
  hours_analyzed: z.number().optional(),
  hourly: z.array(BestTimeHourSchema),
  best_window: WindowSchema.optional(),
  worst_window: WindowSchema.optional(),
  summary: z.string().optional(),
});

export type BestTime = z.infer<typeof BestTimeSchema>;

/** ============================================================
 *  /routes/optimal
 *  ============================================================ */

export const RouteSchema = z.object({
  distance_km: z.number(),
  duration_min: z.number(),
  exposure_index: z.number().optional(),
  avg_aqi_now: z.number().optional(),
  predicted_arrival_aqi: z.number().optional(),
  score: z.number().optional(),
  polyline: z.string(),
});

export const RouteOptimalSchema = z.object({
  origin: z.tuple([z.number(), z.number()]),
  destination: z.tuple([z.number(), z.number()]),
  route: RouteSchema,
  weights: z
    .object({
      alpha_distance: z.number(),
      beta_air: z.number(),
    })
    .optional(),
  air_quality: z
    .object({
      combined_aqi: z.number().optional(),
      confidence: z.number().optional(),
    })
    .optional(),
  ml_prediction: MLPredictionSchema.optional().nullable(),
  ai_analysis: AIAnalysisSchema.optional().nullable(),
  explanation: z.string().optional(),
});

export type RouteOptimal = z.infer<typeof RouteOptimalSchema>;

/** ============================================================
 *  /contingency/forecast
 *  ============================================================ */

export const ContingencyDriverSchema = z.object({
  feature: z.string(),
  value: z.number().optional(),
  importance: z.number().optional(),
  contribution: z.number().optional(),
});

export const ContingencyHorizonSchema = z.object({
  horizon_h: z.number(),
  prob_fase1_o3: z.number(),
  prob_uncalibrated: z.number().optional(),
  o3_expected_ppb: z.number().optional(),
  o3_ci80_ppb: z.tuple([z.number(), z.number()]).optional(),
  top_drivers: z.array(ContingencyDriverSchema).optional(),
  recommendations: z.array(z.string()).optional(),
  timestamp: z.string().optional(),
});

export const ContingencyForecastSchema = z.object({
  timestamp: z.string(),
  location: LocationSchema.optional(),
  forecasts: z.array(ContingencyHorizonSchema),
  explanation_hint: z.string().optional(),
  model_version: z.string().optional(),
  disclaimer: z.string().optional(),
});

export type ContingencyForecast = z.infer<typeof ContingencyForecastSchema>;

/** ============================================================
 *  /ppi/context
 *  ============================================================ */

export const PPIContextSchema = z.object({
  location: LocationSchema,
  timestamp: z.string(),
  air_quality: z.object({
    aqi: z.number(),
    dominant_pollutant: z.string().optional(),
    confidence: z.number().optional(),
    pollutants: PollutantsSchema.optional(),
  }),
  expected_biometric_impact: z.object({
    spo2_drop_estimate_pp: z.number(),
    hrv_decrease_estimate_pct: z.number(),
    hr_increase_estimate_bpm: z.number(),
    resp_increase_estimate_pct: z.number(),
  }),
  ppi_estimates: z.object({
    estimated_ppi_healthy: z.number(),
    estimated_ppi_asthmatic: z.number(),
    estimated_ppi_copd: z.number(),
    estimated_ppi_cvd: z.number(),
    risk_level: z.string(),
  }),
  risk_factors: z
    .object({
      altitude_m: z.number().optional(),
      thermal_inversion_risk: z.boolean().optional(),
      trend: z.string().optional(),
    })
    .optional(),
  recommendation: z.string().optional(),
});

export type PPIContext = z.infer<typeof PPIContextSchema>;

/** ============================================================
 *  /trip/compare
 *  ============================================================ */

export const TripModeSchema = z.object({
  mode: z.string(),
  duration_min: z.number().optional(),
  distance_km: z.number().optional(),
  cost_mxn: z.number().optional(),
  direct_cost_mxn: z.number().optional(),
  total_cost_mxn: z.number().optional(),
  hidden_cost_mxn: z.number().optional(),
  co2_kg: z.number().optional(),
  pm25_exposure_g: z.number().optional(),
  calories: z.number().optional(),
  calories_burned: z.number().optional(),
  avg_aqi: z.number().optional(),
  health_impact: z.string().optional(),
  vehicle_display: z.string().optional(),
  tolls_mxn: z.number().optional(),
  parking_mxn: z.number().optional(),
  liters: z.number().optional(),
});

/**
 * Backend returns modes keyed by name (auto/metro/uber/bike).
 * Accept both object-map and legacy array shapes. Expose a
 * flattened `modes_list` via transform for UI consumption.
 */
export const TripCompareSchema = z
  .object({
    origin: LocationSchema,
    destination: LocationSchema,
    modes: z.union([
      z.array(TripModeSchema),
      z.record(z.string(), TripModeSchema),
    ]),
    recommendation: z
      .union([z.string(), z.record(z.string(), z.any())])
      .optional(),
    ai_insight: z.string().optional(),
  })
  .transform((d) => ({
    ...d,
    modes_list: Array.isArray(d.modes)
      ? d.modes
      : Object.entries(d.modes).map(([k, v]) => ({ ...v, mode: v.mode ?? k })),
  }));

export type TripCompare = z.infer<typeof TripCompareSchema>;

/** ============================================================
 *  Fuel · /fuel/prices
 *  ============================================================ */

export const FuelPricesSchema = z.object({
  magna: z.number().optional(),
  premium: z.number().optional(),
  diesel: z.number().optional(),
  source: z.string().optional(),
  updated_at: z.string().optional(),
  currency: z.string().optional(),
  unit: z.string().optional(),
});

export type FuelPrices = z.infer<typeof FuelPricesSchema>;

/** ============================================================
 *  Fuel · /fuel/catalog/search
 *  ============================================================ */

export const VehicleSchema = z.object({
  make: z.string(),
  model: z.string(),
  year: z.number(),
  fuel_type: z.string().optional(),
  conuee_km_per_l: z.number().optional(),
  transmission: z.string().optional(),
  displacement_cc: z.number().optional(),
  cylinders: z.number().optional(),
  emission_standard: z.string().optional(),
});

export const VehicleSearchSchema = z.object({
  results: z.array(VehicleSchema).optional(),
  count: z.number().optional(),
  items: z.array(VehicleSchema).optional(),
});

export type Vehicle = z.infer<typeof VehicleSchema>;
export type VehicleSearch = z.infer<typeof VehicleSearchSchema>;
