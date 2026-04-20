export type AQILevel =
  | "good"
  | "moderate"
  | "sensitive"
  | "unhealthy"
  | "very-unhealthy"
  | "hazardous";

export interface AQIMeta {
  level: AQILevel;
  label: string;
  shortLabel: string;
  color: string;
  gradient: string;
  gradientClass: string;
  range: [number, number];
  description: string;
  recommendation: string;
}

const AQI_TABLE: AQIMeta[] = [
  {
    level: "good",
    label: "Buena",
    shortLabel: "Good",
    color: "#00e676",
    gradient: "linear-gradient(135deg, #00e676 0%, #4aa1b3 100%)",
    gradientClass: "aw-aqi-gradient-good",
    range: [0, 50],
    description: "Aire limpio. Actividad al aire libre sin restricciones.",
    recommendation: "Disfruta el exterior sin preocupaciones.",
  },
  {
    level: "moderate",
    label: "Moderada",
    shortLabel: "Moderate",
    color: "#ffd400",
    gradient: "linear-gradient(135deg, #ffd400 0%, #ff8f00 100%)",
    gradientClass: "aw-aqi-gradient-moderate",
    range: [51, 100],
    description:
      "Calidad aceptable. Personas sensibles podrían notar síntomas leves.",
    recommendation: "Limita esfuerzos prolongados si eres sensible.",
  },
  {
    level: "sensitive",
    label: "Dañina para grupos sensibles",
    shortLabel: "Sensitive",
    color: "#ff8f00",
    gradient: "linear-gradient(135deg, #ff8f00 0%, #ff3d3d 100%)",
    gradientClass: "aw-aqi-gradient-unhealthy",
    range: [101, 150],
    description: "Grupos sensibles deben reducir exposición exterior.",
    recommendation: "Usa mascarilla si tienes asma o EPOC.",
  },
  {
    level: "unhealthy",
    label: "Dañina",
    shortLabel: "Unhealthy",
    color: "#ff3d3d",
    gradient: "linear-gradient(135deg, #ff3d3d 0%, #9c27b0 100%)",
    gradientClass: "aw-aqi-gradient-unhealthy",
    range: [151, 200],
    description: "Todos pueden experimentar efectos en la salud.",
    recommendation: "Evita ejercicio al aire libre.",
  },
  {
    level: "very-unhealthy",
    label: "Muy Dañina",
    shortLabel: "Very Unhealthy",
    color: "#9c27b0",
    gradient: "linear-gradient(135deg, #9c27b0 0%, #6b0022 100%)",
    gradientClass: "aw-aqi-gradient-hazardous",
    range: [201, 300],
    description: "Alerta sanitaria: efectos serios para toda la población.",
    recommendation: "Permanece en interiores con ventilación filtrada.",
  },
  {
    level: "hazardous",
    label: "Peligrosa",
    shortLabel: "Hazardous",
    color: "#6b0022",
    gradient: "linear-gradient(135deg, #6b0022 0%, #3a0010 100%)",
    gradientClass: "aw-aqi-gradient-hazardous",
    range: [301, 500],
    description: "Emergencia: riesgo grave para toda la población.",
    recommendation: "Permanece en interior. Activa filtros HEPA.",
  },
];

export function aqiMeta(aqi: number): AQIMeta {
  return (
    AQI_TABLE.find(({ range }) => aqi >= range[0] && aqi <= range[1]) ??
    AQI_TABLE[AQI_TABLE.length - 1]
  );
}

export const AQI_LEVELS = AQI_TABLE;
