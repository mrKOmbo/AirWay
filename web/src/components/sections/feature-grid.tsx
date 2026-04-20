"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { GlassCard } from "@/components/ui/glass-card";
import { SectionHeader } from "@/components/ui/section-header";
import {
  Map as MapIcon,
  Activity,
  Heart,
  Fuel,
  CloudLightning,
  Route,
  type LucideIcon,
} from "lucide-react";

interface Feature {
  icon: LucideIcon;
  title: string;
  description: string;
  accent: string;
  stat: string;
  statLabel: string;
}

const FEATURES: Feature[] = [
  {
    icon: MapIcon,
    title: "Heatmap IDW Multi-fuente",
    description:
      "Interpola OpenAQ + WAQI + CAMS con corrección altitudinal y por viento. 15×15 grid, actualización cada 10 min.",
    accent: "#0099ff",
    stat: "9+",
    statLabel: "fuentes fusionadas",
  },
  {
    icon: Route,
    title: "Rutas AQI-weighted",
    description:
      "Dijkstra modificado: score = α·distancia + β·exposición. Muestrea AQI cada 150m y predice al llegar.",
    accent: "#4aa1b3",
    stat: "3×",
    statLabel: "alternativas por viaje",
  },
  {
    icon: Activity,
    title: "Predicción ML 1h · 3h · 6h",
    description:
      "XGBoost + 49 features: contaminantes, meteo, lags y rolling stats. R² 0.85 en 1h.",
    accent: "#59b7d1",
    stat: "85%",
    statLabel: "accuracy a 1h",
  },
  {
    icon: Heart,
    title: "PPI Biométrico",
    description:
      "Estima impacto esperado en SpO₂, HRV, ritmo cardíaco y respiración según tu perfil clínico.",
    accent: "#d32f2f",
    stat: "4",
    statLabel: "perfiles clínicos",
  },
  {
    icon: CloudLightning,
    title: "Contingencia O₃ · 72h",
    description:
      "Pronóstico probabilístico calibrado por cuantiles. 3× más horizonte que SEDEMA.",
    accent: "#9c27b0",
    stat: "72h",
    statLabel: "de anticipación",
  },
  {
    icon: Fuel,
    title: "Fuel + CO₂",
    description:
      "Catálogo CONUEE de 1,200+ vehículos, precios Profeco en vivo, costo y CO₂ por ruta.",
    accent: "#ff8f00",
    stat: "1.2k",
    statLabel: "vehículos catálogo",
  },
];

export function FeatureGrid() {
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".feature-card", {
        y: 40,
        opacity: 0,
        duration: 0.9,
        ease: "power3.out",
        stagger: 0.08,
        scrollTrigger: {
          trigger: root.current,
          start: "top 80%",
          once: true,
        },
      });
    }, root);
    return () => ctx.revert();
  }, []);

  return (
    <section className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-16 md:py-24">
      <div ref={root}>
        <SectionHeader
          eyebrow="Capacidades"
          title="Datos duros. Decisiones simples."
          subtitle="Cada sección del dashboard consume un endpoint real del backend — sin mocks, sin pipelines fake."
          className="mb-12"
        />
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {FEATURES.map((f) => (
            <FeatureCard key={f.title} feature={f} />
          ))}
        </div>
      </div>
    </section>
  );
}

function FeatureCard({ feature }: { feature: Feature }) {
  const Icon = feature.icon;
  return (
    <GlassCard
      variant="default"
      radius="xl"
      className="feature-card p-6 flex flex-col gap-5 h-full group hover:-translate-y-1 transition-transform duration-500"
    >
      <div className="flex items-start justify-between">
        <div
          className="rounded-2xl p-3 shadow-sm"
          style={{
            background: `linear-gradient(135deg, ${feature.accent}20 0%, ${feature.accent}05 100%)`,
            boxShadow: `inset 0 0 0 1px ${feature.accent}20`,
          }}
        >
          <Icon className="h-5 w-5" style={{ color: feature.accent }} strokeWidth={2.2} />
        </div>
        <div className="text-right">
          <div
            className="aw-display aw-number text-3xl leading-none"
            style={{ color: feature.accent }}
          >
            {feature.stat}
          </div>
          <div className="aw-eyebrow text-[9px] mt-0.5">{feature.statLabel}</div>
        </div>
      </div>

      <div className="space-y-2">
        <h3 className="text-lg font-semibold text-aw-primary tracking-tight">
          {feature.title}
        </h3>
        <p className="text-sm text-aw-ink-soft leading-relaxed">
          {feature.description}
        </p>
      </div>
    </GlassCard>
  );
}
