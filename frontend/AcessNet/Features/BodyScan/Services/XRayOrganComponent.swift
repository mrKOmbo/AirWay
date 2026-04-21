//
//  XRayOrganComponent.swift
//  AcessNet
//
//  Component ECS que marca una entidad como "órgano con shader X-Ray".
//  El XRaySystem itera estas entidades cada frame y sube los uniforms al
//  CustomMaterial de cada ModelEntity.
//

import RealityKit

struct XRayOrganComponent: Component {
    /// Daño objetivo 0..1 (lo que el backend / PPI pide).
    var damageLevel: Float = 0

    /// Daño actual (interpola hacia damageLevel con damping).
    var currentDamage: Float = 0

    /// Pulso (Hz): corazón 1.2, pulmón 0.25, cerebro 0.15.
    var pulseRateHz: Float = 0.25

    /// Amplitud radial del pulso (metros).
    var pulseAmp: Float = 0.012

    /// Multiplicador del emissive (1.5..3.0).
    var glowIntensity: Float = 2.2

    /// Si el órgano debe renderizar (apagar durante fade-out).
    var enabled: Bool = true
}
