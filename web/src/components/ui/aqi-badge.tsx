import { cn } from "@/lib/utils";
import { aqiMeta } from "@/lib/aqi";

interface AQIBadgeProps {
  aqi: number;
  size?: "sm" | "md" | "lg";
  showLabel?: boolean;
  className?: string;
}

const SIZE_CLASS = {
  sm: "text-[11px] px-2 py-0.5",
  md: "text-xs px-2.5 py-1",
  lg: "text-sm px-3 py-1.5",
} as const;

export function AQIBadge({
  aqi,
  size = "md",
  showLabel = true,
  className,
}: AQIBadgeProps) {
  const meta = aqiMeta(aqi);
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full font-medium text-white shadow-sm",
        SIZE_CLASS[size],
        className,
      )}
      style={{ background: meta.gradient }}
    >
      <span className="aw-number font-semibold tracking-tight">{Math.round(aqi)}</span>
      {showLabel && <span className="opacity-90">{meta.label}</span>}
    </span>
  );
}
