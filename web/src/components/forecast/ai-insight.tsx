"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { Sparkles, AlertCircle, Users, Activity } from "lucide-react";
import type { z } from "zod";
import type { AIAnalysisSchema } from "@/lib/api/schemas";

type AIAnalysis = z.infer<typeof AIAnalysisSchema>;

interface Props {
  analysis?: AIAnalysis | null;
  loading?: boolean;
  confidence?: number;
  stations?: number;
  range?: { low: number; high: number };
}

export function AIInsight({
  analysis,
  loading,
  confidence,
  stations,
  range,
}: Props) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current || !analysis) return;
    const ctx = gsap.context(() => {
      gsap.from(".insight-row", {
        y: 14,
        opacity: 0,
        duration: 0.55,
        ease: "power3.out",
        stagger: 0.06,
      });
    }, ref);
    return () => ctx.revert();
  }, [analysis]);

  const hasConfidence = confidence !== undefined;

  return (
    <div
      className="relative overflow-hidden rounded-[32px] isolate"
      style={{
        background:
          "linear-gradient(135deg, rgba(10,29,77,0.94) 0%, rgba(10,29,77,0.82) 45%, rgba(16,42,107,0.75) 100%)",
        boxShadow:
          "0 1px 0 rgba(255,255,255,0.08) inset, 0 30px 70px -30px rgba(10,29,77,0.5)",
        border: "1px solid rgba(255,255,255,0.08)",
      }}
    >
      {/* Conic halo */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-1/3 -right-1/3 h-[140%] w-[80%] opacity-40"
        style={{
          background:
            "conic-gradient(from 110deg, rgba(89,183,209,0.8), rgba(0,153,255,0.6), rgba(76,207,255,0.5), rgba(89,183,209,0.8))",
          filter: "blur(60px)",
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.25] mix-blend-overlay"
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml;utf8,<svg viewBox='0 0 120 120' xmlns='http://www.w3.org/2000/svg'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0.3 0 0 0 0 0.6 0 0 0 0 1 0 0 0 0.14 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")",
        }}
      />

      <div
        ref={ref}
        className="relative p-6 md:p-8 grid md:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)] gap-6"
      >
        {/* Left: insight */}
        <div className="flex flex-col gap-4 text-white">
          <div className="flex items-center gap-3">
            <div
              className="h-9 w-9 rounded-xl grid place-items-center"
              style={{
                background:
                  "linear-gradient(135deg, rgba(89,183,209,0.35), rgba(0,153,255,0.35))",
                boxShadow: "inset 0 1px 0 rgba(255,255,255,0.25)",
              }}
            >
              <Sparkles className="h-4 w-4 text-white" strokeWidth={2.3} />
            </div>
            <div>
              <div className="aw-eyebrow text-white/60">
                Insight IA · Gemini
              </div>
              <div className="text-xs text-white/45 mt-0.5">
                Análisis contextual · generado al momento
              </div>
            </div>
          </div>

          {loading ? (
            <div className="space-y-2">
              <div className="h-3 aw-shimmer bg-white/10 rounded" />
              <div className="h-3 w-5/6 aw-shimmer bg-white/10 rounded" />
              <div className="h-3 w-4/6 aw-shimmer bg-white/10 rounded" />
            </div>
          ) : !analysis ? (
            <p className="text-sm text-white/60">
              Esperando análisis del backend…
            </p>
          ) : (
            <>
              {analysis.summary && (
                <p className="insight-row text-[15px] md:text-base leading-relaxed text-white font-medium">
                  {analysis.summary}
                </p>
              )}
              <div className="grid sm:grid-cols-2 gap-2.5">
                {analysis.recommendation && (
                  <InsightPill
                    icon={<AlertCircle className="h-3.5 w-3.5" />}
                    label="Recomendación"
                    text={analysis.recommendation}
                  />
                )}
                {analysis.activity_recommendation && (
                  <InsightPill
                    icon={<Activity className="h-3.5 w-3.5" />}
                    label="Actividad"
                    text={analysis.activity_recommendation}
                    accent="#00e676"
                  />
                )}
              </div>
              {analysis.affected_groups && analysis.affected_groups.length > 0 && (
                <div className="insight-row flex items-start gap-2.5 pt-1">
                  <Users className="h-4 w-4 text-white/55 shrink-0 mt-0.5" />
                  <div className="flex flex-wrap gap-1.5">
                    {analysis.affected_groups.map((g) => (
                      <span
                        key={g}
                        className="inline-flex items-center px-2 py-0.5 text-[10px] font-medium rounded-full"
                        style={{
                          background: "rgba(255,143,0,0.16)",
                          color: "#ffb347",
                          border: "1px solid rgba(255,143,0,0.34)",
                        }}
                      >
                        {g}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* Right: confidence + metadata */}
        <div className="flex flex-col justify-between gap-5">
          {hasConfidence && (
            <div className="insight-row flex flex-col gap-3">
              <div className="flex items-end justify-between">
                <span className="aw-eyebrow text-white/55">
                  Confianza
                </span>
                <span className="aw-display aw-number text-3xl text-white">
                  {Math.round((confidence ?? 0) * 100)}
                  <span className="text-lg text-white/55 ml-0.5">%</span>
                </span>
              </div>
              <div className="h-1.5 rounded-full bg-white/10 overflow-hidden">
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${Math.round((confidence ?? 0) * 100)}%`,
                    background:
                      "linear-gradient(90deg, #59b7d1 0%, #0099ff 60%, #4ccfff 100%)",
                    transition: "width 900ms cubic-bezier(0.22,1,0.36,1)",
                  }}
                />
              </div>
            </div>
          )}

          <div className="insight-row grid grid-cols-2 gap-3">
            {stations !== undefined && (
              <MetaChip
                label="Estaciones"
                value={`${stations}`}
              />
            )}
            {range && (
              <MetaChip
                label="Rango AQI"
                value={`${Math.round(range.low)}–${Math.round(range.high)}`}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function InsightPill({
  icon,
  label,
  text,
  accent = "#4ccfff",
}: {
  icon: React.ReactNode;
  label: string;
  text: string;
  accent?: string;
}) {
  return (
    <div
      className="insight-row rounded-2xl p-3.5 flex items-start gap-2.5"
      style={{
        background: "rgba(255,255,255,0.05)",
        border: "1px solid rgba(255,255,255,0.08)",
      }}
    >
      <div
        className="shrink-0 h-7 w-7 rounded-full grid place-items-center mt-0.5"
        style={{
          background: `${accent}22`,
          color: accent,
        }}
      >
        {icon}
      </div>
      <div className="min-w-0">
        <div
          className="text-[10px] font-mono uppercase tracking-[0.14em]"
          style={{ color: accent }}
        >
          {label}
        </div>
        <p className="text-[13px] text-white/85 leading-relaxed mt-0.5">
          {text}
        </p>
      </div>
    </div>
  );
}

function MetaChip({ label, value }: { label: string; value: string }) {
  return (
    <div
      className="rounded-xl p-3 flex flex-col gap-0.5"
      style={{
        background: "rgba(255,255,255,0.05)",
        border: "1px solid rgba(255,255,255,0.08)",
      }}
    >
      <span className="text-[10px] font-mono uppercase tracking-[0.14em] text-white/50">
        {label}
      </span>
      <span className="aw-number text-base text-white font-semibold">
        {value}
      </span>
    </div>
  );
}
