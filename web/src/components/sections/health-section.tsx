"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { gsap } from "gsap";
import { SectionHeader } from "@/components/ui/section-header";
import { GlassCard } from "@/components/ui/glass-card";
import { LivePill } from "@/components/ui/live-pill";
import { BiometricSilhouette } from "@/components/health/biometric-silhouette";
import { BiometricMetric } from "@/components/health/biometric-metric";
import {
  PPIProfileSelector,
  type ClinicalProfile,
} from "@/components/health/ppi-profile-selector";
import { ContingencyHorizonCard } from "@/components/health/contingency-horizon";
import { ContingencyDrivers } from "@/components/health/contingency-drivers";
import {
  useContingencyForecast,
  usePPIContext,
} from "@/hooks/use-air-quality";
import { useGeolocation } from "@/hooks/use-geolocation";
import { AlertCircle, Mountain, Thermometer } from "lucide-react";
import { cn } from "@/lib/utils";

export function HealthSection() {
  const geo = useGeolocation();
  const ppi = usePPIContext(geo.coords);
  const contingency = useContingencyForecast(geo.coords);

  const [profile, setProfile] = useState<ClinicalProfile>("healthy");
  const [selectedHorizon, setSelectedHorizon] = useState(0);

  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".health-reveal", {
        y: 40,
        opacity: 0,
        duration: 0.9,
        ease: "power3.out",
        stagger: 0.08,
        scrollTrigger: {
          trigger: root.current,
          start: "top 75%",
          once: true,
        },
      });
    }, root);
    return () => ctx.revert();
  }, []);

  const impact = ppi.data?.expected_biometric_impact;
  const ppiScores = useMemo(() => {
    if (!ppi.data?.ppi_estimates) return undefined;
    const e = ppi.data.ppi_estimates;
    return {
      healthy: e.estimated_ppi_healthy,
      asthmatic: e.estimated_ppi_asthmatic,
      copd: e.estimated_ppi_copd,
      cvd: e.estimated_ppi_cvd,
    };
  }, [ppi.data]);

  const currentPPI = ppiScores?.[profile];
  const riskLevel = ppi.data?.ppi_estimates.risk_level;
  const aqi = ppi.data?.air_quality.aqi ?? 0;
  const intensity = Math.min(aqi / 200, 1);

  const forecasts = contingency.data?.forecasts ?? [];
  const activeHorizon = forecasts[selectedHorizon];

  return (
    <section
      id="health"
      ref={root}
      className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-16 md:py-24 scroll-mt-24"
    >
      <div className="flex flex-col gap-8">
        <div className="health-reveal flex flex-col md:flex-row md:items-end md:justify-between gap-4">
          <SectionHeader
            eyebrow="Fase 6 · Salud"
            title="Tu cuerpo, antes del impacto"
            subtitle="Modelamos la respuesta biométrica esperada a la exposición actual + pronóstico probabilístico de contingencia O₃ a 72 horas."
          />
          <div className="flex flex-wrap items-center gap-2">
            <LivePill>PPI · biométrico</LivePill>
          </div>
        </div>

        {/* --- PPI block --- */}
        <div className="health-reveal grid lg:grid-cols-[1fr_1.4fr] gap-5">
          {/* Silhouette panel */}
          <GlassCard
            variant="default"
            radius="2xl"
            className="relative overflow-hidden p-6 md:p-7 flex flex-col items-center text-center"
          >
            <div
              className="absolute inset-0 pointer-events-none opacity-60"
              style={{
                background:
                  "radial-gradient(circle at 50% 30%, rgba(0,153,255,0.08) 0%, transparent 60%)",
              }}
            />
            <div className="relative">
              <div className="aw-eyebrow">Impacto esperado</div>
              <div className="aw-display text-2xl text-aw-primary mt-1">
                AQI{" "}
                <span className="aw-number">
                  {aqi ? Math.round(aqi) : "—"}
                </span>
              </div>
            </div>
            <div className="relative mt-3">
              <BiometricSilhouette intensity={intensity} />
            </div>
            {riskLevel && (
              <div
                className="mt-2 inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold"
                style={{
                  background:
                    intensity < 0.3
                      ? "rgba(46,125,50,0.12)"
                      : intensity < 0.6
                        ? "rgba(255,143,0,0.12)"
                        : "rgba(255,61,61,0.12)",
                  color:
                    intensity < 0.3
                      ? "#2e7d32"
                      : intensity < 0.6
                        ? "#ff8f00"
                        : "#ff3d3d",
                }}
              >
                Riesgo {riskLevel}
              </div>
            )}
          </GlassCard>

          {/* Metrics + profile */}
          <div className="flex flex-col gap-5">
            <GlassCard variant="default" radius="xl" className="p-6 md:p-7">
              <div className="flex items-center justify-between mb-5">
                <div>
                  <div className="aw-eyebrow">Respuesta biométrica estimada</div>
                  <div className="text-xs text-aw-ink-muted mt-0.5">
                    Basada en curvas dosis-respuesta científicas
                  </div>
                </div>
                {currentPPI !== undefined && (
                  <div className="text-right">
                    <div className="aw-eyebrow">PPI</div>
                    <div className="aw-display text-3xl text-aw-primary">
                      {currentPPI}
                    </div>
                  </div>
                )}
              </div>

              {ppi.isLoading ? (
                <div className="grid sm:grid-cols-2 gap-5">
                  {Array.from({ length: 4 }).map((_, i) => (
                    <div
                      key={i}
                      className="h-20 aw-shimmer bg-aw-border rounded-lg"
                    />
                  ))}
                </div>
              ) : impact ? (
                <div className="grid sm:grid-cols-2 gap-5">
                  <BiometricMetric
                    label="SpO₂"
                    value={impact.spo2_drop_estimate_pp}
                    unit="pp"
                    sign="minus"
                    max={3}
                    color="#0099ff"
                    description="Caída estimada en saturación de oxígeno"
                    delay={0}
                  />
                  <BiometricMetric
                    label="HRV"
                    value={impact.hrv_decrease_estimate_pct}
                    unit="%"
                    sign="minus"
                    max={15}
                    color="#4aa1b3"
                    description="Reducción en variabilidad cardíaca"
                    delay={0.1}
                  />
                  <BiometricMetric
                    label="Frecuencia cardíaca"
                    value={impact.hr_increase_estimate_bpm}
                    unit="bpm"
                    sign="plus"
                    max={12}
                    color="#d32f2f"
                    description="Aumento estimado de pulso en reposo"
                    delay={0.2}
                  />
                  <BiometricMetric
                    label="Respiración"
                    value={impact.resp_increase_estimate_pct}
                    unit="%"
                    sign="plus"
                    max={10}
                    color="#ff8f00"
                    description="Aumento en frecuencia respiratoria"
                    delay={0.3}
                  />
                </div>
              ) : (
                <p className="text-sm text-aw-ink-muted">
                  Sin datos biométricos — verifica el backend.
                </p>
              )}
            </GlassCard>

            <div>
              <div className="aw-eyebrow mb-3">Selecciona tu perfil clínico</div>
              <PPIProfileSelector
                active={profile}
                onChange={setProfile}
                scores={ppiScores}
              />
            </div>

            {ppi.data?.risk_factors && (
              <GlassCard variant="default" radius="lg" className="p-4">
                <div className="flex flex-wrap items-center gap-5 text-xs text-aw-ink-soft">
                  {ppi.data.risk_factors.altitude_m !== undefined && (
                    <RiskFactor
                      icon={Mountain}
                      label="Altitud"
                      value={`${Math.round(ppi.data.risk_factors.altitude_m)} m`}
                    />
                  )}
                  {ppi.data.risk_factors.thermal_inversion_risk !==
                    undefined && (
                    <RiskFactor
                      icon={Thermometer}
                      label="Inversión térmica"
                      value={
                        ppi.data.risk_factors.thermal_inversion_risk
                          ? "Riesgo alto"
                          : "Sin riesgo"
                      }
                      warn={ppi.data.risk_factors.thermal_inversion_risk}
                    />
                  )}
                  {ppi.data.risk_factors.trend && (
                    <RiskFactor
                      icon={AlertCircle}
                      label="Tendencia"
                      value={ppi.data.risk_factors.trend}
                    />
                  )}
                </div>
              </GlassCard>
            )}

            {ppi.data?.recommendation && (
              <GlassCard
                variant="default"
                radius="lg"
                className="p-4 flex items-start gap-3"
              >
                <AlertCircle className="h-4 w-4 text-aw-accent shrink-0 mt-0.5" />
                <p className="text-sm text-aw-ink-soft leading-relaxed">
                  {ppi.data.recommendation}
                </p>
              </GlassCard>
            )}
          </div>
        </div>

        {/* --- Contingency block --- */}
        <div className="health-reveal flex flex-col md:flex-row md:items-end md:justify-between gap-3 mt-6">
          <div>
            <div className="aw-eyebrow">Contingencia O₃ · ZMVM</div>
            <div className="aw-display text-2xl text-aw-primary mt-1">
              Pronóstico probabilístico 72h
            </div>
            <p className="text-sm text-aw-ink-soft mt-1 max-w-2xl">
              3× más horizonte que el aviso oficial. Calibración por cuantiles
              con intervalos de confianza al 80%.
            </p>
          </div>
          {contingency.data?.model_version && (
            <span className="text-[10px] font-mono text-aw-ink-muted uppercase tracking-widest">
              {contingency.data.model_version}
            </span>
          )}
        </div>

        <div className="health-reveal grid md:grid-cols-3 gap-4">
          {contingency.isLoading &&
            Array.from({ length: 3 }).map((_, i) => (
              <GlassCard
                key={i}
                variant="default"
                radius="xl"
                className="h-[220px] aw-shimmer bg-aw-border"
              />
            ))}
          {forecasts.map((f, i) => (
            <button
              key={f.horizon_h}
              onClick={() => setSelectedHorizon(i)}
              className={cn(
                "text-left transition-all",
                i === selectedHorizon
                  ? "ring-2 ring-aw-accent ring-offset-2 ring-offset-white rounded-[inherit]"
                  : "",
              )}
            >
              <ContingencyHorizonCard horizon={f} index={i} />
            </button>
          ))}
        </div>

        <div className="health-reveal">
          <ContingencyDrivers
            horizon={activeHorizon}
            loading={contingency.isLoading}
          />
        </div>

        {contingency.data?.disclaimer && (
          <p className="health-reveal text-[10px] text-aw-ink-muted italic max-w-3xl">
            {contingency.data.disclaimer}
          </p>
        )}
      </div>
    </section>
  );
}

function RiskFactor({
  icon: Icon,
  label,
  value,
  warn = false,
}: {
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
  label: string;
  value: string;
  warn?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <Icon
        className={cn(
          "h-3.5 w-3.5",
          warn ? "text-aw-warning" : "text-aw-ink-muted",
        )}
        strokeWidth={2.3}
      />
      <span className="aw-eyebrow text-[10px]">{label}</span>
      <span
        className={cn(
          "aw-number font-semibold text-sm",
          warn ? "text-aw-warning" : "text-aw-primary",
        )}
      >
        {value}
      </span>
    </div>
  );
}
