"use client";

import {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import { gsap } from "gsap";
import { aqiMeta } from "@/lib/aqi";
import { cn } from "@/lib/utils";
import type { BestTime } from "@/lib/api/schemas";
import { Sun, Sparkles, Wind } from "lucide-react";
import { usePressHold } from "@/hooks/use-press-hold";

interface Props {
  data?: BestTime;
  loading?: boolean;
}

export function BestTimeStrip({ data, loading }: Props) {
  const [activeIdx, setActiveIdx] = useState<number | null>(null);
  const [pinnedIdx, setPinnedIdx] = useState<number | null>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const barsRef = useRef<HTMLDivElement>(null);

  const hourly = useMemo(() => data?.hourly ?? [], [data]);

  const bestWindowFlags = useMemo(() => {
    if (!data?.best_window || !hourly.length) return null;
    const s = new Date(data.best_window.start).getTime();
    const e = new Date(data.best_window.end).getTime();
    return hourly.map((h) => {
      const t = new Date(h.time).getTime();
      return t >= s && t <= e;
    });
  }, [data, hourly]);

  const highlightIdx = pinnedIdx ?? activeIdx;
  const hovered = highlightIdx !== null ? hourly[highlightIdx] : null;

  useLayoutEffect(() => {
    if (!barsRef.current || !hourly.length) return;
    const ctx = gsap.context(() => {
      gsap.from(".best-time-col", {
        y: 18,
        opacity: 0,
        duration: 0.8,
        ease: "power3.out",
        stagger: 0.02,
      });
      gsap.from(".best-time-bar", {
        scaleY: 0,
        transformOrigin: "bottom",
        duration: 0.9,
        delay: 0.05,
        ease: "power3.out",
        stagger: 0.02,
      });
    }, barsRef);
    return () => ctx.revert();
  }, [hourly.length]);

  if (loading) {
    return (
      <div className="rounded-[32px] aw-glass-strong aw-glass-edge p-6 md:p-7">
        <div className="h-40 aw-shimmer bg-aw-border rounded-2xl" />
      </div>
    );
  }

  if (!hourly.length) {
    return (
      <div className="rounded-[32px] aw-glass p-6 text-center">
        <div className="aw-eyebrow">Timeline</div>
        <p className="mt-2 text-sm text-aw-ink-muted">
          Sin datos horarios — verifica el backend.
        </p>
      </div>
    );
  }

  const max = Math.max(...hourly.map((h) => h.aqi), 100);
  const min = Math.min(...hourly.map((h) => h.aqi), 0);

  return (
    <div
      ref={rootRef}
      className="relative rounded-[32px] overflow-hidden isolate"
      style={{
        background:
          "linear-gradient(135deg, rgba(255,255,255,0.92) 0%, rgba(248,252,255,0.85) 100%)",
        border: "1px solid rgba(10,29,77,0.08)",
        backdropFilter: "blur(32px) saturate(180%)",
        WebkitBackdropFilter: "blur(32px) saturate(180%)",
        boxShadow:
          "0 1px 0 rgba(255,255,255,0.9) inset, 0 24px 60px -30px rgba(10,29,77,0.22)",
      }}
    >
      {/* Aurora blob */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-32 right-0 h-80 w-80 rounded-full opacity-40"
        style={{
          background:
            "radial-gradient(50% 50% at 50% 50%, rgba(0,153,255,0.4), transparent 70%)",
          filter: "blur(40px)",
        }}
      />

      <div className="relative p-6 md:p-7 flex flex-col gap-5">
        {/* Header */}
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <div className="flex items-center gap-2">
              <div
                className="h-7 w-7 rounded-full grid place-items-center"
                style={{
                  background:
                    "linear-gradient(135deg, rgba(89,183,209,0.24), rgba(0,153,255,0.24))",
                }}
              >
                <Sparkles className="h-3.5 w-3.5 text-aw-accent" strokeWidth={2.4} />
              </div>
              <span className="aw-eyebrow">
                Timeline · próximas {hourly.length}h
              </span>
            </div>
            <div className="flex items-baseline gap-2 mt-2">
              <span className="aw-display text-2xl md:text-[26px] text-aw-primary">
                {data?.best_window
                  ? `${formatHour(data.best_window.start)} – ${formatHour(data.best_window.end)}`
                  : "Ventana analizándose"}
              </span>
              {data?.best_window && (
                <span className="aw-number text-sm text-aw-ink-soft">
                  AQI prom {Math.round(data.best_window.avg_aqi)}
                </span>
              )}
            </div>
            {data?.summary && (
              <p className="text-xs text-aw-ink-muted mt-1.5 max-w-xl leading-relaxed">
                {data.summary}
              </p>
            )}
          </div>

          <div className="flex flex-col items-end gap-1.5">
            <div className="flex items-center gap-1.5 text-[11px] text-aw-ink-soft">
              <Sun className="h-3.5 w-3.5 text-aw-warning" />
              <span>Ventana óptima</span>
            </div>
            <span className="text-[10px] text-aw-ink-muted font-mono uppercase tracking-[0.14em]">
              Mantén presionado · fija hora
            </span>
          </div>
        </div>

        {/* Bars */}
        <div
          ref={barsRef}
          className="relative pt-6 pb-1"
          onPointerLeave={() => setActiveIdx(null)}
        >
          <div
            className="grid gap-1 items-end"
            style={{
              gridTemplateColumns: `repeat(${hourly.length}, minmax(0, 1fr))`,
              height: 150,
            }}
          >
            {hourly.map((h, i) => {
              const meta = aqiMeta(h.aqi);
              const heightPct = Math.max(10, ((h.aqi - min * 0.2) / (max - min * 0.2)) * 100);
              const isBest = bestWindowFlags?.[i] ?? false;
              const isActive = i === highlightIdx;
              const isPinned = i === pinnedIdx;
              return (
                <HourColumn
                  key={h.time}
                  meta={meta}
                  heightPct={heightPct}
                  isBest={isBest}
                  isActive={isActive}
                  isPinned={isPinned}
                  dimmed={highlightIdx !== null && !isActive}
                  onEnter={() => setActiveIdx(i)}
                  onLeave={() => setActiveIdx((cur) => (cur === i ? null : cur))}
                  onPin={() => setPinnedIdx(i)}
                  onUnpin={() => setPinnedIdx((cur) => (cur === i ? null : cur))}
                />
              );
            })}
          </div>

          {/* Hour labels */}
          <div
            className="grid gap-1 mt-3"
            style={{
              gridTemplateColumns: `repeat(${hourly.length}, minmax(0, 1fr))`,
            }}
          >
            {hourly.map((h, i) => {
              const isHighlight = i === highlightIdx;
              return (
                <div
                  key={h.time}
                  className={cn(
                    "text-center font-mono tabular-nums transition-colors",
                    isHighlight
                      ? "text-aw-primary font-semibold"
                      : i % 2 === 0
                        ? "text-aw-ink-soft"
                        : "text-aw-ink-muted/50",
                  )}
                  style={{ fontSize: isHighlight ? 11 : 9 }}
                >
                  {formatHour(h.time, true)}
                </div>
              );
            })}
          </div>
        </div>

        {/* Peek detail */}
        <HourPeek
          hour={hovered}
          pinned={pinnedIdx !== null}
        />
      </div>
    </div>
  );
}

function HourColumn({
  meta,
  heightPct,
  isBest,
  isActive,
  isPinned,
  dimmed,
  onEnter,
  onLeave,
  onPin,
  onUnpin,
}: {
  meta: ReturnType<typeof aqiMeta>;
  heightPct: number;
  isBest: boolean;
  isActive: boolean;
  isPinned: boolean;
  dimmed: boolean;
  onEnter: () => void;
  onLeave: () => void;
  onPin: () => void;
  onUnpin: () => void;
}) {
  const { bind, pressing, progress } = usePressHold({
    holdMs: 340,
    onHold: onPin,
    onRelease: () => {
      // Unpin on release only if user releases
      onUnpin();
    },
  });

  return (
    <div
      className="best-time-col relative h-full flex items-end"
      onPointerEnter={onEnter}
      onPointerLeave={onLeave}
    >
      {isBest && (
        <span
          aria-hidden
          className="absolute -top-1 left-1/2 -translate-x-1/2 h-2 w-2 rounded-full"
          style={{
            background: "#00e676",
            boxShadow: "0 0 0 4px rgba(0,230,118,0.22)",
            animation: "aw-pulse 1.8s ease-out infinite",
          }}
        />
      )}
      <div
        {...bind}
        className="best-time-bar relative w-full rounded-[10px] cursor-pointer touch-none select-none will-change-transform"
        style={
          {
            height: `${heightPct}%`,
            background: meta.gradient,
            boxShadow: isActive || isPinned
              ? `0 0 0 2px rgba(255,255,255,0.8), 0 0 0 4px ${meta.color}88, 0 12px 24px ${meta.color}66`
              : isBest
                ? `0 0 0 1.5px rgba(0,230,118,0.6), 0 6px 16px ${meta.color}55`
                : `0 4px 12px ${meta.color}22`,
            opacity: dimmed ? 0.4 : 1,
            transform:
              isActive || isPinned ? "translateY(-4px) scaleY(1.05)" : "none",
            transformOrigin: "bottom",
            transition:
              "transform 220ms cubic-bezier(0.22,1,0.36,1), box-shadow 260ms ease, opacity 180ms ease",
          } as CSSProperties
        }
      >
        {/* Progress ring while pressing */}
        {pressing && progress > 0 && !isPinned && (
          <div
            aria-hidden
            className="absolute inset-0 rounded-[10px] pointer-events-none"
            style={{
              background: `linear-gradient(to top, rgba(255,255,255,0.55) ${progress * 100}%, transparent ${progress * 100}%)`,
              mixBlendMode: "overlay",
            }}
          />
        )}
        {isPinned && (
          <span
            aria-hidden
            className="absolute inset-0 rounded-[10px] ring-2 ring-white/80 pointer-events-none"
          />
        )}
      </div>
    </div>
  );
}

function HourPeek({
  hour,
  pinned,
}: {
  hour: { time: string; aqi: number; category?: string } | null;
  pinned: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const meta = hour ? aqiMeta(hour.aqi) : null;

  useEffect(() => {
    if (!ref.current) return;
    gsap.to(ref.current, {
      opacity: hour ? 1 : 0,
      y: hour ? 0 : 8,
      duration: 0.36,
      ease: "power3.out",
    });
  }, [hour]);

  return (
    <div
      ref={ref}
      className="min-h-[66px] flex items-center"
      style={{ opacity: 0 }}
      aria-live="polite"
    >
      {hour && meta ? (
        <div className="flex items-center gap-4 w-full rounded-2xl bg-white/70 border border-aw-border backdrop-blur px-4 py-3">
          <div
            className="h-10 w-10 shrink-0 rounded-xl grid place-items-center"
            style={{
              background: meta.gradient,
              boxShadow: `0 6px 16px ${meta.color}55`,
            }}
          >
            <Wind className="h-4 w-4 text-white" strokeWidth={2.4} />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-baseline gap-2">
              <span className="aw-display aw-number text-2xl text-aw-primary">
                {Math.round(hour.aqi)}
              </span>
              <span
                className="text-[11px] font-semibold uppercase tracking-[0.14em]"
                style={{ color: meta.color }}
              >
                {meta.shortLabel}
              </span>
              <span className="text-xs text-aw-ink-muted">
                · {formatHour(hour.time)}
              </span>
              {pinned && (
                <span className="ml-auto text-[10px] font-semibold uppercase tracking-[0.14em] text-aw-accent">
                  Fijo · suelta para cerrar
                </span>
              )}
            </div>
            <p className="text-xs text-aw-ink-soft mt-0.5 leading-relaxed">
              {meta.recommendation}
            </p>
          </div>
        </div>
      ) : (
        <div className="w-full rounded-2xl border border-dashed border-aw-border bg-white/40 px-4 py-3">
          <p className="text-xs text-aw-ink-muted">
            Pasa el cursor o mantén presionada una hora para ver el detalle.
          </p>
        </div>
      )}
    </div>
  );
}

function formatHour(iso: string, short = false) {
  const d = new Date(iso);
  const h = d.getHours();
  if (short) return String(h).padStart(2, "0");
  return `${String(h).padStart(2, "0")}:00`;
}
