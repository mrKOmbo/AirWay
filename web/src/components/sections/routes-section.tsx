"use client";

import { useEffect, useRef, useState } from "react";
import { gsap } from "gsap";
import { SectionHeader } from "@/components/ui/section-header";
import { GlassCard } from "@/components/ui/glass-card";
import { LivePill } from "@/components/ui/live-pill";
import { TripComparator } from "@/components/routes/trip-comparator";
import { FuelPricesPanel } from "@/components/routes/fuel-prices";
import { VehicleSearch } from "@/components/routes/vehicle-search";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useTripCompare } from "@/hooks/use-trip-fuel";
import { demoDestination } from "@/hooks/use-routes";
import type { Vehicle } from "@/lib/api/schemas";

export function RoutesSection() {
  const geo = useGeolocation();
  const destination = demoDestination(geo.coords);
  const [vehicle, setVehicle] = useState<Vehicle | undefined>(undefined);

  const trip = useTripCompare(
    geo.coords,
    destination,
    vehicle as Record<string, unknown> | undefined,
  );

  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!root.current) return;
    const ctx = gsap.context(() => {
      gsap.from(".routes-reveal", {
        y: 40,
        opacity: 0,
        duration: 0.9,
        ease: "power3.out",
        stagger: 0.1,
        scrollTrigger: {
          trigger: root.current,
          start: "top 75%",
          once: true,
        },
      });
    }, root);
    return () => ctx.revert();
  }, []);

  return (
    <section
      id="routes"
      ref={root}
      className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-16 md:py-24 scroll-mt-24"
    >
      <div className="flex flex-col gap-8">
        <div className="routes-reveal flex flex-col md:flex-row md:items-end md:justify-between gap-4">
          <SectionHeader
            eyebrow="Fase 7 · Multimodal + Fuel"
            title="Cada viaje, medido en todas sus dimensiones"
            subtitle="Compara tiempo, costo, CO₂ y exposición al aire entre auto, metro, Uber y bici. Catálogo CONUEE con 1,200+ vehículos y precios oficiales de gasolina."
          />
          <div className="flex items-center gap-2">
            <LivePill>Trip · AI</LivePill>
          </div>
        </div>

        <div className="routes-reveal">
          <TripComparator data={trip.data} loading={trip.isLoading} />
        </div>

        <div className="routes-reveal grid lg:grid-cols-[1fr_1.1fr] gap-5">
          <GlassCard variant="default" radius="xl" className="p-6 md:p-7">
            <FuelPricesPanel />
          </GlassCard>
          <VehicleSearch onSelect={setVehicle} selected={vehicle} />
        </div>
      </div>
    </section>
  );
}
