"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";

/**
 * Fullscreen animated background with aurora gradient blobs.
 * Sits behind all content. Pointer-events: none.
 */
export function AuroraBackground() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced) return;

    const ctx = gsap.context(() => {
      const blobs = ref.current?.querySelectorAll<HTMLDivElement>(".aw-aurora-blob");
      if (!blobs) return;
      blobs.forEach((blob, i) => {
        gsap.to(blob, {
          x: `random(-80, 80)`,
          y: `random(-60, 60)`,
          scale: `random(0.9, 1.15)`,
          duration: 18 + i * 4,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
          delay: i * 0.8,
        });
      });
    }, ref);

    return () => ctx.revert();
  }, []);

  return (
    <div ref={ref} className="aw-aurora" aria-hidden>
      <div
        className="aw-aurora-blob"
        style={{
          top: "-10%",
          left: "-8%",
          width: "52vmax",
          height: "52vmax",
          background: "radial-gradient(circle, #59b7d1 0%, transparent 70%)",
        }}
      />
      <div
        className="aw-aurora-blob"
        style={{
          top: "10%",
          right: "-12%",
          width: "44vmax",
          height: "44vmax",
          background: "radial-gradient(circle, #0099ff 0%, transparent 70%)",
          opacity: 0.35,
        }}
      />
      <div
        className="aw-aurora-blob"
        style={{
          bottom: "-18%",
          left: "20%",
          width: "58vmax",
          height: "58vmax",
          background: "radial-gradient(circle, #4aa1b3 0%, transparent 72%)",
          opacity: 0.3,
        }}
      />
      <div
        className="aw-aurora-blob"
        style={{
          bottom: "8%",
          right: "14%",
          width: "36vmax",
          height: "36vmax",
          background: "radial-gradient(circle, #b5e7f3 0%, transparent 72%)",
          opacity: 0.5,
        }}
      />
    </div>
  );
}
