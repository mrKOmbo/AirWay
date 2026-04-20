"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { aqiMeta } from "@/lib/aqi";

interface AQIDialProps {
  aqi: number;
  size?: number;
}

/**
 * Circular AQI dial — animated stroke + center counter.
 * Driven by GSAP so the tween lives with the DOM, not React state.
 */
export function AQIDial({ aqi, size = 280 }: AQIDialProps) {
  const meta = aqiMeta(aqi);
  const circleRef = useRef<SVGCircleElement>(null);
  const numberRef = useRef<HTMLDivElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);

  const stroke = 14;
  const r = (size - stroke) / 2;
  const circumference = 2 * Math.PI * r;
  const maxAQI = 300;
  const pct = Math.min(aqi / maxAQI, 1);

  useEffect(() => {
    if (!circleRef.current || !numberRef.current) return;

    const ctx = gsap.context(() => {
      // Stroke reveal
      gsap.fromTo(
        circleRef.current,
        { strokeDashoffset: circumference },
        {
          strokeDashoffset: circumference * (1 - pct),
          duration: 2,
          ease: "power3.out",
        },
      );

      // Number counter
      const obj = { v: 0 };
      gsap.to(obj, {
        v: aqi,
        duration: 2,
        ease: "power3.out",
        onUpdate: () => {
          if (numberRef.current) {
            numberRef.current.textContent = Math.round(obj.v).toString();
          }
        },
      });

      // Glow pulse
      if (glowRef.current) {
        gsap.to(glowRef.current, {
          scale: 1.08,
          opacity: 0.85,
          duration: 2.4,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
        });
      }
    });

    return () => ctx.revert();
  }, [aqi, circumference, pct]);

  return (
    <div
      className="relative flex items-center justify-center"
      style={{ width: size, height: size }}
    >
      {/* Glow layer */}
      <div
        ref={glowRef}
        aria-hidden
        className="absolute inset-2 rounded-full blur-2xl opacity-60"
        style={{ background: meta.gradient }}
      />

      {/* Ring */}
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        className="relative -rotate-90"
      >
        <defs>
          <linearGradient id={`aqi-stroke-${meta.level}`} x1="0" x2="1" y1="0" y2="1">
            <stop offset="0%" stopColor={meta.color} />
            <stop
              offset="100%"
              stopColor={
                meta.level === "good"
                  ? "#4aa1b3"
                  : meta.level === "moderate"
                    ? "#ff8f00"
                    : meta.level === "sensitive"
                      ? "#ff3d3d"
                      : meta.level === "unhealthy"
                        ? "#9c27b0"
                        : "#6b0022"
              }
            />
          </linearGradient>
        </defs>
        {/* Track */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="rgba(10,29,77,0.08)"
          strokeWidth={stroke}
        />
        {/* Progress */}
        <circle
          ref={circleRef}
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={`url(#aqi-stroke-${meta.level})`}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference}
          style={{ filter: `drop-shadow(0 0 16px ${meta.color}66)` }}
        />
      </svg>

      {/* Center */}
      <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
        <span className="aw-eyebrow">AQI Live</span>
        <div
          ref={numberRef}
          className="aw-display aw-number text-[84px] leading-none"
          style={{
            backgroundImage: meta.gradient,
            WebkitBackgroundClip: "text",
            backgroundClip: "text",
            color: "transparent",
          }}
        >
          0
        </div>
        <span className="mt-1 text-sm font-medium text-aw-primary">
          {meta.label}
        </span>
      </div>
    </div>
  );
}
