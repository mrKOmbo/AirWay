"use client";

import { useEffect, useRef, useState } from "react";
import { gsap } from "gsap";
import { GlassCard } from "@/components/ui/glass-card";
import { useVehicleSearch } from "@/hooks/use-trip-fuel";
import type { Vehicle } from "@/lib/api/schemas";
import { Car, Fuel, Gauge, Search, X } from "lucide-react";

interface Props {
  onSelect?: (v: Vehicle) => void;
  selected?: Vehicle;
}

function useDebounced<T>(value: T, delay = 250): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

export function VehicleSearch({ onSelect, selected }: Props) {
  const [query, setQuery] = useState("");
  const debounced = useDebounced(query, 300);
  const search = useVehicleSearch(debounced, 6);
  const resultsRef = useRef<HTMLDivElement>(null);

  const items = search.data?.results ?? search.data?.items ?? [];

  useEffect(() => {
    if (!resultsRef.current || !items.length) return;
    const ctx = gsap.context(() => {
      gsap.from(".vehicle-result", {
        y: 10,
        opacity: 0,
        duration: 0.4,
        ease: "power3.out",
        stagger: 0.04,
      });
    }, resultsRef);
    return () => ctx.revert();
  }, [items]);

  return (
    <GlassCard variant="default" radius="xl" className="p-5 md:p-6 flex flex-col gap-4">
      <div>
        <div className="aw-eyebrow">Catálogo CONUEE · 1,200+ vehículos</div>
        <div className="text-xs text-aw-ink-muted mt-0.5">
          Busca tu auto para estimar costo y CO₂ por ruta
        </div>
      </div>

      <label className="relative block">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-aw-ink-muted" />
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Ej: Nissan Versa, Jetta 2020…"
          className="w-full rounded-xl border border-aw-border bg-white/80 pl-9 pr-9 py-2.5 text-sm text-aw-primary placeholder:text-aw-ink-muted focus:outline-none focus:ring-2 focus:ring-aw-accent/40 focus:border-aw-accent transition-colors"
        />
        {query && (
          <button
            onClick={() => setQuery("")}
            className="absolute right-2 top-1/2 -translate-y-1/2 h-6 w-6 grid place-items-center rounded-full hover:bg-aw-border text-aw-ink-muted"
            aria-label="Limpiar búsqueda"
          >
            <X className="h-3.5 w-3.5" />
          </button>
        )}
      </label>

      {selected && (
        <SelectedVehicle vehicle={selected} />
      )}

      <div ref={resultsRef}>
        {query.length < 2 ? (
          <p className="text-xs text-aw-ink-muted">
            Escribe al menos 2 letras para buscar.
          </p>
        ) : search.isLoading ? (
          <div className="space-y-2">
            {Array.from({ length: 3 }).map((_, i) => (
              <div
                key={i}
                className="h-12 aw-shimmer bg-aw-border rounded-lg"
              />
            ))}
          </div>
        ) : search.isError ? (
          <p className="text-xs text-aw-danger">
            Error al buscar. ¿Backend corriendo?
          </p>
        ) : items.length === 0 ? (
          <p className="text-xs text-aw-ink-muted">Sin resultados.</p>
        ) : (
          <div className="max-h-72 overflow-y-auto rounded-lg">
            {items.map((v, i) => (
              <button
                key={`${v.make}-${v.model}-${v.year}-${i}`}
                onClick={() => onSelect?.(v)}
                className="vehicle-result w-full text-left p-3 rounded-lg hover:bg-aw-primary/5 transition-colors flex items-center gap-3 group"
              >
                <div className="h-8 w-8 rounded-lg bg-aw-primary/5 grid place-items-center group-hover:bg-aw-primary/10 transition-colors">
                  <Car className="h-3.5 w-3.5 text-aw-primary" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium text-aw-primary truncate">
                    {v.make} {v.model}
                  </div>
                  <div className="text-[10px] text-aw-ink-muted flex items-center gap-2 mt-0.5">
                    <span>{v.year}</span>
                    {v.fuel_type && (
                      <>
                        <span>·</span>
                        <span className="capitalize">{v.fuel_type}</span>
                      </>
                    )}
                    {v.conuee_km_per_l !== undefined && (
                      <>
                        <span>·</span>
                        <span className="aw-number">
                          {v.conuee_km_per_l.toFixed(1)} km/L
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>
    </GlassCard>
  );
}

function SelectedVehicle({ vehicle }: { vehicle: Vehicle }) {
  return (
    <div className="rounded-xl border border-aw-accent/40 bg-aw-accent/5 p-4">
      <div className="aw-eyebrow text-aw-accent">Vehículo seleccionado</div>
      <div className="flex items-center gap-3 mt-2">
        <div className="h-10 w-10 rounded-lg bg-aw-accent/15 grid place-items-center">
          <Car className="h-5 w-5 text-aw-accent" strokeWidth={2.2} />
        </div>
        <div className="flex-1">
          <div className="text-sm font-semibold text-aw-primary">
            {vehicle.make} {vehicle.model}
          </div>
          <div className="text-[10px] text-aw-ink-muted aw-number">
            {vehicle.year} · {vehicle.fuel_type ?? "—"}
          </div>
        </div>
      </div>
      <div className="grid grid-cols-3 gap-2 mt-3">
        <SpecTile
          icon={Gauge}
          label="Rendimiento"
          value={
            vehicle.conuee_km_per_l !== undefined
              ? vehicle.conuee_km_per_l.toFixed(1)
              : "—"
          }
          unit="km/L"
        />
        <SpecTile
          icon={Fuel}
          label="Cilindros"
          value={vehicle.cylinders?.toString() ?? "—"}
        />
        <SpecTile
          icon={Car}
          label="Cilindrada"
          value={
            vehicle.displacement_cc !== undefined
              ? (vehicle.displacement_cc / 1000).toFixed(1)
              : "—"
          }
          unit="L"
        />
      </div>
    </div>
  );
}

function SpecTile({
  icon: Icon,
  label,
  value,
  unit,
}: {
  icon: typeof Car;
  label: string;
  value: string;
  unit?: string;
}) {
  return (
    <div className="rounded-lg bg-white/70 p-2">
      <Icon className="h-3 w-3 text-aw-ink-muted" />
      <div className="aw-eyebrow text-[9px] mt-1">{label}</div>
      <div className="flex items-baseline gap-0.5">
        <span className="aw-number text-sm font-semibold text-aw-primary">
          {value}
        </span>
        {unit && (
          <span className="text-[9px] text-aw-ink-muted font-medium">
            {unit}
          </span>
        )}
      </div>
    </div>
  );
}
