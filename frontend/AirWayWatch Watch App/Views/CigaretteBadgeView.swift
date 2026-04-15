//
//  CigaretteBadgeView.swift
//  AirWayWatch Watch App
//
//  Compact badge showing cigarette equivalence on the main watch screen.
//  Tapping navigates to the full ExposureView.
//
//  Color coding:
//    < 1 cigarette  → green  (low exposure)
//    1-3 cigarettes → yellow (moderate)
//    3-5 cigarettes → orange (high)
//    > 5 cigarettes → red    (very high)
//

import SwiftUI

struct CigaretteBadgeView: View {
    let cigarettes: Double
    let ratePerHour: Double

    private var badgeColor: Color {
        switch cigarettes {
        case ..<1:   return Color(hex: "#4CD964")
        case 1..<3:  return Color(hex: "#FFD60A")
        case 3..<5:  return Color(hex: "#FF9F0A")
        default:     return Color(hex: "#FF3B30")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Cigarette icon
            Text("\u{1F6AC}")  // 🚬
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", cigarettes))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(badgeColor)

                    Text("cigs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                if ratePerHour > 0.01 {
                    Text(String(format: "+%.2f/h", ratePerHour))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(badgeColor.opacity(0.7))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(badgeColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(badgeColor.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}
