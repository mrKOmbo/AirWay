"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { SectionHeader } from "@/components/ui/section-header";
import { AQIWidget } from "@/components/widgets/aqi-widget";
import { ExposureWidget } from "@/components/widgets/exposure-widget";
import { BestTimeWidget } from "@/components/widgets/best-time-widget";
import { PredictionWidget } from "@/components/widgets/prediction-widget";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useAirAnalysis, useBestTime } from "@/hooks/use-air-quality";

export function WidgetsSection() {
  const geo = useGeolocation();
  const analysis = useAirAnalysis(geo.coords);
  const bestTime = useBestTime(geo.coords, "walk", 12);

  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".widget-reveal", {
        y: 30,
        scale: 0.94,
        opacity: 0,
        rotate: -2,
        duration: 0.9,
        ease: "power3.out",
        stagger: 0.08,
        scrollTrigger: {
          trigger: root.current,
          start: "top 70%",
          once: true,
        },
      });
    }, root);
    return () => ctx.revert();
  }, []);

  const aqi = analysis.data?.combined_aqi ?? 42;
  const pred6h = analysis.data?.ml_prediction?.predictions?.["6h"]?.aqi ?? aqi - 5;
  const hourlyAQI = bestTime.data?.hourly?.slice(0, 12).map((h) => h.aqi);

  const windowLabel = bestTime.data?.best_window
    ? {
        start: formatTime(bestTime.data.best_window.start),
        end: formatTime(bestTime.data.best_window.end),
        aqi: Math.round(bestTime.data.best_window.avg_aqi),
      }
    : undefined;

  return (
    <section
      id="widgets"
      ref={root}
      className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-16 md:py-24 scroll-mt-24"
    >
      <div className="flex flex-col gap-10">
        <SectionHeader
          eyebrow="Extensiones · Wearables"
          title="Widgets embebibles · tipo Apple Watch"
          subtitle="Los mismos datos del dashboard, condensados en complicaciones cuadradas listas para watchOS, iOS Home Screen o PWA."
          align="center"
          className="mx-auto text-center"
        />

        <div className="flex items-center justify-center flex-wrap gap-5 md:gap-7">
          <div className="widget-reveal">
            <AQIWidget aqi={aqi} location="Tu ubicación" />
          </div>
          <div className="widget-reveal">
            <PredictionWidget current={Math.round(aqi)} predicted6h={Math.round(pred6h)} />
          </div>
          <div className="widget-reveal">
            <ExposureWidget hourly={hourlyAQI} />
          </div>
          <div className="widget-reveal">
            <BestTimeWidget window={windowLabel} />
          </div>
        </div>

        <p className="text-center text-xs text-aw-ink-muted max-w-xl mx-auto">
          Todos los widgets son componentes React independientes reutilizables en
          cualquier lienzo — listos para screenshots, embed en apps móviles o
          complicaciones de reloj.
        </p>
      </div>
    </section>
  );
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, "0")}:00`;
}
