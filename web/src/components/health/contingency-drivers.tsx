"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { GlassCard } from "@/components/ui/glass-card";
import type { z } from "zod";
import type { ContingencyHorizonSchema } from "@/lib/api/schemas";

type Horizon = z.infer<typeof ContingencyHorizonSchema>;

const FEATURE_LABELS: Record<string, string> = {
  wind_speed_10m: "Viento 10m",
  temperature_2m: "Temperatura 2m",
  relative_humidity: "Humedad rel.",
  shortwave_radiation: "Radiación solar",
  boundary_layer_height: "Capa límite",
  pressure_msl: "Presión",
  no2: "NO₂",
  o3: "O₃ actual",
  pm25: "PM2.5",
};

function friendly(feature: string): string {
  return FEATURE_LABELS[feature] ?? feature.replace(/_/g, " ");
}

interface Props {
  horizon?: Horizon;
  loading?: boolean;
}

export function ContingencyDrivers({ horizon, loading }: Props) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current || !horizon?.top_drivers?.length) return;
    const ctx = gsap.context(() => {
      gsap.from(".driver-bar-fill", {
        scaleX: 0,
        transformOrigin: "left",
        duration: 1.1,
        ease: "power3.out",
        stagger: 0.08,
      });
      gsap.from(".driver-row", {
        x: -12,
        opacity: 0,
        duration: 0.6,
        ease: "power3.out",
        stagger: 0.08,
      });
    }, ref);
    return () => ctx.revert();
  }, [horizon]);

  const drivers = horizon?.top_drivers?.slice(0, 5) ?? [];
  // Backend returns `importance` (positive weight); older responses had `contribution`.
  const contribution = (d: {
    importance?: number;
    contribution?: number;
  }): number => d.importance ?? d.contribution ?? 0;
  const maxContribution = Math.max(
    ...drivers.map((d) => Math.abs(contribution(d))),
    0.1,
  );

  return (
    <GlassCard variant="default" radius="xl" className="p-6 md:p-7">
      <div className="flex items-center justify-between mb-5">
        <div>
          <div className="aw-eyebrow">Drivers del modelo</div>
          <div className="text-xs text-aw-ink-muted mt-0.5">
            SHAP contributions · quantile regression
          </div>
        </div>
        {horizon && (
          <span className="text-[10px] aw-number text-aw-ink-soft">
            h+{horizon.horizon_h}
          </span>
        )}
      </div>

      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-8 aw-shimmer bg-aw-border rounded-lg" />
          ))}
        </div>
      ) : drivers.length === 0 ? (
        <p className="text-sm text-aw-ink-muted">Sin drivers disponibles.</p>
      ) : (
        <div ref={ref} className="space-y-2.5">
          {drivers.map((d, i) => {
            const sign = contribution(d) >= 0;
            const widthPct = (Math.abs(contribution(d)) / maxContribution) * 100;
            const color = sign ? "#ff3d3d" : "#2e7d32";
            return (
              <div key={d.feature} className="driver-row">
                <div className="flex items-center justify-between text-[11px] mb-1">
                  <span className="text-aw-primary font-medium">
                    {friendly(d.feature)}
                  </span>
                  <span
                    className="aw-number font-semibold"
                    style={{ color }}
                  >
                    {sign ? "+" : ""}
                    {(contribution(d) * 100).toFixed(1)}%
                  </span>
                </div>
                <div className="relative h-2 rounded-full bg-aw-border overflow-hidden">
                  <div
                    className="driver-bar-fill absolute left-0 top-0 h-full rounded-full"
                    style={{
                      width: `${widthPct}%`,
                      background: `linear-gradient(90deg, ${color}40, ${color})`,
                    }}
                  />
                </div>
                {i === 0 && (
                  <div className="text-[9px] text-aw-ink-muted mt-1">
                    Driver dominante
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </GlassCard>
  );
}
