"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { cn } from "@/lib/utils";

interface Props {
  label: string;
  value: number;
  unit: string;
  sign?: "plus" | "minus";
  /** max expected value, used for gauge scaling */
  max: number;
  color: string;
  description?: string;
  delay?: number;
}

export function BiometricMetric({
  label,
  value,
  unit,
  sign = "minus",
  max,
  color,
  description,
  delay = 0,
}: Props) {
  const valueRef = useRef<HTMLSpanElement>(null);
  const barRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      // Counter tween
      if (valueRef.current) {
        const obj = { v: 0 };
        gsap.to(obj, {
          v: value,
          duration: 1.4,
          ease: "power3.out",
          delay,
          onUpdate: () => {
            if (valueRef.current) {
              valueRef.current.textContent = obj.v.toFixed(
                value < 5 ? 2 : 1,
              );
            }
          },
        });
      }
      // Gauge sweep
      if (barRef.current) {
        const pct = Math.min(Math.abs(value) / max, 1) * 100;
        gsap.fromTo(
          barRef.current,
          { width: "0%" },
          {
            width: `${pct}%`,
            duration: 1.4,
            ease: "power3.out",
            delay,
          },
        );
      }
    });
    return () => ctx.revert();
  }, [value, max, delay]);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="aw-eyebrow text-[10px]">{label}</span>
      </div>
      <div className="flex items-baseline gap-1.5">
        <span
          className={cn(
            "aw-number text-sm font-mono font-bold",
            sign === "plus" ? "text-aw-danger" : "text-aw-accent",
          )}
        >
          {sign === "plus" ? "+" : "−"}
        </span>
        <span
          ref={valueRef}
          className="aw-display aw-number text-2xl text-aw-primary leading-none"
        >
          0.00
        </span>
        <span className="text-[10px] font-medium text-aw-ink-muted">
          {unit}
        </span>
      </div>
      <div className="h-1.5 rounded-full bg-aw-border overflow-hidden">
        <div
          ref={barRef}
          className="h-full rounded-full"
          style={{
            background: `linear-gradient(90deg, ${color}80, ${color})`,
            width: "0%",
          }}
        />
      </div>
      {description && (
        <span className="text-[10px] text-aw-ink-muted leading-snug">
          {description}
        </span>
      )}
    </div>
  );
}
