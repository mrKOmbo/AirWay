"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useAirAnalysis } from "@/hooks/use-air-quality";
import { AQIDial } from "./aqi-dial";
import { GlassCard } from "@/components/ui/glass-card";
import { LivePill } from "@/components/ui/live-pill";
import { aqiMeta } from "@/lib/aqi";
import { pollutantValue } from "@/lib/api/schemas";
import {
  Sparkles,
  MapPin,
  Wind,
  Activity,
  ArrowRight,
  ShieldCheck,
} from "lucide-react";

export function HeroSection() {
  const geo = useGeolocation();
  const analysis = useAirAnalysis(geo.coords);
  const root = useRef<HTMLDivElement>(null);

  const aqi = analysis.data?.combined_aqi ?? 0;
  const meta = aqiMeta(aqi);
  const pm25 = pollutantValue(analysis.data?.pollutants?.pm25);
  const no2 = pollutantValue(analysis.data?.pollutants?.no2);
  const o3 = pollutantValue(analysis.data?.pollutants?.o3);
  const confidence = analysis.data?.confidence;
  const stations = analysis.data?.station_count;

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".hero-fade-up", {
        y: 24,
        opacity: 0,
        duration: 1,
        ease: "power3.out",
        stagger: 0.08,
      });
      gsap.from(".hero-dial", {
        scale: 0.9,
        opacity: 0,
        duration: 1.2,
        ease: "power3.out",
        delay: 0.2,
      });
    }, root);
    return () => ctx.revert();
  }, []);

  return (
    <section
      id="live"
      ref={root}
      className="relative mx-auto w-full max-w-7xl px-4 md:px-6 pt-8 md:pt-14 pb-16 md:pb-24"
    >
      <div className="grid lg:grid-cols-[1.1fr_1fr] gap-10 lg:gap-14 items-center">
        {/* Left: headline */}
        <div className="space-y-7">
          <div className="hero-fade-up flex flex-wrap items-center gap-2">
            <LivePill>En vivo desde tu ubicación</LivePill>
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/70 backdrop-blur border border-aw-border px-3 py-1 text-xs font-medium text-aw-primary">
              <Sparkles className="h-3 w-3" />
              ML · NASA TEMPO
            </span>
          </div>

          <h1 className="hero-fade-up aw-display text-[44px] md:text-[64px] lg:text-[76px] text-aw-primary">
            Respira con{" "}
            <span
              style={{
                backgroundImage:
                  "linear-gradient(135deg, #0099ff 0%, #4aa1b3 50%, #0a1d4d 100%)",
                WebkitBackgroundClip: "text",
                backgroundClip: "text",
                color: "transparent",
              }}
            >
              inteligencia
            </span>
            <span className="block text-aw-ink-soft font-medium text-[22px] md:text-[28px] lg:text-[32px] mt-3 tracking-tight">
              Tu aire, tus rutas, tu salud — en tiempo real.
            </span>
          </h1>

          <p className="hero-fade-up text-aw-ink-soft text-lg max-w-xl leading-relaxed">
            AirWay fusiona estaciones terrestres, modelos CAMS, datos NASA TEMPO
            y predicción ML propia para darte rutas más limpias, pronósticos
            horarios y análisis del impacto real en tu cuerpo.
          </p>

          <div className="hero-fade-up flex flex-wrap items-center gap-3">
            <a
              href="#map"
              className="group inline-flex items-center gap-2 rounded-full px-5 py-3 text-sm font-semibold text-white transition-transform hover:scale-[1.02] active:scale-[0.98]"
              style={{
                background:
                  "linear-gradient(135deg, #0099ff 0%, #0a1d4d 100%)",
                boxShadow:
                  "0 10px 32px rgba(0,153,255,0.32), inset 0 1px 0 rgba(255,255,255,0.3)",
              }}
            >
              Ver mapa interactivo
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </a>
            <a
              href="#health"
              className="inline-flex items-center gap-2 rounded-full border border-aw-border-strong bg-white/70 backdrop-blur px-5 py-3 text-sm font-semibold text-aw-primary hover:bg-white transition-colors"
            >
              <ShieldCheck className="h-4 w-4" />
              Análisis biométrico
            </a>
          </div>

          {/* Location bar */}
          <div className="hero-fade-up flex items-center gap-3 text-sm text-aw-ink-muted">
            <MapPin className="h-4 w-4" />
            <span className="aw-number">
              {geo.coords
                ? `${geo.coords.lat.toFixed(3)}, ${geo.coords.lon.toFixed(3)}`
                : "Localizando…"}
            </span>
            {geo.source === "fallback" && (
              <span className="text-xs text-aw-warning">
                · usando CDMX por defecto
              </span>
            )}
          </div>
        </div>

        {/* Right: AQI dial + readings */}
        <div className="hero-dial relative">
          <GlassCard
            variant="strong"
            radius="2xl"
            className="p-7 md:p-9 flex flex-col gap-8"
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="aw-eyebrow">Calidad del aire</div>
                <div className="mt-1 text-sm text-aw-ink-soft">
                  Fusión {stations ?? "…"} estaciones · confianza{" "}
                  <span className="aw-number font-medium">
                    {confidence ? `${Math.round(confidence * 100)}%` : "—"}
                  </span>
                </div>
              </div>
              <div
                className="rounded-full p-2"
                style={{
                  background: meta.gradient,
                  boxShadow: `0 0 0 1px ${meta.color}40, 0 8px 24px ${meta.color}40`,
                }}
              >
                <Wind className="h-4 w-4 text-white" />
              </div>
            </div>

            <div className="flex justify-center">
              <AQIDial aqi={aqi || 42} size={280} />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <PollutantCell label="PM2.5" value={pm25} unit="µg/m³" />
              <PollutantCell label="NO₂" value={no2} unit="ppb" />
              <PollutantCell label="O₃" value={o3} unit="ppb" />
            </div>

            <div className="flex items-start gap-3 rounded-2xl bg-aw-primary/5 border border-aw-border p-4">
              <Activity className="h-5 w-5 text-aw-accent shrink-0 mt-0.5" />
              <p className="text-sm text-aw-ink-soft leading-relaxed">
                {analysis.data?.ai_analysis?.recommendation ??
                  meta.recommendation}
              </p>
            </div>
          </GlassCard>
        </div>
      </div>
    </section>
  );
}

function PollutantCell({
  label,
  value,
  unit,
}: {
  label: string;
  value?: number;
  unit: string;
}) {
  return (
    <div className="rounded-xl border border-aw-border bg-white/60 backdrop-blur p-3">
      <div className="aw-eyebrow text-[10px]">{label}</div>
      <div className="mt-1.5 flex items-baseline gap-1">
        <span className="aw-display aw-number text-xl text-aw-primary">
          {value !== undefined ? value.toFixed(1) : "—"}
        </span>
        <span className="text-[10px] text-aw-ink-muted font-medium">{unit}</span>
      </div>
    </div>
  );
}
