"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { Wind } from "lucide-react";

interface Props {
  size?: number;
  hourly?: number[];
  goalAqi?: number;
}

const MOCK_HOURS = [38, 42, 55, 68, 82, 92, 88, 76, 62, 50, 45, 48];

export function ExposureWidget({
  size = 220,
  hourly = MOCK_HOURS,
  goalAqi = 50,
}: Props) {
  const ref = useRef<HTMLDivElement>(null);
  const max = Math.max(...hourly, goalAqi * 1.2);

  useEffect(() => {
    if (!ref.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".exp-bar", {
        scaleY: 0,
        transformOrigin: "bottom",
        duration: 0.9,
        ease: "power3.out",
        stagger: 0.04,
      });
    }, ref);
    return () => ctx.revert();
  }, []);

  const avg = hourly.reduce((a, b) => a + b, 0) / hourly.length;
  const overGoal = hourly.filter((v) => v > goalAqi).length;

  return (
    <div
      ref={ref}
      className="relative rounded-[32px] p-5 flex flex-col justify-between text-white overflow-hidden"
      style={{
        width: size,
        height: size,
        background:
          "linear-gradient(145deg, #061018 0%, #0a1b2e 50%, #0a1d4d 100%)",
        boxShadow:
          "0 20px 50px rgba(10,29,77,0.35), inset 0 0 0 1px rgba(255,255,255,0.08)",
      }}
    >
      <div className="relative flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <Wind className="h-3 w-3 opacity-70" strokeWidth={2.3} />
          <span className="text-[10px] uppercase tracking-widest font-mono opacity-70">
            Exposición 12h
          </span>
        </div>
      </div>

      <div className="relative flex items-end gap-1 h-[80px] my-3">
        {hourly.map((v, i) => {
          const h = (v / max) * 100;
          const over = v > goalAqi;
          return (
            <div
              key={i}
              className="exp-bar flex-1 rounded-sm"
              style={{
                height: `${h}%`,
                background: over
                  ? "linear-gradient(180deg, #ff8f00, #ff3d3d)"
                  : "linear-gradient(180deg, #59b7d1, #0099ff)",
                opacity: 0.85,
              }}
            />
          );
        })}
      </div>

      <div className="relative flex items-baseline justify-between">
        <div>
          <div className="text-[9px] uppercase tracking-widest opacity-60">
            Promedio
          </div>
          <div className="aw-display aw-number text-2xl leading-none">
            {Math.round(avg)}
          </div>
        </div>
        <div className="text-right">
          <div className="text-[9px] uppercase tracking-widest opacity-60">
            Sobre meta
          </div>
          <div
            className="aw-number text-sm font-semibold"
            style={{ color: overGoal > 3 ? "#ff8f00" : "#59b7d1" }}
          >
            {overGoal} h
          </div>
        </div>
      </div>
    </div>
  );
}
