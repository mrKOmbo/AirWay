"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { GlassCard } from "@/components/ui/glass-card";
import { aqiMeta } from "@/lib/aqi";
import type { MLPredictionSchema } from "@/lib/api/schemas";
import type { z } from "zod";
import { ArrowUp, ArrowDown, Minus } from "lucide-react";
import { cn } from "@/lib/utils";

type MLPrediction = z.infer<typeof MLPredictionSchema>;

interface Props {
  prediction?: MLPrediction | null;
  currentAqi?: number;
  loading?: boolean;
}

const HORIZONS: Array<{ key: "1h" | "3h" | "6h"; label: string }> = [
  { key: "1h", label: "1 hora" },
  { key: "3h", label: "3 horas" },
  { key: "6h", label: "6 horas" },
];

export function PredictionTrio({ prediction, currentAqi, loading }: Props) {
  return (
    <div className="grid sm:grid-cols-3 gap-4">
      {HORIZONS.map((h, idx) => {
        const pred = prediction?.predictions?.[h.key];
        const delta =
          pred && currentAqi != null
            ? Math.round(pred.aqi - currentAqi)
            : undefined;
        return (
          <HorizonCard
            key={h.key}
            label={h.label}
            aqi={pred?.aqi}
            delta={delta}
            loading={loading}
            index={idx}
          />
        );
      })}
    </div>
  );
}

function HorizonCard({
  label,
  aqi,
  delta,
  loading,
  index,
}: {
  label: string;
  aqi?: number;
  delta?: number;
  loading?: boolean;
  index: number;
}) {
  const numRef = useRef<HTMLDivElement>(null);
  const sparkRef = useRef<SVGPathElement>(null);
  const meta = aqi !== undefined ? aqiMeta(aqi) : null;

  useEffect(() => {
    if (aqi === undefined || !numRef.current) return;
    const ctx = gsap.context(() => {
      const obj = { v: 0 };
      gsap.to(obj, {
        v: aqi,
        duration: 1.6,
        ease: "power3.out",
        delay: index * 0.12,
        onUpdate: () => {
          if (numRef.current)
            numRef.current.textContent = Math.round(obj.v).toString();
        },
      });
      if (sparkRef.current) {
        const len = sparkRef.current.getTotalLength?.() ?? 200;
        gsap.fromTo(
          sparkRef.current,
          { strokeDasharray: len, strokeDashoffset: len },
          {
            strokeDashoffset: 0,
            duration: 1.8,
            delay: index * 0.12,
            ease: "power2.out",
          },
        );
      }
    });
    return () => ctx.revert();
  }, [aqi, index]);

  const trend =
    delta === undefined ? "flat" : delta > 2 ? "up" : delta < -2 ? "down" : "flat";
  const trendColor =
    trend === "up"
      ? "#ff3d3d"
      : trend === "down"
        ? "#2e7d32"
        : "#6b7a95";

  return (
    <GlassCard
      variant="default"
      radius="xl"
      className="p-5 relative overflow-hidden"
    >
      <div
        className="pointer-events-none absolute -top-10 -right-10 h-32 w-32 rounded-full blur-3xl opacity-40"
        style={{ background: meta?.color ?? "#59b7d1" }}
        aria-hidden
      />
      <div className="relative flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <span className="aw-eyebrow">Predicción · {label}</span>
          <span
            className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold"
            style={{
              background: `${trendColor}18`,
              color: trendColor,
            }}
          >
            {trend === "up" && <ArrowUp className="h-3 w-3" strokeWidth={3} />}
            {trend === "down" && <ArrowDown className="h-3 w-3" strokeWidth={3} />}
            {trend === "flat" && <Minus className="h-3 w-3" strokeWidth={3} />}
            {delta !== undefined
              ? `${delta > 0 ? "+" : ""}${delta}`
              : "—"}
          </span>
        </div>

        <div className="flex items-baseline gap-2">
          {loading ? (
            <div className="h-14 w-24 aw-shimmer bg-aw-border rounded-lg" />
          ) : (
            <div
              ref={numRef}
              className="aw-display aw-number text-[56px] leading-none"
              style={
                meta
                  ? {
                      backgroundImage: meta.gradient,
                      WebkitBackgroundClip: "text",
                      backgroundClip: "text",
                      color: "transparent",
                    }
                  : { color: "#6b7a95" }
              }
            >
              {aqi !== undefined ? "0" : "—"}
            </div>
          )}
          <span className="aw-eyebrow">AQI</span>
        </div>

        <div className="flex items-center justify-between">
          <span
            className="text-xs font-medium"
            style={{ color: meta?.color ?? "#6b7a95" }}
          >
            {meta?.label ?? "Sin datos"}
          </span>
          <svg width="72" height="28" viewBox="0 0 72 28" aria-hidden>
            <defs>
              <linearGradient id={`spark-${label}`} x1="0" x2="1">
                <stop offset="0%" stopColor={meta?.color ?? "#59b7d1"} stopOpacity="0.2" />
                <stop offset="100%" stopColor={meta?.color ?? "#59b7d1"} />
              </linearGradient>
            </defs>
            <path
              ref={sparkRef}
              d="M0 20 Q 18 8, 36 12 T 72 6"
              stroke={`url(#spark-${label})`}
              strokeWidth="2"
              strokeLinecap="round"
              fill="none"
            />
          </svg>
        </div>
      </div>
    </GlassCard>
  );
}

export function PredictionTrioSkeleton() {
  return (
    <div className="grid sm:grid-cols-3 gap-4">
      {HORIZONS.map((h) => (
        <GlassCard key={h.key} variant="default" radius="xl" className="p-5">
          <div className={cn("h-32 aw-shimmer bg-aw-border rounded-lg")} />
        </GlassCard>
      ))}
    </div>
  );
}
