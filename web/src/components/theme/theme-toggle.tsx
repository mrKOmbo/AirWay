"use client";

import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { cn } from "@/lib/utils";

type Theme = "light" | "dark";

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>("light");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const t =
      (document.documentElement.dataset.theme as Theme | undefined) ?? "light";
    setTheme(t);
    setMounted(true);
  }, []);

  const toggle = () => {
    const next: Theme = theme === "light" ? "dark" : "light";
    setTheme(next);
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem("aw-theme", next);
    } catch {
      /* ignore */
    }
  };

  return (
    <button
      onClick={toggle}
      aria-label={
        theme === "light" ? "Activar modo oscuro" : "Activar modo claro"
      }
      className={cn(
        "relative h-8 w-8 rounded-full border border-aw-border flex items-center justify-center",
        "bg-white/70 backdrop-blur hover:bg-white transition-colors text-aw-primary",
      )}
    >
      {mounted && (theme === "light" ? (
        <Moon className="h-3.5 w-3.5" strokeWidth={2.2} />
      ) : (
        <Sun className="h-3.5 w-3.5" strokeWidth={2.2} />
      ))}
    </button>
  );
}
