"use client";

import { useEffect, useRef, useState } from "react";
import { gsap } from "gsap";
import { SectionHeader } from "@/components/ui/section-header";
import { GlassCard } from "@/components/ui/glass-card";
import { LivePill } from "@/components/ui/live-pill";
import { AirwayMap } from "@/components/map/airway-map";
import { MapLegend } from "@/components/map/map-legend";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useAirHeatmap } from "@/hooks/use-air-quality";
import { MapPin, Bike, Footprints, Layers } from "lucide-react";
import { cn } from "@/lib/utils";

type TransportMode = "bike" | "walk";

export function MapSection() {
  const geo = useGeolocation();
  const [mode, setMode] = useState<TransportMode>("bike");

  const heatmap = useAirHeatmap(geo.coords, 8, 15);

  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".map-reveal", {
        y: 40,
        opacity: 0,
        duration: 1,
        ease: "power3.out",
        stagger: 0.12,
        scrollTrigger: {
          trigger: root.current,
          start: "top 72%",
          once: true,
        },
      });
    }, root);
    return () => ctx.revert();
  }, []);

  return (
    <section
      id="map"
      ref={root}
      className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-16 md:py-24 scroll-mt-24"
    >
      <div className="flex flex-col gap-8">
        <div className="map-reveal flex flex-col md:flex-row md:items-end md:justify-between gap-4">
          <SectionHeader
            eyebrow="Fase 4 · Mapa"
            title="Heatmap IDW multi-fuente"
            subtitle="OpenAQ, WAQI y CAMS fusionados con interpolación IDW, corrección altitudinal y predicción ML a +1h. Grid de 15×15 puntos actualizado cada 10 min."
          />
          <div className="flex items-center gap-2">
            <LivePill>Heatmap · 10 min</LivePill>
          </div>
        </div>

        <div className="map-reveal grid lg:grid-cols-[1fr_320px] gap-5">
          <GlassCard
            variant="default"
            radius="2xl"
            className="relative overflow-hidden min-h-[560px] p-0"
          >
            <div className="absolute inset-0 rounded-[inherit] overflow-hidden">
              <AirwayMap
                center={geo.coords}
                heatmap={heatmap.data}
                className="h-full"
              />
            </div>

            <div className="absolute top-4 left-4 z-10">
              <div className="aw-glass-strong rounded-full pl-3 pr-4 py-2 flex items-center gap-2 text-xs">
                <MapPin className="h-3.5 w-3.5 text-aw-accent" />
                <span className="aw-number text-aw-primary font-medium">
                  {geo.coords
                    ? `${geo.coords.lat.toFixed(3)}, ${geo.coords.lon.toFixed(3)}`
                    : "Localizando…"}
                </span>
                <span className="text-aw-ink-muted">·</span>
                <span className="text-aw-ink-soft">
                  {heatmap.data?.points.length ?? 0} puntos
                </span>
              </div>
            </div>
          </GlassCard>

          <div className="flex flex-col gap-4">
            <GlassCard variant="default" radius="lg" className="p-4">
              <div className="aw-eyebrow mb-3">Modo de análisis</div>
              <div className="grid grid-cols-2 gap-2">
                <ModeButton
                  active={mode === "bike"}
                  onClick={() => setMode("bike")}
                  icon={Bike}
                  label="Bicicleta"
                />
                <ModeButton
                  active={mode === "walk"}
                  onClick={() => setMode("walk")}
                  icon={Footprints}
                  label="Caminata"
                />
              </div>
            </GlassCard>

            <GlassCard variant="default" radius="lg" className="p-4">
              <MapLegend />
            </GlassCard>

            <GlassCard variant="default" radius="lg" className="p-4">
              <div className="flex items-start gap-3">
                <div className="h-9 w-9 rounded-lg bg-aw-primary/10 grid place-items-center shrink-0">
                  <Layers className="h-4 w-4 text-aw-primary" />
                </div>
                <div className="flex flex-col">
                  <div className="aw-eyebrow">Cobertura</div>
                  <span className="aw-number text-sm text-aw-primary mt-0.5">
                    {heatmap.data?.radius_km
                      ? `Radio ${heatmap.data.radius_km}km · ${heatmap.data.points.length} puntos`
                      : "—"}
                  </span>
                  <p className="text-[11px] text-aw-ink-muted mt-1 leading-relaxed">
                    Interpolación IDW con peso adaptativo: prioriza estaciones
                    cercanas y corrige por altitud e inversión térmica.
                  </p>
                </div>
              </div>
            </GlassCard>
          </div>
        </div>
      </div>
    </section>
  );
}

function ModeButton({
  active,
  onClick,
  icon: Icon,
  label,
}: {
  active: boolean;
  onClick: () => void;
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
  label: string;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "flex items-center justify-center gap-2 rounded-xl py-2.5 text-xs font-medium transition-all",
        active
          ? "bg-aw-primary text-white shadow-sm"
          : "bg-white/60 text-aw-ink-soft hover:bg-white hover:text-aw-primary border border-aw-border",
      )}
    >
      <Icon className="h-3.5 w-3.5" strokeWidth={2.4} />
      {label}
    </button>
  );
}
