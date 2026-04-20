"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";

interface Props {
  intensity?: number; // 0-1 scaling the pulse urgency
}

/**
 * Minimal anatomical silhouette with animated pulse indicators
 * at heart + lungs. Pulse speed scales with exposure intensity.
 */
export function BiometricSilhouette({ intensity = 0.3 }: Props) {
  const heartRef = useRef<SVGCircleElement>(null);
  const leftLungRef = useRef<SVGCircleElement>(null);
  const rightLungRef = useRef<SVGCircleElement>(null);
  const auraRef = useRef<SVGCircleElement>(null);

  useEffect(() => {
    // Heart pulse: 60 bpm at low intensity → 90 bpm at high
    const heartBPM = 60 + intensity * 35;
    const heartPeriod = 60 / heartBPM;
    const lungsPeriod = 4 - intensity * 1.4;

    const ctx = gsap.context(() => {
      if (heartRef.current) {
        gsap.to(heartRef.current, {
          attr: { r: 7 },
          duration: heartPeriod / 2,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
        });
      }
      [leftLungRef.current, rightLungRef.current].forEach((node, i) => {
        if (!node) return;
        gsap.to(node, {
          attr: { r: 9 },
          opacity: 0.9,
          duration: lungsPeriod / 2,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
          delay: i * 0.1,
        });
      });
      if (auraRef.current) {
        gsap.to(auraRef.current, {
          opacity: 0.25 + intensity * 0.25,
          attr: { r: 90 + intensity * 10 },
          duration: 2.8,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
        });
      }
    });

    return () => ctx.revert();
  }, [intensity]);

  const riskColor =
    intensity < 0.3 ? "#2e7d32" : intensity < 0.6 ? "#ff8f00" : "#ff3d3d";

  return (
    <svg
      viewBox="0 0 200 260"
      className="w-full max-w-[220px]"
      aria-hidden
    >
      <defs>
        <radialGradient id="aura-gradient">
          <stop offset="0%" stopColor={riskColor} stopOpacity="0.25" />
          <stop offset="100%" stopColor={riskColor} stopOpacity="0" />
        </radialGradient>
        <linearGradient id="silhouette-gradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#0a1d4d" stopOpacity="0.85" />
          <stop offset="100%" stopColor="#4aa1b3" stopOpacity="0.85" />
        </linearGradient>
      </defs>

      {/* Risk aura */}
      <circle
        ref={auraRef}
        cx="100"
        cy="120"
        r="90"
        fill="url(#aura-gradient)"
      />

      {/* Body silhouette */}
      <path
        d="M100 24
           C 86 24 78 34 78 46
           C 78 56 84 62 90 66
           L 88 80
           C 70 86 58 98 56 118
           L 60 150
           C 62 170 68 180 66 200
           L 70 230
           L 82 230
           L 86 204
           L 90 178
           L 100 178
           L 110 178
           L 114 204
           L 118 230
           L 130 230
           L 134 200
           C 132 180 138 170 140 150
           L 144 118
           C 142 98 130 86 112 80
           L 110 66
           C 116 62 122 56 122 46
           C 122 34 114 24 100 24 Z"
        fill="url(#silhouette-gradient)"
        opacity="0.95"
      />

      {/* Left lung */}
      <circle ref={leftLungRef} cx="84" cy="118" r="7" fill="#59b7d1" opacity="0.8" />
      {/* Right lung */}
      <circle ref={rightLungRef} cx="116" cy="118" r="7" fill="#59b7d1" opacity="0.8" />
      {/* Heart */}
      <circle ref={heartRef} cx="95" cy="128" r="5" fill="#ff3d3d" />

      {/* Connector lines to labels */}
      <g
        stroke="rgba(255,255,255,0.55)"
        strokeWidth="1"
        strokeDasharray="2 3"
        fill="none"
      >
        <path d="M84 118 L 30 100" />
        <path d="M95 128 L 170 150" />
      </g>

      {/* Label pins */}
      <g>
        <circle cx="30" cy="100" r="2.5" fill="#59b7d1" />
        <circle cx="170" cy="150" r="2.5" fill="#ff3d3d" />
      </g>
    </svg>
  );
}
