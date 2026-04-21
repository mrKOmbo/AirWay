//
//  MapSheetTokens.swift
//  AcessNet
//
//  Sistema de tokens unificado para los bottom sheets del mapa.
//  Extiende DesignTokens (ColorExtensions.swift) con specs propias de sheets:
//  detents, handle bar, backdrop, estilos semánticos y jerarquía tipográfica.
//

import SwiftUI

// MARK: - Map Sheet Detent

/// Los tres niveles de altura estándar para los sheets del mapa.
/// Diseñados para que el usuario pueda ver el mapa detrás en peek/medium.
enum MapSheetDetent: Equatable {
    /// 120pt fijos — solo header + acción primaria. El mapa domina (85% visible).
    case peek
    /// 45% de la altura — contenido principal. Mapa aún visible (55%).
    case medium
    /// 90% de la altura — detalles completos. Mapa apenas asoma (10%).
    case large

    /// Altura resuelta en puntos para una altura total de pantalla dada.
    func height(in screenHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek:   return 120
        case .medium: return screenHeight * 0.45
        case .large:  return screenHeight * 0.90
        }
    }

    /// Orden para comparar "cuán alto" está el sheet.
    var rank: Int {
        switch self {
        case .peek:   return 0
        case .medium: return 1
        case .large:  return 2
        }
    }

    /// Detent siguiente al hacer swipe up.
    var nextUp: MapSheetDetent {
        switch self {
        case .peek:   return .medium
        case .medium: return .large
        case .large:  return .large
        }
    }

    /// Detent siguiente al hacer swipe down.
    var nextDown: MapSheetDetent {
        switch self {
        case .peek:   return .peek
        case .medium: return .peek
        case .large:  return .medium
        }
    }
}

// MARK: - Map Sheet Style

/// Estilos semánticos que determinan el tratamiento visual del sheet.
/// Cada pop del mapa entra en una de estas 3 categorías.
enum MapSheetStyle: Equatable {
    /// Informativo — datos para leer (LocationInfoCard, RouteInfoCard).
    /// Stroke blanco sutil, shadow neutral.
    case info

    /// Hero — decisión importante, color dominante (HeroAirQualityCard, RoutePreferenceSelector).
    /// Stroke teñido del color del contenido, shadow de color.
    case hero(tint: Color)

    /// Compact — info pasiva, sin modalidad (NavigationPanel inline).
    /// Sin stroke, padding reducido.
    case compact
}

// MARK: - Map Sheet Tokens

/// Valores canónicos para construir cualquier bottom sheet del mapa.
/// No hardcodear estos números en componentes — leerlos de aquí.
enum MapSheetTokens {

    // MARK: - Container

    /// Radio de las esquinas superiores del sheet (las inferiores son 0).
    static let containerRadius: CGFloat = 24

    /// Color base del sheet, sobre el que se aplica el material.
    static let containerBaseColor: Color = .black.opacity(0.75)

    /// Material de SwiftUI para el efecto glass.
    static let containerMaterial: Material = .ultraThinMaterial

    /// Grosor del stroke del sheet.
    static let strokeWidth: CGFloat = 1

    // MARK: - Handle Bar

    /// Ancho del handle bar (indicador superior de drag).
    static let handleWidth: CGFloat = 36

    /// Alto del handle bar.
    static let handleHeight: CGFloat = 5

    /// Color del handle bar en reposo.
    static let handleColor: Color = .white.opacity(0.35)

    /// Color del handle bar cuando el usuario lo está arrastrando.
    static let handleColorActive: Color = .white.opacity(0.65)

    /// Padding superior del handle dentro del sheet.
    static let handleTopInset: CGFloat = 8

    /// Padding inferior del handle (separación con el contenido).
    static let handleBottomInset: CGFloat = 8

    /// Alto total de la zona del handle (top + handle + bottom).
    static var handleAreaHeight: CGFloat {
        handleTopInset + handleHeight + handleBottomInset
    }

    // MARK: - Content Padding

    /// Padding horizontal del contenido del sheet.
    static let contentHorizontal: CGFloat = 16

    /// Padding vertical (top) del contenido — debajo del handle.
    static let contentTop: CGFloat = 4

    /// Padding vertical (bottom) — separación del borde inferior del sheet.
    static let contentBottom: CGFloat = 20

    /// Spacing entre secciones internas del sheet.
    static let sectionSpacing: CGFloat = 16

    /// Spacing entre elementos dentro de una sección.
    static let elementSpacing: CGFloat = 8

    // MARK: - Backdrop

    /// Opacidad del dim de fondo cuando el sheet está en medium.
    /// Opción B (mapa interactivo): dim sutil para indicar prioridad sin bloquear.
    static let backdropOpacityMedium: Double = 0.18

    /// Opacidad del dim cuando el sheet está en large (bloqueo funcional).
    static let backdropOpacityLarge: Double = 0.45

    /// Opacidad cuando está en peek (sin dim).
    static let backdropOpacityPeek: Double = 0.0

    /// Devuelve la opacidad de dim correspondiente al detent actual.
    static func backdropOpacity(for detent: MapSheetDetent) -> Double {
        switch detent {
        case .peek:   return backdropOpacityPeek
        case .medium: return backdropOpacityMedium
        case .large:  return backdropOpacityLarge
        }
    }

    // MARK: - Shadow

    /// Radio de sombra estándar del sheet.
    static let shadowRadius: CGFloat = 20

    /// Desplazamiento vertical de la sombra.
    static let shadowOffsetY: CGFloat = -4

    /// Color de sombra por defecto (sheets .info y .compact).
    static let shadowColorNeutral: Color = .black.opacity(0.4)

    /// Factor de opacidad aplicado al tint en sheets .hero.
    static let shadowTintOpacity: Double = 0.35

    // MARK: - Close Button

    /// Tamaño mínimo del botón de cerrar — cumple Apple HIG (44x44 touch target).
    static let closeButtonSize: CGFloat = 44

    /// Tamaño del icono xmark dentro del botón.
    static let closeIconSize: CGFloat = 14

    // MARK: - Drag Gesture

    /// Distancia mínima de swipe para disparar cambio de detent.
    static let dragThreshold: CGFloat = 60

    /// Velocidad por encima de la cual el swipe es "rápido" (en pts/s).
    static let dragVelocityThreshold: CGFloat = 500

    // MARK: - Animation

    /// Spring para transiciones entre detents — responsivo pero calmado.
    static let detentSpring: Animation = .spring(response: 0.38, dampingFraction: 0.82)

    /// Spring para aparición/desaparición del sheet entero.
    static let presentSpring: Animation = .spring(response: 0.45, dampingFraction: 0.78)

    /// Animación del dim de fondo (más lenta que el sheet para efecto cinematográfico).
    static let backdropAnimation: Animation = .easeInOut(duration: 0.35)
}

// MARK: - Semantic Colors (Map Sheets)

/// Paleta semántica consolidada para los sheets. Reemplaza los
/// hex hardcodeados regados en LocationInfoCard, RouteInfoCard, etc.
enum MapSheetColor {

    /// Helper interno: construye un Color desde un RGB entero (0xRRGGBB).
    /// Evita el init `Color(hex:)` porque el LSP tiene ambigüedad al resolverlo
    /// en contexto estático de enum con tipo explícito.
    private static func rgb(_ value: UInt32) -> Color {
        Color(
            .sRGB,
            red:     Double((value >> 16) & 0xFF) / 255,
            green:   Double((value >> 8)  & 0xFF) / 255,
            blue:    Double(value         & 0xFF) / 255,
            opacity: 1
        )
    }

    // MARK: - Action / Brand

    /// Azul de acción primaria (Calcular ruta, CTAs).
    static let actionPrimary: Color = rgb(0x3B82F6)
    /// Azul profundo para gradientes.
    static let actionPrimaryDeep: Color = rgb(0x1E40AF)

    /// Cyan de acento para info secundaria.
    static let accent: Color = rgb(0x22D3EE)

    /// Púrpura para contexto ML / predicciones.
    static let ml: Color = rgb(0xA78BFA)
    /// Púrpura profundo.
    static let mlDeep: Color = rgb(0x7C3AED)

    // MARK: - AQI Semantic

    /// AQI bueno (≤50).
    static let aqiGood: Color = rgb(0x34D399)
    /// AQI moderado (51-100).
    static let aqiModerate: Color = rgb(0xFBBF24)
    /// AQI malo (101-150).
    static let aqiPoor: Color = rgb(0xFB923C)
    /// AQI no saludable (151-200).
    static let aqiUnhealthy: Color = rgb(0xF87171)
    /// AQI severo (201-300).
    static let aqiSevere: Color = rgb(0xA78BFA)
    /// AQI peligroso (>300).
    static let aqiHazardous: Color = rgb(0x881337)

    // MARK: - UI Text

    /// Texto primario sobre fondo oscuro del sheet.
    static let textPrimary: Color = .white
    /// Texto secundario (subtítulos, labels).
    static let textSecondary: Color = .white.opacity(0.65)
    /// Texto terciario (metadatos, trackings).
    static let textTertiary: Color = .white.opacity(0.5)

    // MARK: - UI Chrome

    /// Stroke sutil para bordes .info.
    static let strokeSubtle: Color = .white.opacity(0.12)
    /// Stroke medio para elementos elevados.
    static let strokeMedium: Color = .white.opacity(0.2)
    /// Fill muy sutil para secciones internas.
    static let fillSubtle: Color = .white.opacity(0.05)
    /// Fill sutil para chips / badges.
    static let fillMedium: Color = .white.opacity(0.1)

    /// Separador entre secciones.
    static let separator: Color = .white.opacity(0.08)
}

// MARK: - Typography Scale

/// Escala tipográfica canónica para los sheets.
/// Basada en la jerarquía de Apple HIG adaptada al peso "heavy" que ya usa la app.
enum MapSheetTypography {

    // MARK: - Font Sizes

    /// Título principal del sheet (40pt = valor AQI hero).
    static let displaySize: CGFloat = 40
    /// Título de sección (17pt = nombre del lugar).
    static let titleSize: CGFloat = 17
    /// Subtítulo / body (13pt = dirección).
    static let bodySize: CGFloat = 13
    /// Label importante (11pt = "Lista para navegar").
    static let labelSize: CGFloat = 11
    /// Caption pequeño (10pt = distancia).
    static let captionSize: CGFloat = 10
    /// Overline mayúscula (9pt tracking 1.0 = "CALIDAD DEL AIRE · DESTINO").
    static let overlineSize: CGFloat = 9

    // MARK: - Font Presets

    /// Valor grande (display) — para AQI hero, velocidad, etc.
    static let display: Font = .system(size: displaySize, weight: .heavy, design: .rounded)

    /// Título del sheet.
    static let title: Font = .system(size: titleSize, weight: .heavy)

    /// Body estándar.
    static let body: Font = .system(size: bodySize, weight: .semibold)

    /// Label destacado.
    static let label: Font = .system(size: labelSize, weight: .heavy)

    /// Caption de metadato.
    static let caption: Font = .system(size: captionSize, weight: .heavy)

    /// Overline de sección.
    static let overline: Font = .system(size: overlineSize, weight: .heavy)

    // MARK: - Tracking (letter-spacing)

    /// Tracking estándar para overlines (secciones en mayúsculas).
    static let overlineTracking: CGFloat = 1.1
}
