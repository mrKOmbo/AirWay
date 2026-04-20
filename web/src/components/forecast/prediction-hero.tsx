"use client";

import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import { gsap } from "gsap";
import { aqiMeta } from "@/lib/aqi";
import type { MLPredictionSchema } from "@/lib/api/schemas";
import type { z } from "zod";
import { ArrowUpRight, ArrowDownRight, Minus, Wind } from "lucide-react";
import { cn } from "@/lib/utils";
import { usePressHold } from "@/hooks/use-press-hold";

type MLPrediction = z.infer<typeof MLPredictionSchema>;
type HorizonKey = "1h" | "3h" | "6h";

interface Props {
  prediction?: MLPrediction | null;
  currentAqi?: number;
  loading?: boolean;
}

const HORIZONS: Array<{ key: HorizonKey; label: string; caption: string }> = [
  { key: "1h", label: "1h", caption: "Próxima hora" },
  { key: "3h", label: "3h", caption: "Próximas 3 horas" },
  { key: "6h", label: "6h", caption: "Próximas 6 horas" },
];

export function PredictionHero({ prediction, currentAqi, loading }: Props) {
  const [horizon, setHorizon] = useState<HorizonKey>("6h");
  const numRef = useRef<HTMLSpanElement>(null);
  const areaRef = useRef<SVGPathElement>(null);
  const lineRef = useRef<SVGPathElement>(null);
  const dotsRef = useRef<SVGGElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);

  const preds = prediction?.predictions;

  const timeline = useMemo(() => {
    const base = currentAqi ?? preds?.["1h"]?.aqi ?? 0;
    return [
      { label: "Ahora", aqi: base },
      { label: "1h", aqi: preds?.["1h"]?.aqi ?? base },
      { label: "3h", aqi: preds?.["3h"]?.aqi ?? base },
      { label: "6h", aqi: preds?.["6h"]?.aqi ?? base },
    ];
  }, [preds, currentAqi]);

  const active = preds?.[horizon];
  const aqi = active?.aqi;
  const meta = aqi !== undefined ? aqiMeta(aqi) : null;
  const currentMeta = currentAqi !== undefined ? aqiMeta(currentAqi) : null;
  const delta =
    aqi !== undefined && currentAqi !== undefined
      ? Math.round(aqi - currentAqi)
      : undefined;

  const trend =
    delta === undefined ? "flat" : delta > 2 ? "up" : delta < -2 ? "down" : "flat";
  const trendColor =
    trend === "up" ? "#ff3d3d" : trend === "down" ? "#0a8a4f" : "#6b7a95";
  const trendBg =
    trend === "up"
      ? "rgba(255,61,61,0.10)"
      : trend === "down"
        ? "rgba(0,230,118,0.14)"
        : "rgba(107,122,149,0.10)";

  // Sparkline path build
  const { linePath, areaPath, dots } = useMemo(
    () => buildSparkPaths(timeline),
    [timeline],
  );

  // Press-and-hold reveals "analysis" overlay
  const { bind, pressing, holding, progress } = usePressHold({
    holdMs: 380,
  });

  // Animate AQI counter + spark
  useEffect(() => {
    if (aqi === undefined || !numRef.current) return;
    const ctx = gsap.context(() => {
      const obj = { v: Number(numRef.current!.textContent) || 0 };
      gsap.to(obj, {
        v: aqi,
        duration: 1.2,
        ease: "power3.out",
        onUpdate: () => {
          if (numRef.current)
            numRef.current.textContent = Math.round(obj.v).toString();
        },
      });
      if (lineRef.current) {
        const len = lineRef.current.getTotalLength?.() ?? 320;
        gsap.fromTo(
          lineRef.current,
          { strokeDasharray: len, strokeDashoffset: len },
          {
            strokeDashoffset: 0,
            duration: 1.6,
            ease: "power2.out",
          },
        );
      }
      if (areaRef.current) {
        gsap.fromTo(
          areaRef.current,
          { opacity: 0 },
          { opacity: 0.32, duration: 0.9, delay: 0.4, ease: "power2.out" },
        );
      }
      if (dotsRef.current) {
        gsap.from(dotsRef.current.children, {
          scale: 0,
          opacity: 0,
          duration: 0.5,
          stagger: 0.1,
          delay: 0.8,
          transformOrigin: "center",
          ease: "back.out(2)",
        });
      }
    });
    return () => ctx.revert();
  }, [aqi, horizon, linePath]);

  // Press feedback
  useEffect(() => {
    if (!cardRef.current) return;
    gsap.to(cardRef.current, {
      scale: pressing ? 0.985 : 1,
      duration: 0.25,
      ease: "power2.out",
    });
  }, [pressing]);

  return (
    <div
      ref={cardRef}
      className="relative overflow-hidden rounded-[32px] isolate"
      style={{
        background:
          "radial-gradient(120% 120% at 0% 0%, rgba(89,183,209,0.22) 0%, rgba(255,255,255,0.72) 45%, rgba(255,255,255,0.9) 100%)",
        boxShadow:
          "0 1px 0 rgba(255,255,255,0.9) inset, 0 40px 80px -40px rgba(10,29,77,0.28), 0 18px 50px -30px rgba(0,153,255,0.22)",
        border: "1px solid rgba(10,29,77,0.08)",
        backdropFilter: "blur(24px) saturate(180%)",
        WebkitBackdropFilter: "blur(24px) saturate(180%)",
      }}
      {...bind}
    >
      {/* Aurora overlays */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-1/2 -right-1/4 h-[120%] w-[80%] opacity-60"
        style={{
          background: meta
            ? `radial-gradient(50% 50% at 50% 50%, ${meta.color}44 0%, transparent 70%)`
            : "radial-gradient(50% 50% at 50% 50%, rgba(0,153,255,0.18) 0%, transparent 70%)",
          filter: "blur(40px)",
          transition: "background 600ms ease",
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.35] mix-blend-overlay"
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml;utf8,<svg viewBox='0 0 120 120' xmlns='http://www.w3.org/2000/svg'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0.04 0 0 0 0 0.11 0 0 0 0 0.3 0 0 0 0.08 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")",
        }}
      />

      <div className="relative p-6 md:p-8 flex flex-col gap-7">
        {/* Top row */}
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <HorizonTabs value={horizon} onChange={setHorizon} prediction={prediction} currentAqi={currentAqi} />
          <div className="flex items-center gap-2">
            <DeltaPill
              delta={delta}
              trend={trend}
              color={trendColor}
              bg={trendBg}
              loading={loading}
            />
          </div>
        </div>

        {/* Big number + context */}
        <div className="grid sm:grid-cols-[minmax(0,1fr)_minmax(0,0.9fr)] gap-6 items-end">
          <div className="flex flex-col gap-3 min-w-0">
            <span className="aw-eyebrow">AQI predicho · {HORIZONS.find((h) => h.key === horizon)?.caption}</span>
            <div className="flex items-baseline gap-3 leading-none">
              <span
                ref={numRef}
                className="aw-display aw-number text-[88px] md:text-[112px] tracking-[-0.04em]"
                style={
                  meta
                    ? ({
                        backgroundImage: meta.gradient,
                        WebkitBackgroundClip: "text",
                        backgroundClip: "text",
                        color: "transparent",
                      } as CSSProperties)
                    : { color: "#6b7a95" }
                }
              >
                {aqi !== undefined ? "0" : "—"}
              </span>
              {meta && (
                <div className="flex flex-col gap-0.5 pb-3">
                  <span
                    className="text-sm font-semibold uppercase tracking-[0.14em]"
                    style={{ color: meta.color }}
                  >
                    {meta.shortLabel}
                  </span>
                  <span className="text-xs text-aw-ink-muted">
                    {meta.label}
                  </span>
                </div>
              )}
            </div>

            {currentMeta && meta && (
              <div className="flex items-center gap-2 text-xs text-aw-ink-soft">
                <CategoryChip label={currentMeta.shortLabel} color={currentMeta.color} />
                <span className="text-aw-ink-muted">→</span>
                <CategoryChip label={meta.shortLabel} color={meta.color} solid />
                {currentMeta.level !== meta.level && (
                  <span className="text-[11px] text-aw-ink-muted">
                    transición de categoría
                  </span>
                )}
              </div>
            )}
          </div>

          {/* Sparkline timeline */}
          <div className="relative w-full min-w-0">
            <svg viewBox="0 0 320 110" className="w-full h-[110px] overflow-visible">
              <defs>
                <linearGradient id="ph-line" x1="0" x2="1">
                  <stop offset="0%" stopColor={currentMeta?.color ?? "#59b7d1"} />
                  <stop offset="100%" stopColor={meta?.color ?? "#0099ff"} />
                </linearGradient>
                <linearGradient id="ph-area" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0%" stopColor={meta?.color ?? "#0099ff"} stopOpacity="0.5" />
                  <stop offset="100%" stopColor={meta?.color ?? "#0099ff"} stopOpacity="0" />
                </linearGradient>
              </defs>
              <path
                ref={areaRef}
                d={areaPath}
                fill="url(#ph-area)"
                opacity="0"
              />
              <path
                ref={lineRef}
                d={linePath}
                stroke="url(#ph-line)"
                strokeWidth="2.5"
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              <g ref={dotsRef}>
                {dots.map((d, i) => {
                  const isActive =
                    (horizon === "1h" && i === 1) ||
                    (horizon === "3h" && i === 2) ||
                    (horizon === "6h" && i === 3);
                  return (
                    <g key={d.label}>
                      <circle
                        cx={d.x}
                        cy={d.y}
                        r={isActive ? 6 : 3}
                        fill={d.color}
                        stroke="white"
                        strokeWidth={isActive ? 3 : 1.5}
                      />
                      <text
                        x={d.x}
                        y={104}
                        textAnchor="middle"
                        className="aw-number"
                        style={{
                          fontSize: 10,
                          fill: isActive ? "var(--color-aw-primary)" : "var(--color-aw-ink-muted)",
                          fontWeight: isActive ? 600 : 400,
                        }}
                      >
                        {d.label}
                      </text>
                    </g>
                  );
                })}
              </g>
            </svg>
          </div>
        </div>

        {/* Press hint + recommendation */}
        <div className="flex items-start gap-3 pt-1">
          <div
            className="shrink-0 h-9 w-9 rounded-full grid place-items-center"
            style={{
              background: meta ? `${meta.color}1a` : "rgba(0,153,255,0.12)",
              color: meta?.color ?? "#0099ff",
            }}
          >
            <Wind className="h-4 w-4" strokeWidth={2.4} />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm text-aw-primary leading-relaxed font-medium">
              {loading
                ? "Calculando horizonte…"
                : meta
                  ? buildNarrative({ horizon, delta, meta, currentMeta })
                  : "Sin datos suficientes para la predicción."}
            </p>
            <div className="mt-1.5 flex items-center gap-2 text-[11px] text-aw-ink-muted">
              <HoldDot />
              <span>Mantén presionado para leer el análisis</span>
            </div>
          </div>
        </div>

        {/* Hold progress bar */}
        <div
          className="absolute left-0 right-0 bottom-0 h-[2px] bg-aw-border overflow-hidden pointer-events-none"
          aria-hidden
        >
          <div
            className="h-full transition-[opacity]"
            style={{
              width: `${Math.round(progress * 100)}%`,
              background: meta?.gradient ?? "linear-gradient(90deg, #59b7d1, #0099ff)",
              opacity: pressing ? 1 : 0,
              transitionDuration: pressing ? "60ms" : "220ms",
            }}
          />
        </div>
      </div>

      {/* Press-and-hold analysis overlay */}
      <HoldOverlay visible={holding} meta={meta} aqi={aqi} delta={delta} horizon={horizon} pm25={active?.pm25} currentAqi={currentAqi} />
    </div>
  );
}

function HoldDot() {
  return (
    <span
      className="inline-block h-1.5 w-1.5 rounded-full"
      style={{
        background: "var(--color-aw-accent)",
        boxShadow: "0 0 0 3px rgba(0,153,255,0.2)",
      }}
    />
  );
}

function CategoryChip({
  label,
  color,
  solid,
}: {
  label: string;
  color: string;
  solid?: boolean;
}) {
  return (
    <span
      className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold uppercase tracking-[0.12em]"
      style={{
        background: solid ? color : `${color}1a`,
        color: solid ? "white" : color,
        border: solid ? "none" : `1px solid ${color}30`,
      }}
    >
      {label}
    </span>
  );
}

function DeltaPill({
  delta,
  trend,
  color,
  bg,
  loading,
}: {
  delta?: number;
  trend: "up" | "down" | "flat";
  color: string;
  bg: string;
  loading?: boolean;
}) {
  if (loading)
    return (
      <span className="h-7 w-20 aw-shimmer bg-aw-border rounded-full" aria-hidden />
    );
  const Icon = trend === "up" ? ArrowUpRight : trend === "down" ? ArrowDownRight : Minus;
  const sign = delta === undefined ? "—" : delta > 0 ? `+${delta}` : `${delta}`;
  const verb =
    trend === "up" ? "sube" : trend === "down" ? "baja" : "estable";
  return (
    <span
      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold"
      style={{ background: bg, color }}
    >
      <Icon className="h-3.5 w-3.5" strokeWidth={3} />
      <span className="aw-number">{sign}</span>
      <span className="opacity-70 font-medium">{verb}</span>
    </span>
  );
}

function HorizonTabs({
  value,
  onChange,
  prediction,
  currentAqi,
}: {
  value: HorizonKey;
  onChange: (k: HorizonKey) => void;
  prediction?: MLPrediction | null;
  currentAqi?: number;
}) {
  return (
    <div
      role="tablist"
      className="inline-flex p-1 rounded-full border border-aw-border bg-white/60 backdrop-blur-md gap-0.5"
    >
      {HORIZONS.map((h) => {
        const pred = prediction?.predictions?.[h.key];
        const active = value === h.key;
        const delta =
          pred?.aqi !== undefined && currentAqi !== undefined
            ? Math.round(pred.aqi - currentAqi)
            : undefined;
        return (
          <button
            key={h.key}
            role="tab"
            aria-selected={active}
            onClick={() => onChange(h.key)}
            className={cn(
              "relative px-3.5 py-1.5 rounded-full text-xs font-semibold transition-colors flex items-center gap-1.5",
              active
                ? "text-white"
                : "text-aw-ink-soft hover:text-aw-primary",
            )}
            style={
              active
                ? {
                    background:
                      "linear-gradient(135deg, #0099ff 0%, #0a1d4d 100%)",
                    boxShadow:
                      "0 6px 18px rgba(0,153,255,0.30), inset 0 1px 0 rgba(255,255,255,0.3)",
                  }
                : undefined
            }
          >
            <span>{h.label}</span>
            {delta !== undefined && (
              <span
                className={cn(
                  "aw-number text-[10px] font-medium",
                  active ? "text-white/85" : "text-aw-ink-muted",
                )}
              >
                {delta > 0 ? `+${delta}` : delta}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

function HoldOverlay({
  visible,
  meta,
  aqi,
  delta,
  horizon,
  pm25,
  currentAqi,
}: {
  visible: boolean;
  meta: ReturnType<typeof aqiMeta> | null;
  aqi?: number;
  delta?: number;
  horizon: HorizonKey;
  pm25?: number;
  currentAqi?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    gsap.to(ref.current, {
      opacity: visible ? 1 : 0,
      y: visible ? 0 : 18,
      duration: visible ? 0.45 : 0.28,
      ease: visible ? "power3.out" : "power2.in",
      pointerEvents: visible ? "auto" : "none",
    });
    if (visible) {
      gsap.from(ref.current.querySelectorAll("[data-hold-row]"), {
        y: 14,
        opacity: 0,
        duration: 0.42,
        stagger: 0.06,
        ease: "power3.out",
        delay: 0.06,
      });
    }
  }, [visible]);

  const rows: Array<{ label: string; value: string; accent?: string }> = [];
  if (meta && aqi !== undefined) {
    rows.push({ label: "Categoría", value: meta.label, accent: meta.color });
    rows.push({
      label: "AQI proyectado",
      value: `${Math.round(aqi)}`,
    });
    if (delta !== undefined && currentAqi !== undefined) {
      rows.push({
        label: "Variación vs ahora",
        value: `${delta > 0 ? "+" : ""}${delta} AQI (${Math.abs(
          delta,
        )} pts ${delta > 0 ? "peor" : "mejor"})`,
      });
    }
    if (pm25 !== undefined) {
      rows.push({
        label: "PM2.5 esperado",
        value: `${pm25.toFixed(1)} µg/m³`,
      });
    }
  }

  return (
    <div
      ref={ref}
      className="absolute inset-0 z-20 p-6 md:p-8 flex flex-col justify-end pointer-events-none"
      style={{ opacity: 0 }}
    >
      <div
        className="rounded-[24px] p-5 md:p-6 flex flex-col gap-3"
        style={{
          background: "rgba(10, 29, 77, 0.94)",
          backdropFilter: "blur(30px) saturate(180%)",
          WebkitBackdropFilter: "blur(30px) saturate(180%)",
          boxShadow: "0 30px 80px -20px rgba(0,0,0,0.4)",
          border: "1px solid rgba(255,255,255,0.1)",
        }}
      >
        <div className="flex items-center justify-between">
          <span className="aw-eyebrow text-white/60">Análisis · {horizon}</span>
          <span
            className="text-[10px] font-semibold tracking-[0.2em] uppercase"
            style={{ color: meta?.color ?? "#4ccfff" }}
          >
            Vista detallada
          </span>
        </div>
        <div className="grid grid-cols-2 gap-3 mt-1">
          {rows.map((r) => (
            <div
              key={r.label}
              data-hold-row
              className="flex flex-col gap-0.5 p-3 rounded-xl"
              style={{ background: "rgba(255,255,255,0.06)" }}
            >
              <span className="text-[10px] uppercase tracking-[0.14em] text-white/55 font-mono">
                {r.label}
              </span>
              <span
                className="aw-number text-base font-semibold"
                style={{ color: r.accent ?? "white" }}
              >
                {r.value}
              </span>
            </div>
          ))}
        </div>
        {meta && (
          <p
            data-hold-row
            className="text-sm leading-relaxed mt-1"
            style={{ color: "rgba(255,255,255,0.88)" }}
          >
            {meta.recommendation}
          </p>
        )}
        <span
          data-hold-row
          className="text-[10px] text-white/45 mt-1 font-mono uppercase tracking-[0.14em]"
        >
          Suelta para volver
        </span>
      </div>
    </div>
  );
}

function buildNarrative({
  horizon,
  delta,
  meta,
  currentMeta,
}: {
  horizon: HorizonKey;
  delta?: number;
  meta: ReturnType<typeof aqiMeta>;
  currentMeta: ReturnType<typeof aqiMeta> | null;
}) {
  const winLabel =
    horizon === "1h"
      ? "en la próxima hora"
      : horizon === "3h"
        ? "en las próximas 3 horas"
        : "en las próximas 6 horas";
  if (currentMeta && currentMeta.level !== meta.level) {
    const verb = delta && delta > 0 ? "escalará a" : "descenderá a";
    return `El aire ${verb} ${meta.label.toLowerCase()} ${winLabel}. ${meta.recommendation}`;
  }
  if (delta !== undefined) {
    if (Math.abs(delta) <= 2) {
      return `El AQI se mantiene estable ${winLabel}. Ventana favorable para planificar actividad.`;
    }
    const verb = delta > 0 ? "subirá" : "bajará";
    return `AQI ${verb} ${Math.abs(delta)} puntos ${winLabel} hacia ${meta.label.toLowerCase()}. ${meta.recommendation}`;
  }
  return meta.recommendation;
}

/* ---------- sparkline builder ---------- */

interface Timeline {
  label: string;
  aqi: number;
}

function buildSparkPaths(timeline: Timeline[]) {
  const W = 320;
  const H = 90;
  const padX = 22;
  const padY = 14;
  const maxVal = Math.max(80, ...timeline.map((p) => p.aqi)) * 1.08;
  const minVal = Math.max(0, Math.min(...timeline.map((p) => p.aqi)) * 0.85);
  const span = maxVal - minVal || 1;

  const points = timeline.map((p, i) => {
    const x = padX + (i * (W - padX * 2)) / (timeline.length - 1);
    const y = padY + (1 - (p.aqi - minVal) / span) * (H - padY * 2);
    return { ...p, x, y, color: aqiMeta(p.aqi).color };
  });

  if (points.length < 2) {
    return { linePath: "", areaPath: "", dots: points };
  }

  let line = `M ${points[0].x} ${points[0].y}`;
  for (let i = 1; i < points.length; i++) {
    const prev = points[i - 1];
    const cur = points[i];
    const midX = (prev.x + cur.x) / 2;
    line += ` C ${midX} ${prev.y}, ${midX} ${cur.y}, ${cur.x} ${cur.y}`;
  }
  const areaPath = `${line} L ${points[points.length - 1].x} ${H} L ${points[0].x} ${H} Z`;
  return { linePath: line, areaPath, dots: points };
}
