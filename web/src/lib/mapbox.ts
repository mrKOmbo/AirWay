export const MAPBOX_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN ?? "";

/**
 * Custom light style ID — using Mapbox's "light-v11" as a clean base.
 * If we want a fully custom style later, we can replace this with a mapbox://styles URL.
 */
export const MAPBOX_STYLE = "mapbox://styles/mapbox/light-v11";

/** Interpolated EPA colors for AQI heatmap layer */
export const AQI_COLOR_RAMP: [number, string][] = [
  [0, "#00e676"],
  [50, "#a7eb5c"],
  [75, "#ffd400"],
  [100, "#ff8f00"],
  [150, "#ff3d3d"],
  [200, "#9c27b0"],
  [300, "#6b0022"],
];

export function aqiToColor(aqi: number): string {
  for (let i = AQI_COLOR_RAMP.length - 1; i >= 0; i--) {
    if (aqi >= AQI_COLOR_RAMP[i][0]) {
      return AQI_COLOR_RAMP[i][1];
    }
  }
  return AQI_COLOR_RAMP[0][1];
}
