"use client";

import { useEffect, useMemo, useRef } from "react";
import { gsap } from "gsap";
import { GlassCard } from "@/components/ui/glass-card";
import type { TripCompare } from "@/lib/api/schemas";
import {
  Car,
  Train,
  Bike,
  Car as TaxiCar,
  type LucideIcon,
  Sparkles,
  Leaf,
  Clock,
  DollarSign,
  Wind,
} from "lucide-react";
import { cn } from "@/lib/utils";

interface Props {
  data?: TripCompare;
  loading?: boolean;
}

const MODE_META: Record<
  string,
  { label: string; icon: LucideIcon; accent: string }
> = {
  auto: { label: "Auto privado", icon: Car, accent: "#0a1d4d" },
  car: { label: "Auto privado", icon: Car, accent: "#0a1d4d" },
  metro: { label: "Metro / bus", icon: Train, accent: "#0099ff" },
  public_transport: { label: "Transporte público", icon: Train, accent: "#0099ff" },
  uber: { label: "Uber", icon: TaxiCar, accent: "#1a1a1a" },
  bike: { label: "Bicicleta", icon: Bike, accent: "#2e7d32" },
  bicycle: { label: "Bicicleta", icon: Bike, accent: "#2e7d32" },
};

function modeMeta(mode: string) {
  return (
    MODE_META[mode.toLowerCase()] ?? {
      label: mode,
      icon: Car,
      accent: "#6b7a95",
    }
  );
}

export function TripComparator({ data, loading }: Props) {
  const modes = useMemo(() => data?.modes_list ?? [], [data]);

  // Best = lowest composite of CO2, cost, duration
  const recommendedIdx = useMemo(() => {
    if (!modes.length) return -1;
    const scored = modes.map((m, i) => ({
      i,
      score:
        (m.co2_kg ?? 99) * 0.45 +
        ((m.total_cost_mxn ?? m.cost_mxn ?? m.direct_cost_mxn ?? 200) / 100) *
          0.3 +
        (m.duration_min ?? 60) * 0.015,
    }));
    scored.sort((a, b) => a.score - b.score);
    return scored[0]?.i ?? -1;
  }, [modes]);

  const root = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!root.current || !modes.length) return;
    const ctx = gsap.context(() => {
      gsap.from(".trip-mode-card", {
        y: 20,
        opacity: 0,
        duration: 0.6,
        ease: "power3.out",
        stagger: 0.08,
      });
    }, root);
    return () => ctx.revert();
  }, [modes]);

  if (loading) {
    return (
      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <GlassCard
            key={i}
            variant="default"
            radius="xl"
            className="h-[240px] aw-shimmer bg-aw-border"
          />
        ))}
      </div>
    );
  }

  if (!modes.length) {
    return (
      <GlassCard variant="default" radius="xl" className="p-8 text-center">
        <div className="aw-eyebrow">Multimodal</div>
        <p className="mt-2 text-sm text-aw-ink-muted">
          Sin datos de comparación — verifica que el backend esté activo.
        </p>
      </GlassCard>
    );
  }

  return (
    <div ref={root} className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {modes.map((m, i) => {
        const meta = modeMeta(m.mode);
        const Icon = meta.icon;
        const isBest = i === recommendedIdx;
        return (
          <GlassCard
            key={m.mode + i}
            variant="default"
            radius="xl"
            className={cn(
              "trip-mode-card relative overflow-hidden p-5 flex flex-col gap-4 transition-all",
              isBest && "ring-1",
            )}
            style={
              isBest
                ? ({
                    ["--tw-ring-color" as string]: meta.accent,
                    boxShadow: `0 14px 40px ${meta.accent}20, inset 0 0 0 1px ${meta.accent}`,
                  } as React.CSSProperties)
                : undefined
            }
          >
            {isBest && (
              <div
                className="absolute top-0 right-0 px-2.5 py-1 text-[10px] font-bold uppercase tracking-widest text-white rounded-bl-xl"
                style={{ background: meta.accent }}
              >
                Mejor
              </div>
            )}

            <div className="flex items-center gap-3">
              <div
                className="h-11 w-11 rounded-xl grid place-items-center"
                style={{
                  background: `${meta.accent}14`,
                  color: meta.accent,
                }}
              >
                <Icon className="h-5 w-5" strokeWidth={2.2} />
              </div>
              <div>
                <div className="text-sm font-semibold text-aw-primary">
                  {meta.label}
                </div>
                <div className="aw-eyebrow text-[9px]">{m.mode}</div>
              </div>
            </div>

            <div className="space-y-3">
              <TripStat
                icon={Clock}
                label="Tiempo"
                value={
                  m.duration_min !== undefined
                    ? `${Math.round(m.duration_min)}`
                    : "—"
                }
                unit="min"
              />
              <TripStat
                icon={DollarSign}
                label="Costo"
                value={(() => {
                  const c = m.total_cost_mxn ?? m.cost_mxn ?? m.direct_cost_mxn;
                  return c !== undefined ? `$${c.toFixed(2)}` : "—";
                })()}
                unit="MXN"
              />
              <TripStat
                icon={Leaf}
                label="CO₂"
                value={
                  m.co2_kg !== undefined ? m.co2_kg.toFixed(2) : "—"
                }
                unit="kg"
                positive={m.co2_kg !== undefined && m.co2_kg < 0.1}
                negative={m.co2_kg !== undefined && m.co2_kg > 2}
              />
              <TripStat
                icon={Wind}
                label="AQI exposición"
                value={
                  m.avg_aqi !== undefined ? Math.round(m.avg_aqi).toString() : "—"
                }
              />
            </div>

            {m.health_impact && (
              <div className="text-[10px] text-aw-ink-muted leading-relaxed pt-2 border-t border-aw-border">
                {m.health_impact}
              </div>
            )}
          </GlassCard>
        );
      })}

      {data?.ai_insight && (
        <GlassCard
          variant="default"
          radius="xl"
          className="trip-mode-card relative overflow-hidden p-5 sm:col-span-2 lg:col-span-4 flex items-start gap-4"
        >
          <div
            className="pointer-events-none absolute -top-12 -right-12 h-40 w-40 rounded-full blur-3xl opacity-30"
            style={{
              background:
                "conic-gradient(from 180deg, #59b7d1, #0099ff, #4aa1b3)",
            }}
          />
          <div className="relative h-10 w-10 rounded-xl grid place-items-center shrink-0 bg-gradient-to-br from-aw-body/20 to-aw-accent/20">
            <Sparkles className="h-5 w-5 text-aw-accent" strokeWidth={2.2} />
          </div>
          <div className="relative flex-1">
            <div className="aw-eyebrow">Insight multimodal · Gemini</div>
            <p className="mt-1.5 text-sm text-aw-primary leading-relaxed">
              {data.ai_insight}
            </p>
            {typeof data.recommendation === "string" && data.recommendation && (
              <p className="mt-2 text-xs text-aw-ink-soft leading-relaxed">
                {data.recommendation}
              </p>
            )}
          </div>
        </GlassCard>
      )}
    </div>
  );
}

function TripStat({
  icon: Icon,
  label,
  value,
  unit,
  positive,
  negative,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
  unit?: string;
  positive?: boolean;
  negative?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <Icon
        className={cn(
          "h-3.5 w-3.5",
          positive && "text-aw-success",
          negative && "text-aw-danger",
          !positive && !negative && "text-aw-ink-muted",
        )}
        strokeWidth={2.3}
      />
      <div className="flex-1 flex items-baseline justify-between gap-2">
        <span className="aw-eyebrow text-[10px]">{label}</span>
        <div className="flex items-baseline gap-0.5">
          <span
            className={cn(
              "aw-number text-sm font-semibold",
              positive && "text-aw-success",
              negative && "text-aw-danger",
              !positive && !negative && "text-aw-primary",
            )}
          >
            {value}
          </span>
          {unit && (
            <span className="text-[9px] text-aw-ink-muted font-medium">
              {unit}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
