//
//  XRayHologram.metal
//  AcessNet
//
//  Surface shader + geometry modifier para dar look "rayos X holográfico" a
//  los órganos 3D del modo Anatomy AR.
//
//  Parámetros (pasados como SIMD4<Float> vía material.custom.value):
//    x: damageLevel   [0..1]  0 = sano (cyan), 1 = severo (magenta)
//    y: pulseRate     (Hz)    corazón ~1.2, pulmón ~0.25, cerebro ~0.15
//    z: pulseAmp      (m)     amplitud radial del pulse (0.002..0.020)
//    w: glowIntensity         multiplicador emissive (1.5..3.0)
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// MARK: - Paleta damage (cyan → amber → orange → magenta)

static inline half3 damageColor(float d) {
    d = saturate(d);
    half3 c0 = half3(0.49h, 0.83h, 0.99h);  // #7DD3FC cyan   · sano
    half3 c1 = half3(0.96h, 0.73h, 0.26h);  // #F4B942 amber  · leve
    half3 c2 = half3(1.00h, 0.54h, 0.24h);  // #FF8A3D orange · moderado
    half3 c3 = half3(1.00h, 0.36h, 0.36h);  // #FF5B5B magenta· severo
    if (d < 0.33) return mix(c0, c1, (half)(d / 0.33));
    if (d < 0.66) return mix(c1, c2, (half)((d - 0.33) / 0.33));
    return mix(c2, c3, (half)((d - 0.66) / 0.34));
}

// MARK: - SURFACE SHADER

[[visible]]
void xraySurface(realitykit::surface_parameters params)
{
    auto u = params.uniforms();
    float4 cv = u.custom_parameter();
    float damage    = cv.x;
    float pulseRate = cv.y;
    float glow      = cv.w;
    float t         = u.time();

    // Normal y dirección de vista en espacio mundo (ya interpoladas).
    float3 N = normalize(params.geometry().normal());
    float3 V = normalize(params.geometry().view_direction());
    float NdotV = saturate(dot(N, V));

    // Fresnel — fino en el borde, casi cero de frente.
    float fresnel = pow(1.0 - NdotV, 3.0);

    // Doble sinusoidal para evitar el look "matemático" de una sola onda.
    float pulseA = 0.5 + 0.5 * sin(t * pulseRate * 6.28318530718);
    float pulseB = 0.5 + 0.5 * sin(t * pulseRate * 6.28318530718 * 1.73 + 1.3);
    float pulse  = mix(pulseA, mix(pulseA, pulseB, 0.6), damage);

    // Scanlines: toque "TC médico".
    float3 wp = params.geometry().world_position();
    float scan = 0.85 + 0.15 * sin(wp.y * 220.0 + t * 4.0);

    half3 tint = damageColor(damage);
    half3 core = tint * 0.08h;                          // interior muy tenue
    half3 rim  = tint * (half)(fresnel * (0.75 + 0.55 * pulse) * glow) * (half)scan;
    half3 emi  = core + rim;

    // Opacidad: casi invisible de frente, sólida en borde.
    float alpha = saturate(0.08 + fresnel * (0.85 + 0.15 * pulse));

    auto s = params.surface();
    s.set_base_color(half3(0.0h));
    s.set_emissive_color(emi);
    s.set_opacity((half)alpha);
    s.set_roughness(1.0h);
    s.set_metallic(0.0h);
}

// MARK: - GEOMETRY MODIFIER (pulse radial)

[[visible]]
void xrayGeometry(realitykit::geometry_parameters params)
{
    auto u = params.uniforms();
    float4 cv = u.custom_parameter();
    float damage    = cv.x;
    float pulseRate = cv.y;
    float pulseAmp  = cv.z;
    float t         = u.time();

    // Amplitud crece ~40% con damage severo (inflamación).
    float amp = pulseAmp * (1.0 + damage * 0.4);

    float wave = sin(t * pulseRate * 6.28318530718);
    wave += 0.15 * sin(t * pulseRate * 6.28318530718 * 2.13 + 0.7);

    float3 n = normalize(params.geometry().normal());
    float3 offset = n * (amp * wave);

    params.geometry().set_model_position_offset(offset);
}
