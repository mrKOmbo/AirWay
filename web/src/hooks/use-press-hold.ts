"use client";

import { useCallback, useEffect, useRef, useState } from "react";

interface UsePressHoldOptions {
  holdMs?: number;
  onHold?: () => void;
  onRelease?: () => void;
  haptic?: boolean;
  disabled?: boolean;
}

export interface PressHoldBinding {
  onPointerDown: (e: React.PointerEvent) => void;
  onPointerUp: (e: React.PointerEvent) => void;
  onPointerCancel: (e: React.PointerEvent) => void;
  onPointerLeave: (e: React.PointerEvent) => void;
  onContextMenu: (e: React.MouseEvent) => void;
}

export interface UsePressHoldResult {
  bind: PressHoldBinding;
  pressing: boolean;
  holding: boolean;
  progress: number;
}

export function usePressHold({
  holdMs = 420,
  onHold,
  onRelease,
  haptic = true,
  disabled = false,
}: UsePressHoldOptions = {}): UsePressHoldResult {
  const [pressing, setPressing] = useState(false);
  const [holding, setHolding] = useState(false);
  const [progress, setProgress] = useState(0);

  const rafRef = useRef<number | null>(null);
  const startRef = useRef(0);
  const cancelledRef = useRef(false);
  const holdingRef = useRef(false);
  const onHoldRef = useRef(onHold);
  const onReleaseRef = useRef(onRelease);
  const holdMsRef = useRef(holdMs);
  const hapticRef = useRef(haptic);
  const tickRef = useRef<() => void>(() => {});

  useEffect(() => {
    onHoldRef.current = onHold;
    onReleaseRef.current = onRelease;
    holdMsRef.current = holdMs;
    hapticRef.current = haptic;
  }, [onHold, onRelease, holdMs, haptic]);

  useEffect(() => {
    tickRef.current = () => {
      const elapsed = performance.now() - startRef.current;
      const p = Math.min(1, elapsed / holdMsRef.current);
      setProgress(p);
      if (p >= 1) {
        if (!cancelledRef.current && !holdingRef.current) {
          holdingRef.current = true;
          setHolding(true);
          if (
            hapticRef.current &&
            typeof navigator !== "undefined" &&
            "vibrate" in navigator
          ) {
            navigator.vibrate?.(14);
          }
          onHoldRef.current?.();
        }
        return;
      }
      rafRef.current = requestAnimationFrame(() => tickRef.current());
    };
  }, []);

  const stopRaf = () => {
    if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
    rafRef.current = null;
  };

  const reset = useCallback(() => {
    stopRaf();
    setPressing(false);
    setProgress(0);
    if (holdingRef.current) {
      holdingRef.current = false;
      setHolding(false);
      onReleaseRef.current?.();
    }
  }, []);

  const bind: PressHoldBinding = {
    onPointerDown: (e) => {
      if (disabled) return;
      try {
        e.currentTarget.setPointerCapture(e.pointerId);
      } catch {}
      cancelledRef.current = false;
      startRef.current = performance.now();
      setPressing(true);
      setProgress(0);
      stopRaf();
      rafRef.current = requestAnimationFrame(() => tickRef.current());
    },
    onPointerUp: (e) => {
      try {
        e.currentTarget.releasePointerCapture(e.pointerId);
      } catch {}
      cancelledRef.current = true;
      reset();
    },
    onPointerCancel: () => {
      cancelledRef.current = true;
      reset();
    },
    onPointerLeave: () => {
      cancelledRef.current = true;
      reset();
    },
    onContextMenu: (e) => e.preventDefault(),
  };

  useEffect(() => () => stopRaf(), []);

  return { bind, pressing, holding, progress };
}
