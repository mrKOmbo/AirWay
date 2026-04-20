//
//  SkeletonOverlay.swift
//  AcessNet
//
//  Overlay SwiftUI Canvas que dibuja el stick figure (puntos + huesos)
//  sobre el feed AR en vivo. 34 joints + 33 huesos.
//

import SwiftUI

struct SkeletonOverlay: View {
    let joints: [BodyJoint: CGPoint]

    var body: some View {
        Canvas { context, size in
            // 1. Dibujar huesos
            for bone in BodyJoint.bones {
                guard
                    let from = joints[bone.0],
                    let to = joints[bone.1]
                else { continue }

                let path = Path { p in
                    p.move(to: from)
                    p.addLine(to: to)
                }

                // Línea glow externa
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                // Línea principal
                context.stroke(
                    path,
                    with: .color(colorForBone(bone)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }

            // 2. Dibujar joints
            for (joint, point) in joints {
                let color = colorForRegion(joint.region)
                let radius: CGFloat = joint.region == .core ? 5 : 4

                // Halo exterior
                let halo = Path(ellipseIn: CGRect(
                    x: point.x - radius - 3,
                    y: point.y - radius - 3,
                    width: (radius + 3) * 2,
                    height: (radius + 3) * 2
                ))
                context.fill(halo, with: .color(color.opacity(0.25)))

                // Punto sólido
                let dot = Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(dot, with: .color(color))
                context.stroke(
                    dot,
                    with: .color(.white),
                    lineWidth: 1.2
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Colors

    private func colorForRegion(_ region: BodyRegion) -> Color {
        switch region {
        case .core: return Color(hex: "#7DD3FC")       // cian suave
        case .leftLimb: return Color(hex: "#A78BFA")   // violeta
        case .rightLimb: return Color(hex: "#F472B6")  // rosa
        }
    }

    private func colorForBone(_ bone: (BodyJoint, BodyJoint)) -> Color {
        let r1 = bone.0.region
        let r2 = bone.1.region
        if r1 == r2 { return colorForRegion(r1).opacity(0.9) }
        return Color.white.opacity(0.85)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SkeletonOverlay(joints: [
            .head: CGPoint(x: 200, y: 100),
            .neck1: CGPoint(x: 200, y: 140),
            .spine7: CGPoint(x: 200, y: 160),
            .spine5: CGPoint(x: 200, y: 200),
            .spine3: CGPoint(x: 200, y: 240),
            .spine1: CGPoint(x: 200, y: 280),
            .hips: CGPoint(x: 200, y: 320),
            .leftShoulder1: CGPoint(x: 160, y: 170),
            .leftArm: CGPoint(x: 130, y: 230),
            .leftForearm: CGPoint(x: 110, y: 290),
            .leftHand: CGPoint(x: 100, y: 340),
            .rightShoulder1: CGPoint(x: 240, y: 170),
            .rightArm: CGPoint(x: 270, y: 230),
            .rightForearm: CGPoint(x: 290, y: 290),
            .rightHand: CGPoint(x: 300, y: 340),
            .leftUpLeg: CGPoint(x: 180, y: 330),
            .leftLeg: CGPoint(x: 170, y: 420),
            .leftFoot: CGPoint(x: 160, y: 500),
            .rightUpLeg: CGPoint(x: 220, y: 330),
            .rightLeg: CGPoint(x: 230, y: 420),
            .rightFoot: CGPoint(x: 240, y: 500)
        ])
    }
}
