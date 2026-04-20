"use client";

import { cn } from "@/lib/utils";
import { GlassCard } from "@/components/ui/glass-card";
import type { RouteFlavor } from "@/hooks/use-routes";
import type { RouteOptimal } from "@/lib/api/schemas";
import { Leaf, Zap, Scale, type LucideIcon } from "lucide-react";

interface Props {
  routes: Array<{
    flavor: RouteFlavor;
    label: string;
    color: string;
    data?: RouteOptimal;
    isLoading: boolean;
    isError: boolean;
  }>;
  active: RouteFlavor;
  onSelect: (flavor: RouteFlavor) => void;
}

const ICONS: Record<RouteFlavor, LucideIcon> = {
  cleanest: Leaf,
  balanced: Scale,
  fastest: Zap,
};

export function RouteCards({ routes, active, onSelect }: Props) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
      {routes.map((r) => {
        const Icon = ICONS[r.flavor];
        const route = r.data?.route;
        const isActive = active === r.flavor;
        return (
          <button
            key={r.flavor}
            onClick={() => onSelect(r.flavor)}
            className={cn(
              "relative text-left rounded-2xl border transition-all overflow-hidden group",
              isActive
                ? "border-transparent ring-2 ring-offset-2 ring-offset-white"
                : "border-aw-border hover:border-aw-border-strong",
            )}
            style={
              isActive
                ? ({
                    ["--tw-ring-color" as string]: r.color,
                  } as React.CSSProperties)
                : undefined
            }
          >
            <div
              className={cn(
                "aw-glass p-4 flex flex-col gap-3 transition-colors",
                isActive && "bg-white/90",
              )}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span
                    className="h-7 w-7 rounded-lg grid place-items-center"
                    style={{
                      background: `${r.color}18`,
                      color: r.color,
                    }}
                  >
                    <Icon className="h-3.5 w-3.5" strokeWidth={2.4} />
                  </span>
                  <span className="text-sm font-semibold text-aw-primary">
                    {r.label}
                  </span>
                </div>
                {isActive && (
                  <span
                    className="text-[10px] font-semibold uppercase tracking-wider px-1.5 py-0.5 rounded-md text-white"
                    style={{ background: r.color }}
                  >
                    Activa
                  </span>
                )}
              </div>

              {r.isLoading ? (
                <div className="h-12 aw-shimmer bg-aw-border rounded-lg" />
              ) : r.isError ? (
                <div className="text-xs text-aw-danger">
                  Error al calcular. ¿Backend corriendo?
                </div>
              ) : route ? (
                <div className="grid grid-cols-3 gap-2">
                  <Metric
                    label="Dist"
                    value={route.distance_km.toFixed(1)}
                    unit="km"
                  />
                  <Metric
                    label="Tiempo"
                    value={Math.round(route.duration_min).toString()}
                    unit="min"
                  />
                  <Metric
                    label="AQI"
                    value={
                      route.avg_aqi_now
                        ? Math.round(route.avg_aqi_now).toString()
                        : "—"
                    }
                  />
                </div>
              ) : (
                <div className="text-xs text-aw-ink-muted">Sin datos</div>
              )}
            </div>
          </button>
        );
      })}
    </div>
  );
}

function Metric({
  label,
  value,
  unit,
}: {
  label: string;
  value: string;
  unit?: string;
}) {
  return (
    <div className="flex flex-col">
      <span className="text-[9px] uppercase tracking-wider text-aw-ink-muted font-mono">
        {label}
      </span>
      <div className="flex items-baseline gap-0.5">
        <span className="aw-number text-base font-semibold text-aw-primary">
          {value}
        </span>
        {unit && (
          <span className="text-[9px] text-aw-ink-muted font-medium">
            {unit}
          </span>
        )}
      </div>
    </div>
  );
}
