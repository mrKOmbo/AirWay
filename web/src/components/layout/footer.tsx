export function Footer() {
  return (
    <footer className="relative mx-auto w-full max-w-7xl px-4 md:px-6 py-12">
      <div className="flex flex-col md:flex-row items-center justify-between gap-4 rounded-3xl border border-aw-border bg-white/60 backdrop-blur-md p-6">
        <div className="flex items-center gap-3">
          <div
            className="h-8 w-8 rounded-full"
            style={{
              background:
                "linear-gradient(135deg, #59b7d1 0%, #0099ff 60%, #0a1d4d 100%)",
            }}
          />
          <div>
            <div className="aw-display text-sm text-aw-primary">AirWay</div>
            <div className="aw-eyebrow text-[9px]">Breathable Intelligence</div>
          </div>
        </div>
        <p className="text-xs text-aw-ink-muted text-center md:text-right">
          Datos fusionados de OpenAQ, WAQI, Open-Meteo CAMS y NASA TEMPO ·
          Predicciones ML scikit-learn · © {new Date().getFullYear()}
        </p>
      </div>
    </footer>
  );
}
