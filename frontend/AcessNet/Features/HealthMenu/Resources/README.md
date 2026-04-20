# HealthMenu · BioDigital HumanKit

Menú tipo "Cure" (Metal Gear Solid 3) que muestra un modelo anatómico 3D del
cuerpo del usuario con los órganos afectados por contaminación/hábitos
resaltados, más una lista de tratamientos accionables.

Se navega desde `BodyScanHubView` (modo `.saved`, solo cuando hay un escaneo
USDZ guardado).

---

## 1. Agregar el paquete HumanKit (Swift Package Manager)

1. En Xcode: `File → Add Package Dependencies…`
2. URL: `https://github.com/biodigital-inc/HumanKit.git`
3. Versión: `Up to Next Major Version` desde **164.3** (o superior disponible).
4. Target: `AcessNet`.

## 2. Activar el SDK en código

El wrapper `BioDigitalHumanView.swift` compila en modo placeholder por
defecto. Para activar el SDK real:

1. En Xcode: `AcessNet target → Build Settings → Swift Compiler - Custom Flags
   → Active Compilation Conditions`.
2. Añade `HAS_HUMANKIT` a Debug y Release.

Mientras la flag no esté activa, el menú muestra un stub SceneKit con un
mensaje de "SDK no enlazado". La app compila sin el paquete.

## 3. Obtener y configurar la API key

1. Crear cuenta en https://developer.biodigital.com
2. Registrar una app con el Bundle ID **xyz.KOmbo.AirWay**.
3. Copiar la API key y el API secret generados.
4. En `frontend/`:
   ```bash
   cp Secrets.example.xcconfig Secrets.xcconfig
   ```
5. Editar `Secrets.xcconfig` y pegar las credenciales reales.
6. En Xcode: `Project → Info → Configurations → Debug/Release → AcessNet`
   asignar el archivo `Secrets` como configuration file.
7. En el `Info.plist` del target añadir:
   ```xml
   <key>BIODIGITAL_API_KEY</key>
   <string>$(BIODIGITAL_API_KEY)</string>
   <key>BIODIGITAL_API_SECRET</key>
   <string>$(BIODIGITAL_API_SECRET)</string>
   ```

> ⚠️ `Secrets.xcconfig` está en `.gitignore`. Nunca lo commitees.

## 4. App Transport Security

El SDK BioDigital usa un loopback local para comunicarse con su webview
interna. Puede ser necesario agregar al `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## 5. Validar object IDs reales del modelo

Los IDs usados en `BioDigitalOrganMapper.swift` son **placeholders**. El
modelo por defecto cargado (`production/maleAdult/flu.json`) expone sus IDs
reales a través del callback `objectPicked` del delegate.

Para descubrirlos en debug:

1. Corre la app con `HAS_HUMANKIT` activada.
2. Toca cada órgano en el modelo 3D.
3. Observa la consola: `🩺 BioDigital objectPicked (no mapeado): <id>`.
4. Actualiza `BioDigitalOrganMapper.objectIds(for:)` con los IDs reales por
   órgano.

## 6. Qué está pendiente (iteraciones futuras)

Marcados con `// TODO` en el código:

- Motor real de cálculo de daño por contaminación.
- Integración con APIs de calidad del aire (IQAir / SEDEMA / OpenWeather).
- HealthKit para consumo real de datos del usuario (pasos, frecuencia
  cardíaca, etc.).
- Notificaciones push contextuales cuando el AQI cambia.
- Selección dinámica de modelo BioDigital según perfil del usuario.
