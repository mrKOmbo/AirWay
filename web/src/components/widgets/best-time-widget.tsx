"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { Sun } from "lucide-react";

interface Props {
  size?: number;
  window?: { start: string; end: string; aqi: number };
}

export function BestTimeWidget({
  size = 220,
  window = { start: "07:00", end: "09:00", aqi: 38 },
}: Props) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".bt-dial", {
        scale: 0.85,
        opacity: 0,
        duration: 1,
        ease: "power3.out",
      });
    }, ref);
    return () => ctx.revert();
  }, []);

  return (
    <div
      ref={ref}
      className="relative rounded-[32px] p-5 flex flex-col justify-between text-white overflow-hidden"
      style={{
        width: size,
        height: size,
        background:
          "linear-gradient(145deg, #2e1a05 0%, #3d2a08 50%, #1a1004 100%)",
        boxShadow:
          "0 20px 50px rgba(10,29,77,0.35), inset 0 0 0 1px rgba(255,255,255,0.08)",
      }}
    >
      <div
        className="absolute inset-0 pointer-events-none opacity-60"
        style={{
          background:
            "radial-gradient(circle at 30% 30%, rgba(255,212,0,0.2) 0%, transparent 60%)",
        }}
      />

      <div className="relative flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <Sun className="h-3 w-3 text-[#ffd400]" strokeWidth={2.3} />
          <span className="text-[10px] uppercase tracking-widest font-mono opacity-70">
            Ventana óptima
          </span>
        </div>
      </div>

      <div className="relative bt-dial flex-1 flex flex-col items-center justify-center my-3">
        <div className="aw-display text-3xl font-bold text-[#ffd400] tracking-tight">
          {window.start}
        </div>
        <div className="text-[9px] uppercase tracking-widest opacity-60 my-1">
          hasta
        </div>
        <div className="aw-display text-3xl font-bold text-[#ffd400] tracking-tight">
          {window.end}
        </div>
      </div>

      <div className="relative flex items-center justify-between text-[10px]">
        <span className="opacity-60">AQI promedio</span>
        <span className="aw-number font-semibold">{window.aqi}</span>
      </div>
    </div>
  );
}
