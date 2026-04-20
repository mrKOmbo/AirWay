"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { GlassCard } from "@/components/ui/glass-card";
import type { z } from "zod";
import type { ContingencyHorizonSchema } from "@/lib/api/schemas";
import { cn } from "@/lib/utils";
import { AlertTriangle, Shield, Activity } from "lucide-react";

type Horizon = z.infer<typeof ContingencyHorizonSchema>;

interface Props {
  horizon: Horizon;
  index: number;
}

export function ContingencyHorizonCard({ horizon, index }: Props) {
  const prob = horizon.prob_fase1_o3;
  const probPct = Math.round(prob * 100);
  const severity =
    prob < 0.2 ? "low" : prob < 0.45 ? "medium" : prob < 0.7 ? "high" : "critical";
  const color =
    severity === "low"
      ? "#2e7d32"
      : severity === "medium"
        ? "#ff8f00"
        : severity === "high"
          ? "#ff3d3d"
          : "#9c27b0";
  const Icon =
    severity === "low" ? Shield : severity === "medium" ? Activity : AlertTriangle;
  const label =
    severity === "low"
      ? "Bajo"
      : severity === "medium"
        ? "Moderado"
        : severity === "high"
          ? "Alto"
          : "Crítico";

  const probRef = useRef<HTMLDivElement>(null);
  const ringRef = useRef<SVGCircleElement>(null);
  const r = 36;
  const circumference = 2 * Math.PI * r;

  useEffect(() => {
    const ctx = gsap.context(() => {
      if (probRef.current) {
        const obj = { v: 0 };
        gsap.to(obj, {
          v: probPct,
          duration: 1.6,
          delay: index * 0.12,
          ease: "power3.out",
          onUpdate: () => {
            if (probRef.current)
              probRef.current.textContent = Math.round(obj.v).toString();
          },
        });
      }
      if (ringRef.current) {
        gsap.fromTo(
          ringRef.current,
          { strokeDashoffset: circumference },
          {
            strokeDashoffset: circumference * (1 - prob),
            duration: 1.6,
            delay: index * 0.12,
            ease: "power3.out",
          },
        );
      }
    });
    return () => ctx.revert();
  }, [prob, probPct, index, circumference]);

  const recommendations = horizon.recommendations?.slice(0, 2) ?? [];

  return (
    <GlassCard
      variant="default"
      radius="xl"
      className="relative overflow-hidden p-5 flex flex-col gap-4"
    >
      <div
        className="pointer-events-none absolute -top-12 -right-12 h-36 w-36 rounded-full blur-3xl opacity-30"
        style={{ background: color }}
      />

      <div className="relative flex items-start justify-between">
        <div>
          <div className="aw-eyebrow">Horizonte · h+{horizon.horizon_h}</div>
          <div className="flex items-center gap-1.5 mt-1">
            <Icon className="h-3.5 w-3.5" style={{ color }} />
            <span
              className="text-xs font-semibold"
              style={{ color }}
            >
              Riesgo {label}
            </span>
          </div>
        </div>

        {/* Probability ring */}
        <div className="relative h-20 w-20 shrink-0">
          <svg
            width="80"
            height="80"
            viewBox="0 0 80 80"
            className="-rotate-90"
          >
            <circle
              cx="40"
              cy="40"
              r={r}
              stroke="rgba(10,29,77,0.08)"
              strokeWidth="6"
              fill="none"
            />
            <circle
              ref={ringRef}
              cx="40"
              cy="40"
              r={r}
              stroke={color}
              strokeWidth="6"
              strokeLinecap="round"
              fill="none"
              strokeDasharray={circumference}
              strokeDashoffset={circumference}
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <div
              ref={probRef}
              className="aw-display aw-number text-xl leading-none"
              style={{ color }}
            >
              0
            </div>
            <span className="text-[9px] text-aw-ink-muted font-mono">%</span>
          </div>
        </div>
      </div>

      <div className="relative grid grid-cols-2 gap-3 pt-3 border-t border-aw-border">
        <O3Stat
          label="O₃ esperado"
          value={horizon.o3_expected_ppb}
          unit="ppb"
        />
        <O3Stat
          label="Intervalo 80%"
          value={
            horizon.o3_ci80_ppb
              ? `${Math.round(horizon.o3_ci80_ppb[0])}–${Math.round(horizon.o3_ci80_ppb[1])}`
              : undefined
          }
          unit="ppb"
        />
      </div>

      {recommendations.length > 0 && (
        <div className="relative space-y-1.5">
          {recommendations.map((rec, i) => (
            <div
              key={i}
              className="flex items-start gap-2 text-[11px] text-aw-ink-soft leading-relaxed"
            >
              <span
                className="mt-1.5 h-1 w-1 rounded-full shrink-0"
                style={{ background: color }}
              />
              <span className="line-clamp-2">{rec}</span>
            </div>
          ))}
        </div>
      )}
    </GlassCard>
  );
}

function O3Stat({
  label,
  value,
  unit,
}: {
  label: string;
  value?: number | string;
  unit: string;
}) {
  return (
    <div>
      <div className="aw-eyebrow text-[9px]">{label}</div>
      <div className="flex items-baseline gap-1 mt-0.5">
        <span className="aw-number text-sm font-semibold text-aw-primary">
          {typeof value === "number"
            ? Math.round(value)
            : (value ?? "—")}
        </span>
        <span className="text-[9px] text-aw-ink-muted font-medium">{unit}</span>
      </div>
    </div>
  );
}

export function ContingencyHorizonSkeleton() {
  return (
    <GlassCard variant="default" radius="xl" className={cn("p-5 h-[220px] aw-shimmer bg-aw-border")} />
  );
}
