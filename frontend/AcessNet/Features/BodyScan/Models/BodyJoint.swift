//
//  BodyJoint.swift
//  AcessNet
//
//  34 joints curados del ARSkeleton3D para visualización stick-figure.
//  El esqueleto completo de ARKit expone ~91 joints (incluye dedos, mandíbula,
//  subdivisiones de columna y cuello). Aquí se seleccionan los 34 más
//  representativos del cuerpo completo.
//

import Foundation
import ARKit

enum BodyJoint: String, CaseIterable, Identifiable {
    // Tronco / columna
    case root
    case hips
    case spine1
    case spine3
    case spine5
    case spine7
    case neck1
    case neck4
    case head
    case jaw

    // Brazo izquierdo
    case leftShoulder1
    case leftArm
    case leftForearm
    case leftHand
    case leftHandThumb
    case leftHandIndex
    case leftHandPinky

    // Brazo derecho
    case rightShoulder1
    case rightArm
    case rightForearm
    case rightHand
    case rightHandThumb
    case rightHandIndex
    case rightHandPinky

    // Pierna izquierda
    case leftUpLeg
    case leftLeg
    case leftFoot
    case leftToes

    // Pierna derecha
    case rightUpLeg
    case rightLeg
    case rightFoot
    case rightToes

    // Ojos (ARKit los expone)
    case leftEye
    case rightEye

    var id: String { rawValue }

    /// Nombre del joint tal cual lo expone `ARSkeleton.JointName` / `ARSkeletonDefinition`.
    var arJointName: String {
        switch self {
        case .root: return "root"
        case .hips: return "hips_joint"
        case .spine1: return "spine_1_joint"
        case .spine3: return "spine_3_joint"
        case .spine5: return "spine_5_joint"
        case .spine7: return "spine_7_joint"
        case .neck1: return "neck_1_joint"
        case .neck4: return "neck_4_joint"
        case .head: return "head_joint"
        case .jaw: return "jaw_joint"

        case .leftShoulder1: return "left_shoulder_1_joint"
        case .leftArm: return "left_arm_joint"
        case .leftForearm: return "left_forearm_joint"
        case .leftHand: return "left_hand_joint"
        case .leftHandThumb: return "left_handThumbStart_joint"
        case .leftHandIndex: return "left_handIndexStart_joint"
        case .leftHandPinky: return "left_handPinkyStart_joint"

        case .rightShoulder1: return "right_shoulder_1_joint"
        case .rightArm: return "right_arm_joint"
        case .rightForearm: return "right_forearm_joint"
        case .rightHand: return "right_hand_joint"
        case .rightHandThumb: return "right_handThumbStart_joint"
        case .rightHandIndex: return "right_handIndexStart_joint"
        case .rightHandPinky: return "right_handPinkyStart_joint"

        case .leftUpLeg: return "left_upLeg_joint"
        case .leftLeg: return "left_leg_joint"
        case .leftFoot: return "left_foot_joint"
        case .leftToes: return "left_toes_joint"

        case .rightUpLeg: return "right_upLeg_joint"
        case .rightLeg: return "right_leg_joint"
        case .rightFoot: return "right_foot_joint"
        case .rightToes: return "right_toes_joint"

        case .leftEye: return "left_eye_joint"
        case .rightEye: return "right_eye_joint"
        }
    }

    /// Conexiones huesos -> (from, to) para dibujar el stick figure.
    static let bones: [(BodyJoint, BodyJoint)] = [
        // Columna
        (.hips, .spine1),
        (.spine1, .spine3),
        (.spine3, .spine5),
        (.spine5, .spine7),
        (.spine7, .neck1),
        (.neck1, .neck4),
        (.neck4, .head),
        (.head, .jaw),

        // Hombros
        (.spine7, .leftShoulder1),
        (.spine7, .rightShoulder1),

        // Brazo izq
        (.leftShoulder1, .leftArm),
        (.leftArm, .leftForearm),
        (.leftForearm, .leftHand),
        (.leftHand, .leftHandThumb),
        (.leftHand, .leftHandIndex),
        (.leftHand, .leftHandPinky),

        // Brazo der
        (.rightShoulder1, .rightArm),
        (.rightArm, .rightForearm),
        (.rightForearm, .rightHand),
        (.rightHand, .rightHandThumb),
        (.rightHand, .rightHandIndex),
        (.rightHand, .rightHandPinky),

        // Caderas
        (.hips, .leftUpLeg),
        (.hips, .rightUpLeg),

        // Pierna izq
        (.leftUpLeg, .leftLeg),
        (.leftLeg, .leftFoot),
        (.leftFoot, .leftToes),

        // Pierna der
        (.rightUpLeg, .rightLeg),
        (.rightLeg, .rightFoot),
        (.rightFoot, .rightToes),

        // Ojos
        (.head, .leftEye),
        (.head, .rightEye)
    ]

    /// Color de clasificación para el UI.
    var region: BodyRegion {
        switch self {
        case .root, .hips, .spine1, .spine3, .spine5, .spine7,
             .neck1, .neck4, .head, .jaw, .leftEye, .rightEye:
            return .core
        case .leftShoulder1, .leftArm, .leftForearm, .leftHand,
             .leftHandThumb, .leftHandIndex, .leftHandPinky:
            return .leftLimb
        case .rightShoulder1, .rightArm, .rightForearm, .rightHand,
             .rightHandThumb, .rightHandIndex, .rightHandPinky:
            return .rightLimb
        case .leftUpLeg, .leftLeg, .leftFoot, .leftToes:
            return .leftLimb
        case .rightUpLeg, .rightLeg, .rightFoot, .rightToes:
            return .rightLimb
        }
    }
}

enum BodyRegion {
    case core, leftLimb, rightLimb
}
