#!/usr/bin/env python3
"""
AirWay — Exporta modelos entrenados a CoreML (.mlmodel) para iOS.

Convierte los .pkl de scikit-learn a .mlmodel usando coremltools.
Los .mlmodel se arrastran al proyecto Xcode para predicción on-device.

Requiere: pip install coremltools
"""

import os
import sys
import json
import joblib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "backend-api", "models")
OUTPUT_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "frontend", "MLModels")

HORIZONS = [1, 3, 6]


def main():
    print("=" * 60)
    print("  AIRWAY — EXPORTACIÓN A COREML")
    print("=" * 60)

    # Verificar coremltools
    try:
        import coremltools as ct
        print(f"  coremltools version: {ct.__version__}")
    except ImportError:
        print("  ❌ coremltools no instalado")
        print("  Instalar: pip install coremltools")
        sys.exit(1)

    # Cargar feature names
    features_path = os.path.join(MODEL_DIR, "feature_names.json")
    with open(features_path) as f:
        features = json.load(f)
    print(f"  Features: {len(features)}")

    # Cargar métricas
    metrics_path = os.path.join(MODEL_DIR, "metrics.json")
    with open(metrics_path) as f:
        metrics = json.load(f)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for horizon in HORIZONS:
        print(f"\n{'─' * 40}")
        print(f"  Horizonte: {horizon}h")

        # Cargar modelo sklearn
        pkl_path = os.path.join(MODEL_DIR, f"pm25_predictor_{horizon}h.pkl")
        if not os.path.exists(pkl_path):
            print(f"  ⚠️  No encontrado: {pkl_path}")
            continue

        model = joblib.load(pkl_path)
        print(f"  ✓ Modelo .pkl cargado")

        # Obtener métricas
        horizon_metrics = next(
            (h for h in metrics.get("horizons", []) if h["horizon"] == f"{horizon}h"),
            {}
        )
        rmse = horizon_metrics.get("test_rmse", 10)

        # Convertir a CoreML
        coreml_model = ct.converters.sklearn.convert(
            model,
            input_features=features,
            output_feature_names=f"pm25_target_{horizon}h",
        )

        # Metadata
        coreml_model.author = "AirWay Team"
        coreml_model.license = "MIT"
        coreml_model.short_description = (
            f"PM2.5 prediction {horizon}h ahead for Mexico City. "
            f"RMSE={rmse} ug/m3. Trained on Open-Meteo 2023-2025."
        )
        coreml_model.version = "1.0"

        # Guardar
        output_path = os.path.join(OUTPUT_DIR, f"PM25Predictor{horizon}h.mlmodel")
        coreml_model.save(output_path)
        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"  ✓ CoreML guardado: {output_path} ({size_mb:.1f} MB)")

    print(f"\n{'=' * 60}")
    print(f"  ARCHIVOS COREML")
    print(f"{'=' * 60}")
    for f in os.listdir(OUTPUT_DIR):
        if f.endswith(".mlmodel"):
            path = os.path.join(OUTPUT_DIR, f)
            size = os.path.getsize(path) / (1024 * 1024)
            print(f"  📱 {f} ({size:.1f} MB)")

    print(f"\n  Siguiente paso:")
    print(f"  1. Arrastra los .mlmodel al proyecto Xcode (target AcessNet)")
    print(f"  2. Xcode auto-genera las clases PM25Predictor1h, etc.")
    print(f"  3. Clean Build (Cmd+Shift+K, luego Cmd+B)")
    print(f"  4. Usa PM25PredictionService.swift para inferencia")


if __name__ == "__main__":
    main()
