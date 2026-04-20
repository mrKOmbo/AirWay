import { AQI_LEVELS } from "@/lib/aqi";

export function MapLegend() {
  return (
    <div className="flex flex-col gap-2.5 min-w-[180px]">
      <div className="aw-eyebrow">Escala AQI</div>
      <div className="flex flex-col gap-1.5">
        {AQI_LEVELS.map((lvl) => (
          <div key={lvl.level} className="flex items-center gap-2.5">
            <span
              className="h-3 w-3 rounded-sm shrink-0"
              style={{ background: lvl.color }}
            />
            <span className="text-[11px] text-aw-ink-soft flex-1">
              {lvl.label}
            </span>
            <span className="aw-number text-[10px] text-aw-ink-muted">
              {lvl.range[0]}–{lvl.range[1] >= 500 ? "500+" : lvl.range[1]}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
