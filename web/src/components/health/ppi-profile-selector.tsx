"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { cn } from "@/lib/utils";
import { Heart, Shield, Activity, Zap, type LucideIcon } from "lucide-react";

export type ClinicalProfile = "healthy" | "asthmatic" | "copd" | "cvd";

interface ProfileMeta {
  key: ClinicalProfile;
  label: string;
  shortLabel: string;
  icon: LucideIcon;
  accent: string;
  description: string;
}

export const PROFILES: ProfileMeta[] = [
  {
    key: "healthy",
    label: "Sano",
    shortLabel: "Sano",
    icon: Shield,
    accent: "#2e7d32",
    description: "Sin condiciones respiratorias o cardiovasculares.",
  },
  {
    key: "asthmatic",
    label: "Asmático",
    shortLabel: "Asma",
    icon: Activity,
    accent: "#0099ff",
    description: "Asma diagnosticada, broncoreactividad elevada.",
  },
  {
    key: "copd",
    label: "EPOC",
    shortLabel: "EPOC",
    icon: Zap,
    accent: "#ff8f00",
    description: "Enfermedad pulmonar obstructiva crónica.",
  },
  {
    key: "cvd",
    label: "Cardiovascular",
    shortLabel: "CV",
    icon: Heart,
    accent: "#d32f2f",
    description: "Riesgo cardiovascular (hipertensión, arritmia).",
  },
];

interface Props {
  active: ClinicalProfile;
  onChange: (p: ClinicalProfile) => void;
  scores?: Record<ClinicalProfile, number>;
}

export function PPIProfileSelector({ active, onChange, scores }: Props) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".profile-chip", {
        y: 12,
        opacity: 0,
        duration: 0.6,
        ease: "power3.out",
        stagger: 0.08,
      });
    }, ref);
    return () => ctx.revert();
  }, []);

  return (
    <div ref={ref} className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      {PROFILES.map((p) => {
        const Icon = p.icon;
        const isActive = p.key === active;
        const ppi = scores?.[p.key];
        return (
          <button
            key={p.key}
            onClick={() => onChange(p.key)}
            className={cn(
              "profile-chip text-left rounded-2xl p-4 border transition-all group",
              isActive
                ? "bg-white shadow-[var(--shadow-aw-md)]"
                : "bg-white/60 hover:bg-white border-aw-border",
            )}
            style={
              isActive
                ? ({
                    borderColor: p.accent,
                    boxShadow: `0 10px 28px ${p.accent}20, 0 0 0 1px ${p.accent}`,
                  } as React.CSSProperties)
                : undefined
            }
          >
            <div className="flex items-center justify-between mb-2.5">
              <span
                className="h-8 w-8 rounded-lg grid place-items-center"
                style={{
                  background: isActive ? p.accent : `${p.accent}18`,
                  color: isActive ? "white" : p.accent,
                }}
              >
                <Icon className="h-4 w-4" strokeWidth={2.3} />
              </span>
              {ppi !== undefined && (
                <span
                  className="aw-number text-[10px] px-1.5 py-0.5 rounded font-bold"
                  style={{
                    background: `${p.accent}12`,
                    color: p.accent,
                  }}
                >
                  PPI {ppi}
                </span>
              )}
            </div>
            <div className="text-sm font-semibold text-aw-primary">
              {p.label}
            </div>
            <p className="text-[10px] text-aw-ink-muted mt-1 leading-snug line-clamp-2">
              {p.description}
            </p>
          </button>
        );
      })}
    </div>
  );
}
