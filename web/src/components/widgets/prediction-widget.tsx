"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { Activity } from "lucide-react";
import { aqiMeta } from "@/lib/aqi";

interface Props {
  size?: number;
  current: number;
  predicted6h: number;
}

export function PredictionWidget({
  size = 220,
  current,
  predicted6h,
}: Props) {
  const ref = useRef<HTMLDivElement>(null);
  const valRef = useRef<HTMLDivElement>(null);
  const pathRef = useRef<SVGPathElement>(null);
  const delta = predicted6h - current;
  const meta = aqiMeta(predicted6h);
  const color = delta < -5 ? "#2e7d32" : delta > 5 ? "#ff3d3d" : "#0099ff";

  useEffect(() => {
    const ctx = gsap.context(() => {
      if (valRef.current) {
        const obj = { v: current };
        gsap.to(obj, {
          v: predicted6h,
          duration: 1.6,
          ease: "power3.out",
          onUpdate: () => {
            if (valRef.current)
              valRef.current.textContent = Math.round(obj.v).toString();
          },
        });
      }
      if (pathRef.current) {
        const len = pathRef.current.getTotalLength?.() ?? 200;
        gsap.fromTo(
          pathRef.current,
          { strokeDasharray: len, strokeDashoffset: len },
          { strokeDashoffset: 0, duration: 1.6, ease: "power2.out" },
        );
      }
    });
    return () => ctx.revert();
  }, [current, predicted6h]);

  return (
    <div
      ref={ref}
      className="relative rounded-[32px] p-5 flex flex-col justify-between text-white overflow-hidden"
      style={{
        width: size,
        height: size,
        background:
          "linear-gradient(145deg, #0a1d4d 0%, #102a6b 50%, #061020 100%)",
        boxShadow:
          "0 20px 50px rgba(10,29,77,0.35), inset 0 0 0 1px rgba(255,255,255,0.08)",
      }}
    >
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background: `radial-gradient(circle at 70% 40%, ${color}28 0%, transparent 60%)`,
        }}
      />

      <div className="relative flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <Activity className="h-3 w-3 opacity-70" strokeWidth={2.3} />
          <span className="text-[10px] uppercase tracking-widest font-mono opacity-70">
            ML · 6 h
          </span>
        </div>
        <span
          className="text-[10px] aw-number font-bold px-1.5 py-0.5 rounded"
          style={{ background: `${color}25`, color }}
        >
          {delta > 0 ? "+" : ""}
          {delta}
        </span>
      </div>

      <div className="relative flex-1 flex items-center justify-center">
        <svg width="100" height="50" viewBox="0 0 100 50" className="absolute bottom-0">
          <path
            ref={pathRef}
            d="M 0 35 Q 20 15, 40 22 T 80 18 L 100 14"
            fill="none"
            stroke={color}
            strokeWidth="2.5"
            strokeLinecap="round"
          />
        </svg>
        <div className="text-center">
          <div
            ref={valRef}
            className="aw-display aw-number text-4xl leading-none"
            style={{ color: meta.color }}
          >
            {current}
          </div>
          <div className="text-[9px] uppercase tracking-widest opacity-60 mt-1">
            {meta.shortLabel}
          </div>
        </div>
      </div>

      <div className="relative text-[10px] opacity-70">
        Predicción 6 h adelante
      </div>
    </div>
  );
}
