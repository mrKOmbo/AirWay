# AirWay / AcessNet — NASA Space Apps Challenge 2025

Monorepo con app iOS + watchOS + widget + backend Django + pipeline ML para predicción de calidad del aire usando datos NASA TEMPO + fuentes terrestres.

## Estructura del repo

```
SpaceApps/
├── frontend/                      # Proyecto Xcode (Swift / SwiftUI)
│   ├── AcessNet.xcodeproj         # bundle id: AcessNet · @main: AirWayApp
│   ├── AcessNet/                  # App iOS principal
│   │   ├── Core/                  # App, Managers, Services, Models, Helpers
│   │   ├── Features/              # AR, AirQuality, Business, Contingency,
│   │   │                          # Health (PPI), Map, Menu, Onboarding, Settings
│   │   ├── Shared/                # Models, Effects, Modifiers, Utils
│   │   └── Resources/             # Fonts, Animations, Models3D (.usdz)
│   ├── AirWayWatch Watch App/     # App watchOS (PPI, Cigarette eq, Exposure)
│   ├── ContingencyWidget/         # WidgetKit
│   └── MLModels/                  # PM25Predictor{1h,3h,6h}.mlmodel (CoreML)
│
├── backend-api/                   # Django 5.1 + DRF · hexagonal
│   ├── src/
│   │   ├── core/                  # settings, urls, celery, wsgi/asgi
│   │   ├── adapters/              # I/O externos
│   │   │   ├── ai/                # gemini_vision, llm_service
│   │   │   ├── air/               # openaq, waqi, openmeteo, elevation
│   │   │   ├── fuel/              # catálogos/clientes combustible
│   │   │   └── router/            # OSRM / routing
│   │   ├── application/           # lógica de negocio
│   │   │   ├── air/               # aggregator, prediction_service
│   │   │   ├── fuel/              # physics_model, departure_optimizer, …
│   │   │   ├── ml/                # features, inference, train_{xgb,quantile}
│   │   │   └── routes/            # exposure, multimodal, use_cases
│   │   └── interfaces/api/        # vistas DRF: contingency, fuel, ppi,
│   │                              # routes, trip  (todo bajo /api/v1/)
│   ├── models/                    # *.pkl entrenados (PM2.5 1h/3h/6h)
│   ├── Dockerfile · docker-compose.yml · requirements.txt
│
├── scripts/                       # Pipeline ML CDMX (PM2.5)
│   ├── download_training_data.py  # RAMA + OpenAQ → CSV
│   ├── train_model.py             # XGBoost baseline
│   └── export_coreml.py           # .pkl → .mlmodel
│
├── render.yaml                    # Blueprint Render (web + postgres)
└── *.md                           # Documentación (ver abajo)
```

## Stack

**iOS / watchOS** · Swift 5.9, SwiftUI, ARKit + RealityKit, MapKit, Combine, CoreLocation, HealthKit (Watch), WatchConnectivity, CoreML, WidgetKit. Mínimos: iOS 16+ / watchOS 9+.

**Backend** · Django 5.1 + DRF, Celery + Redis, Postgres (Render) / SQLite (fallback local), Gunicorn, Docker. ML: XGBoost, LightGBM, scikit-learn, MAPIE (intervalos cuantiles), pandas, pyarrow.

**Fuentes de datos** · NASA TEMPO (NO₂, O₃, HCHO), OpenAQ (PM2.5/PM10), WAQI, OpenMeteo (viento/temp), RAMA CDMX, Gemini (visión + LLM para explicaciones).

## Rutas API (backend-api)

Todas bajo `/api/v1/`, incluidas desde `core/urls.py`:

| Prefijo | App | Responsabilidad |
|---|---|---|
| `routes/` | `interfaces/api/routes` | Ruteo multimodal + exposición AQI |
| `ppi/` | `interfaces/api/ppi` | Personal Pollution Index (Watch) |
| `contingency/` | `interfaces/api/contingency` | ContingencyCast (predicción +horas) |
| `fuel/` | `interfaces/api/fuel` | GasolinaMeter: stations, departure, vehicle-vision |
| `trip/` | `interfaces/api/trip` | Comparación de modos de viaje |
| `healthz` | — | Health check (apunta a routes) |

Health check de Render: `/api/v1/contingency/health`.

## Features iOS (mapa mental)

- **Home** · `Features/AirQuality/Views/AQIHomeView.swift` · Tabs `home / map / fuel / health / settings` en `MainTabView.swift`. Tiene modo edición (reordenar/ocultar secciones).
- **Map** · `Features/Map/` · Ruteo con Dijkstra ponderado por AQI, muchos componentes de visualización (zonas, flechas, partículas, banners).
- **AR** · `Features/AR/Views/ARParticlesView.swift` · 2 000 partículas PM2.5 con mesh caching + warmup progresivo.
- **Health / PPI** · dashboards + perfil de vulnerabilidad + grabador de trayectos.
- **Fuel (GasolinaMeter)** · hub con estaciones, comparación de modos, optimal departure, perfil de vehículo, escaneo con visión (Gemini).
- **Contingency** · `ContingencyCastView` con gauge, drivers, recomendaciones y horizon card.
- **Watch** · PPI score + haptics, cigarette equivalence, exposure, mapa de ruta. Sincroniza con el iPhone vía `WatchConnectivityManager`.

## Variables de entorno

Configuración vía `.env` (ver `.env.example`). Claves relevantes:

- `OPENAQ_API_KEY`, `WAQI_TOKEN`
- `GEMINI_API_KEY`, `GEMINI_MODEL`, `LLM_PROVIDER` (`gemini` | `alt`)
- `DATABASE_URL` (Render) o `DB_*` (docker-compose local)
- `DEBUG`, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `SECRET_KEY`
- `REDIS_URL` (opcional, si no hay se usa LocMem)

⚠️ El `.env` con secretos **no** se commitea (ver commit `7410d07`). Solo `.env.example`.

## Comandos habituales

**Backend local (Docker)**
```bash
cd backend-api && docker compose up --build
# → http://localhost:8000/api/v1/…
```

**Backend local (sin Docker)**
```bash
cd backend-api && source venv/bin/activate
pip install -r requirements.txt
cd src && python manage.py runserver
```

**iOS**
```bash
open frontend/AcessNet.xcodeproj    # ⌘R en Xcode
```

**Entrenar + exportar modelos ML**
```bash
python scripts/download_training_data.py     # genera CSVs de train/test CDMX
python scripts/train_model.py                # entrena .pkl
python scripts/export_coreml.py              # .pkl → .mlmodel
```

## Deploy (Render)

`render.yaml` declara:
- `airway-api` (web, Docker, plan starter, región oregon)
- `airway-postgres` (Postgres starter)
- Secretos marcados `sync: false` (OPENAQ, WAQI, GEMINI) → se configuran en el dashboard.

Autodeploy en `git push`. El Dockerfile compila con GDAL/PROJ/GEOS + `libgomp1` (necesario para XGBoost en Linux).

## Documentación adicional (en la raíz)

Archivos `.md` con contexto de producto y roadmap — útiles para entender decisiones, no para leer de corrido:

- `AIRWAY_DESCRIPCION_GENERAL.md`, `AIRWAY_DOCUMENTACION_EJECUTIVA.md` — visión general
- `PROPUESTA_PREDICCION_CONTINGENCIAS.md`, `GNN_NIVEL3_IMPLEMENTACION_FUTURA.md` — ML futuro
- `IDEAS_IA_AIRWAY_HACKATHON.md`, `IDEA5_PREDICCION_AQI_IMPLEMENTACION.md` — ideas AI
- `IDEAS_GASOLINAMETER_*.md`, `IDEAS_EXPANSION_SIMULACION_EMISIONES_*.md` — GasolinaMeter/expansión
- `IDEAS_IA_POBLACIONES_VULNERABLES.md`, `IDEAS_ENGAGEMENT_USUARIO_PROMEDIO.md` — UX
- `USER_GUIDE.md`, `README.md` — uso
- `ANEXO_ADC_AIRWAY.md`, `AIRWAY_INFO_CONFIDENCIAL_ADC.md` — confidencial

## Convenciones

- **Git user**: `BICHOTEE`. Rama principal: `main`. Commits en español con prefijos tipo `feat(…): …`, `chore: …`.
- **Idioma**: el código y los comentarios mezclan español e inglés; los `.md` de producto son en español.
- **Secretos**: nunca commitear `.env` ni `xcuserstate`. `frontend/AcessNet.xcodeproj.backup/` existe como backup del `.pbxproj`.
