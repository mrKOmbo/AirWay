"use client";

import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { LivePill } from "@/components/ui/live-pill";
import { ThemeToggle } from "@/components/theme/theme-toggle";
import { Wind, Map, Activity, Gauge, Heart } from "lucide-react";

const LINKS = [
  { href: "#live", label: "Live", icon: Wind },
  { href: "#map", label: "Mapa", icon: Map },
  { href: "#forecast", label: "Predicción", icon: Activity },
  { href: "#health", label: "Salud", icon: Heart },
  { href: "#routes", label: "Rutas", icon: Gauge },
];

export function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const ref = useRef<HTMLElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      ref={ref}
      className={cn(
        "sticky top-0 z-40 w-full transition-all duration-300",
        scrolled ? "py-2" : "py-4",
      )}
    >
      <div className="mx-auto w-full max-w-7xl px-4 md:px-6">
        <div
          className={cn(
            "flex items-center justify-between gap-4 rounded-full border border-aw-border pl-5 pr-2 py-2 transition-all duration-300",
            scrolled
              ? "aw-glass-strong shadow-[var(--shadow-aw-md)]"
              : "bg-white/50 backdrop-blur-sm",
          )}
        >
          <a href="#" className="flex items-center gap-2.5 group">
            <WordmarkGlyph />
            <span className="aw-display text-[17px] tracking-tight text-aw-primary">
              AirWay
            </span>
          </a>

          <nav className="hidden md:flex items-center gap-1">
            {LINKS.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="px-3 py-1.5 rounded-full text-sm font-medium text-aw-ink-soft hover:text-aw-primary hover:bg-white/70 transition-colors"
              >
                {link.label}
              </a>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            <LivePill className="hidden sm:inline-flex">
              <span className="aw-number">Sync</span>
            </LivePill>
            <ThemeToggle />
            <a
              href="#routes"
              className="relative inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold text-white transition-all hover:scale-[1.02] active:scale-[0.98]"
              style={{
                background:
                  "linear-gradient(135deg, #0099ff 0%, #0a1d4d 100%)",
                boxShadow:
                  "0 6px 18px rgba(0,153,255,0.28), inset 0 1px 0 rgba(255,255,255,0.3)",
              }}
            >
              Explorar
            </a>
          </div>
        </div>
      </div>
    </header>
  );
}

function WordmarkGlyph() {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 32 32"
      fill="none"
      className="shrink-0"
      aria-hidden
    >
      <defs>
        <linearGradient id="aw-logo-g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#59b7d1" />
          <stop offset="60%" stopColor="#0099ff" />
          <stop offset="100%" stopColor="#0a1d4d" />
        </linearGradient>
      </defs>
      <circle cx="16" cy="16" r="14" fill="url(#aw-logo-g)" />
      <path
        d="M7 19 C 12 15, 14 15, 16 17 C 18 19, 20 19, 25 14"
        stroke="white"
        strokeWidth="2.2"
        strokeLinecap="round"
        fill="none"
      />
      <circle cx="22" cy="11" r="1.6" fill="white" />
    </svg>
  );
}
