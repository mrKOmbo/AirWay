"use client";

import { useEffect, useRef, useState } from "react";
import { gsap } from "gsap";
import { SectionHeader } from "@/components/ui/section-header";
import { LivePill } from "@/components/ui/live-pill";
import { PredictionHero } from "@/components/forecast/prediction-hero";
import { BestTimeStrip } from "@/components/forecast/best-time-strip";
import { AIInsight } from "@/components/forecast/ai-insight";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useAirAnalysis, useBestTime } from "@/hooks/use-air-quality";
import {
  Bike,
  Footprints,
  Activity as Run,
  TrendingUp,
  TrendingDown,
  Minus,
} from "lucide-react";
import { cn } from "@/lib/utils";

type Mode = "walk" | "run" | "bike";

export function ForecastSection() {
  const geo = useGeolocation();
  const [mode, setMode] = useState<Mode>("walk");
  const analysis = useAirAnalysis(geo.coords, mode);
  const bestTime = useBestTime(geo.coords, mode, 12);
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".forecast-reveal", {
        y: 48,
        opacity: 0,
        duration: 1,
        ease: "power3.out",
        stagger: 0.12,
        scrollTrigger: {
          trigger: root.current,
          start: "top 78%",
          once: true,
        },
      });
    }, root);
    return () => ctx.revert();
  }, []);

  const trend = analysis.data?.ml_prediction?.trend;
  const aqiNow = analysis.data?.combined_aqi;

  return (
    <section
      id="forecast"
      ref={root}
      className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-20 md:py-28 scroll-mt-24"
    >
      {/* Ambient backdrop */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-24 left-0 right-0 h-[320px] opacity-70"
        style={{
          background:
            "radial-gradient(70% 60% at 15% 0%, rgba(89,183,209,0.14), transparent 65%), radial-gradient(60% 55% at 90% 10%, rgba(0,153,255,0.10), transparent 70%)",
        }}
      />

      <div className="relative flex flex-col gap-8">
        {/* Header */}
        <div className="forecast-reveal flex flex-col md:flex-row md:items-end md:justify-between gap-4">
          <SectionHeader
            eyebrow="Fase 5 · Predicción"
            title="El próximo respiro, antes de que llegue"
            subtitle="XGBoost con 49 features (contaminantes + meteo + lags) fusionado con CAMS + análisis Gemini. Mantén presionado para ver el detalle de cualquier horizonte u hora."
          />
          <div className="flex items-center gap-2">
            <TrendPill trend={trend} />
            <LivePill>ML · actualiza cada 5 min</LivePill>
          </div>
        </div>

        {/* Controls bar */}
        <div className="forecast-reveal flex items-center justify-between gap-4 flex-wrap">
          <ModeSelector mode={mode} onChange={setMode} />
          <div className="flex items-center gap-2 text-xs text-aw-ink-muted">
            <span>AQI actual</span>
            <span className="aw-number font-semibold text-aw-primary text-sm">
              {aqiNow !== undefined ? Math.round(aqiNow) : "—"}
            </span>
            {analysis.data?.category && (
              <span className="text-[11px]">· {analysis.data.category}</span>
            )}
          </div>
        </div>

        {/* Hero prediction */}
        <div className="forecast-reveal">
          <PredictionHero
            prediction={analysis.data?.ml_prediction}
            currentAqi={aqiNow}
            loading={analysis.isLoading}
          />
        </div>

        {/* Timeline */}
        <div className="forecast-reveal">
          <BestTimeStrip data={bestTime.data} loading={bestTime.isLoading} />
        </div>

        {/* AI insight */}
        <div className="forecast-reveal">
          <AIInsight
            analysis={analysis.data?.ai_analysis}
            loading={analysis.isLoading}
            confidence={analysis.data?.confidence}
            stations={analysis.data?.station_count}
            range={
              analysis.data?.aqi_range
                ? {
                    low: analysis.data.aqi_range.low,
                    high: analysis.data.aqi_range.high,
                  }
                : undefined
            }
          />
        </div>
      </div>
    </section>
  );
}

function TrendPill({ trend }: { trend?: string }) {
  if (!trend) return null;
  const map: Record<
    string,
    { label: string; color: string; bg: string; Icon: React.ComponentType<{ className?: string; strokeWidth?: number }> }
  > = {
    improving: {
      label: "Mejorando",
      color: "#0a8a4f",
      bg: "rgba(0,230,118,0.14)",
      Icon: TrendingDown,
    },
    stable: {
      label: "Estable",
      color: "#0099ff",
      bg: "rgba(0,153,255,0.12)",
      Icon: Minus,
    },
    worsening: {
      label: "Empeorando",
      color: "#ff3d3d",
      bg: "rgba(255,61,61,0.12)",
      Icon: TrendingUp,
    },
  };
  const meta = map[trend] ?? map.stable;
  const Icon = meta.Icon;
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold"
      style={{ color: meta.color, background: meta.bg }}
    >
      <Icon className="h-3.5 w-3.5" strokeWidth={2.6} />
      {meta.label}
    </span>
  );
}

const MODE_META: Array<{
  value: Mode;
  label: string;
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
}> = [
  { value: "walk", label: "Caminar", icon: Footprints },
  { value: "run", label: "Correr", icon: Run },
  { value: "bike", label: "Bici", icon: Bike },
];

function ModeSelector({
  mode,
  onChange,
}: {
  mode: Mode;
  onChange: (m: Mode) => void;
}) {
  return (
    <div
      className="inline-flex items-center rounded-full border border-aw-border bg-white/70 backdrop-blur p-1 gap-1"
      role="radiogroup"
    >
      {MODE_META.map((m) => {
        const Icon = m.icon;
        const active = mode === m.value;
        return (
          <button
            key={m.value}
            role="radio"
            aria-checked={active}
            onClick={() => onChange(m.value)}
            className={cn(
              "flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold transition-all",
              active
                ? "text-white shadow-sm"
                : "text-aw-ink-soft hover:text-aw-primary hover:bg-white",
            )}
            style={
              active
                ? {
                    background:
                      "linear-gradient(135deg, #0099ff 0%, #0a1d4d 100%)",
                    boxShadow:
                      "0 6px 14px rgba(0,153,255,0.28), inset 0 1px 0 rgba(255,255,255,0.3)",
                  }
                : undefined
            }
          >
            <Icon className="h-3.5 w-3.5" strokeWidth={2.4} />
            {m.label}
          </button>
        );
      })}
    </div>
  );
}
