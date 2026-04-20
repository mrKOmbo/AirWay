"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { GlassCard } from "@/components/ui/glass-card";
import { LivePill } from "@/components/ui/live-pill";
import { useFuelPrices } from "@/hooks/use-trip-fuel";
import { Droplets, Flame } from "lucide-react";
import { cn } from "@/lib/utils";

const FUEL_META = [
  {
    key: "magna",
    label: "Magna",
    octane: "87",
    color: "#2e7d32",
    icon: Droplets,
  },
  {
    key: "premium",
    label: "Premium",
    octane: "91+",
    color: "#ff3d3d",
    icon: Flame,
  },
  {
    key: "diesel",
    label: "Diesel",
    octane: "Diesel",
    color: "#0a1d4d",
    icon: Droplets,
  },
] as const;

export function FuelPricesPanel() {
  const prices = useFuelPrices();
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".fuel-tile", {
        y: 16,
        opacity: 0,
        duration: 0.7,
        ease: "power3.out",
        stagger: 0.08,
      });
    }, ref);
    return () => ctx.revert();
  }, []);

  return (
    <div className="flex flex-col gap-4" ref={ref}>
      <div className="flex items-center justify-between">
        <div>
          <div className="aw-eyebrow">Precios de gasolina · Profeco</div>
          <div className="text-xs text-aw-ink-muted mt-0.5">
            {prices.data?.source ?? "Fuente oficial"}
            {prices.data?.updated_at && (
              <>
                {" · "}
                <span className="aw-number">
                  {formatRelative(prices.data.updated_at)}
                </span>
              </>
            )}
          </div>
        </div>
        <LivePill>30 min</LivePill>
      </div>

      <div className="grid grid-cols-3 gap-3">
        {FUEL_META.map((f) => {
          const price = prices.data?.[f.key as "magna" | "premium" | "diesel"];
          const Icon = f.icon;
          return (
            <div
              key={f.key}
              className={cn(
                "fuel-tile relative overflow-hidden rounded-2xl p-4 border border-aw-border bg-white/70 backdrop-blur",
              )}
            >
              <div
                className="pointer-events-none absolute -top-8 -right-8 h-24 w-24 rounded-full blur-2xl opacity-30"
                style={{ background: f.color }}
              />
              <div className="relative flex items-center gap-2">
                <span
                  className="h-7 w-7 rounded-lg grid place-items-center"
                  style={{
                    background: `${f.color}18`,
                    color: f.color,
                  }}
                >
                  <Icon className="h-3.5 w-3.5" strokeWidth={2.3} />
                </span>
                <div>
                  <div className="text-xs font-semibold text-aw-primary">
                    {f.label}
                  </div>
                  <div className="aw-eyebrow text-[9px]">
                    Octanaje {f.octane}
                  </div>
                </div>
              </div>
              <div className="relative mt-3 flex items-baseline gap-1">
                <span className="aw-number text-xs text-aw-ink-muted">$</span>
                <span
                  className="aw-display aw-number text-2xl leading-none"
                  style={{ color: f.color }}
                >
                  {prices.isLoading
                    ? "—"
                    : price !== undefined
                      ? price.toFixed(2)
                      : "—"}
                </span>
                <span className="text-[10px] font-medium text-aw-ink-muted">
                  MXN/L
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function formatRelative(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.max(0, Math.floor(diff / 60000));
  if (mins < 1) return "hace unos segundos";
  if (mins < 60) return `hace ${mins} min`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `hace ${hrs} h`;
  const days = Math.floor(hrs / 24);
  return `hace ${days} d`;
}
