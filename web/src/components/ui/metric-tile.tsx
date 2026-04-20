import { cn } from "@/lib/utils";
import { GlassCard } from "./glass-card";
import { type LucideIcon } from "lucide-react";

interface MetricTileProps {
  label: string;
  value: string | number;
  unit?: string;
  icon?: LucideIcon;
  accent?: string;
  trend?: {
    value: number;
    direction: "up" | "down" | "flat";
  };
  className?: string;
}

export function MetricTile({
  label,
  value,
  unit,
  icon: Icon,
  accent = "#0099ff",
  trend,
  className,
}: MetricTileProps) {
  return (
    <GlassCard
      variant="default"
      radius="lg"
      className={cn("p-5 overflow-hidden group", className)}
    >
      <div
        className="pointer-events-none absolute -top-6 -right-6 h-28 w-28 rounded-full blur-2xl opacity-30 transition-opacity group-hover:opacity-50"
        style={{ background: accent }}
        aria-hidden
      />
      <div className="relative flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <span className="aw-eyebrow">{label}</span>
          {Icon && (
            <Icon
              className="h-4 w-4"
              style={{ color: accent }}
              strokeWidth={2.2}
            />
          )}
        </div>
        <div className="flex items-baseline gap-1.5">
          <span className="aw-display aw-number text-3xl text-aw-primary">
            {value}
          </span>
          {unit && (
            <span className="text-xs font-medium text-aw-ink-muted">{unit}</span>
          )}
        </div>
        {trend && (
          <div
            className={cn(
              "flex items-center gap-1 text-xs font-medium",
              trend.direction === "up" && "text-aw-danger",
              trend.direction === "down" && "text-aw-success",
              trend.direction === "flat" && "text-aw-ink-muted",
            )}
          >
            <TrendArrow dir={trend.direction} />
            <span className="aw-number">
              {trend.value > 0 ? "+" : ""}
              {trend.value}
            </span>
          </div>
        )}
      </div>
    </GlassCard>
  );
}

function TrendArrow({ dir }: { dir: "up" | "down" | "flat" }) {
  if (dir === "flat")
    return (
      <svg width="12" height="12" viewBox="0 0 12 12">
        <path d="M2 6h8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      </svg>
    );
  const rotate = dir === "up" ? 0 : 180;
  return (
    <svg
      width="12"
      height="12"
      viewBox="0 0 12 12"
      style={{ transform: `rotate(${rotate}deg)` }}
    >
      <path
        d="M6 2L10 7H7V10H5V7H2L6 2Z"
        fill="currentColor"
      />
    </svg>
  );
}
