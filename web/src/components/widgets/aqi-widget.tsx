"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { aqiMeta } from "@/lib/aqi";

interface Props {
  aqi: number;
  location?: string;
  size?: number;
}

export function AQIWidget({ aqi, location = "Actual", size = 220 }: Props) {
  const ringRef = useRef<SVGCircleElement>(null);
  const valRef = useRef<HTMLDivElement>(null);

  const meta = aqiMeta(aqi);
  const r = (size - 28) / 2;
  const c = 2 * Math.PI * r;
  const pct = Math.min(aqi / 300, 1);

  useEffect(() => {
    const ctx = gsap.context(() => {
      if (ringRef.current) {
        gsap.fromTo(
          ringRef.current,
          { strokeDashoffset: c },
          {
            strokeDashoffset: c * (1 - pct),
            duration: 1.6,
            ease: "power3.out",
          },
        );
      }
      if (valRef.current) {
        const obj = { v: 0 };
        gsap.to(obj, {
          v: aqi,
          duration: 1.6,
          ease: "power3.out",
          onUpdate: () => {
            if (valRef.current)
              valRef.current.textContent = Math.round(obj.v).toString();
          },
        });
      }
    });
    return () => ctx.revert();
  }, [aqi, c, pct]);

  return (
    <div
      className="relative rounded-[32px] p-5 flex flex-col justify-between text-white overflow-hidden"
      style={{
        width: size,
        height: size,
        background: "#0a0a0f",
        boxShadow:
          "0 20px 50px rgba(10,29,77,0.35), inset 0 0 0 1px rgba(255,255,255,0.08)",
      }}
    >
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background: `radial-gradient(circle at 70% 20%, ${meta.color}25 0%, transparent 60%)`,
        }}
      />
      <div className="relative flex items-center justify-between">
        <span className="text-[10px] uppercase tracking-widest font-mono opacity-70">
          AQI
        </span>
        <span
          className="h-2 w-2 rounded-full"
          style={{
            background: meta.color,
            boxShadow: `0 0 8px ${meta.color}`,
          }}
        />
      </div>

      <div className="relative flex items-center justify-center my-2">
        <svg
          width={size - 40}
          height={size - 40}
          viewBox={`0 0 ${size} ${size}`}
          className="-rotate-90"
        >
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            stroke="rgba(255,255,255,0.08)"
            strokeWidth="8"
            fill="none"
          />
          <circle
            ref={ringRef}
            cx={size / 2}
            cy={size / 2}
            r={r}
            stroke={meta.color}
            strokeWidth="8"
            strokeLinecap="round"
            fill="none"
            strokeDasharray={c}
            strokeDashoffset={c}
            style={{ filter: `drop-shadow(0 0 10px ${meta.color})` }}
          />
        </svg>
        <div className="absolute text-center">
          <div
            ref={valRef}
            className="aw-display aw-number text-4xl leading-none"
            style={{ color: meta.color }}
          >
            0
          </div>
          <div className="text-[9px] uppercase tracking-widest opacity-60 mt-1">
            {meta.shortLabel}
          </div>
        </div>
      </div>

      <div className="relative text-[10px] opacity-70">{location}</div>
    </div>
  );
}
