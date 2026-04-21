//
//  SearchResultsView.swift
//  AcessNet
//
//  Vista de resultados de búsqueda de ubicaciones
//

import SwiftUI
import CoreLocation

// MARK: - Search Results View

struct SearchResultsView: View {
    @Environment(\.weatherTheme) private var theme
    let results: [SearchResult]
    let isSearching: Bool
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (SearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isSearching {
                searchingView
            } else if results.isEmpty {
                emptyResultsView
            } else {
                resultsList
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.78))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.textTint.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }

    // MARK: - Subviews

    private var searchingView: some View {
        HStack(spacing: 10) {
            ProgressView().tint(theme.textTint).scaleEffect(0.8)
            Text("Buscando…")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.75))
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }

    private var emptyResultsView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.5))

            Text("Sin resultados")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(theme.textTint.opacity(0.65))
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(results) { result in
                    SearchResultRow(
                        result: result,
                        userLocation: userLocation,
                        onSelect: { onSelect(result) }
                    )

                    if result.id != results.last?.id {
                        Rectangle().fill(theme.textTint.opacity(0.06)).frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    @Environment(\.weatherTheme) private var theme
    let result: SearchResult
    let userLocation: CLLocationCoordinate2D?
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onSelect()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(colorForPlaceType(result.placeType).opacity(0.2))
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(colorForPlaceType(result.placeType).opacity(0.4), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: result.placeType.icon)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(colorForPlaceType(result.placeType))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(theme.textTint)
                        .lineLimit(1)

                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.textTint.opacity(0.55))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if let distance = calculateDistance() {
                    HStack(spacing: 3) {
                        Text(distance)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "#60A5FA"))
                            .monospacedDigit()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(theme.textTint.opacity(0.4))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#60A5FA").opacity(0.12)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isPressed ? theme.textTint.opacity(0.08) : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func calculateDistance() -> String? {
        guard let userLocation = userLocation,
              let resultCoordinate = result.coordinate else {
            return nil
        }

        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let resultLoc = CLLocation(latitude: resultCoordinate.latitude, longitude: resultCoordinate.longitude)

        let distanceInMeters = userLoc.distance(from: resultLoc)

        if distanceInMeters < 1000 {
            return String(format: "%.0f m", distanceInMeters)
        } else {
            return String(format: "%.1f km", distanceInMeters / 1000)
        }
    }

    private func colorForPlaceType(_ type: PlaceType) -> Color {
        switch type {
        case .food:           return Color(hex: "#FB923C")
        case .entertainment:  return Color(hex: "#A78BFA")
        case .shopping:       return Color(hex: "#60A5FA")
        case .transportation: return Color(hex: "#34D399")
        case .health:         return Color(hex: "#F87171")
        case .nature:         return Color(hex: "#10B981")
        case .generic:        return Color(hex: "#94A3B8")
        }
    }
}

// MARK: - Recent Searches View (opcional, futuro)

struct RecentSearchesView: View {
    @Environment(\.weatherTheme) private var theme
    let recentSearches: [SearchHistoryItem]
    let onSelect: (SearchHistoryItem) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RECIENTES")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundColor(theme.textTint.opacity(0.55))

                Spacer()

                Button(action: {
                    HapticFeedback.light()
                    onClear()
                }) {
                    Text("Limpiar")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Color(hex: "#F87171"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle().fill(theme.textTint.opacity(0.08)).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(recentSearches) { search in
                        Button(action: {
                            HapticFeedback.light()
                            onSelect(search)
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(theme.textTint.opacity(0.08))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(theme.textTint.opacity(0.6))
                                }
                                .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(search.title)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(theme.textTint)
                                        .lineLimit(1)

                                    if !search.subtitle.isEmpty {
                                        Text(search.subtitle)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(theme.textTint.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.up.backward")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(theme.textTint.opacity(0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if search.id != recentSearches.last?.id {
                            Rectangle().fill(theme.textTint.opacity(0.06)).frame(height: 1)
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.78))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.textTint.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }
}

// MARK: - Preview

#Preview("Search Results") {
    VStack {
        Spacer()

        SearchResultsView(
            results: [
                SearchResult(
                    title: "Starbucks",
                    subtitle: "123 Main Street, San Francisco",
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ),
                SearchResult(
                    title: "Apple Park",
                    subtitle: "One Apple Park Way, Cupertino",
                    coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
                ),
                SearchResult(
                    title: "Golden Gate Bridge",
                    subtitle: "San Francisco, CA",
                    coordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
                )
            ],
            isSearching: false,
            userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            onSelect: { result in
                print("Selected: \(result.title)")
            }
        )
        .padding()

        Spacer()
    }
}

#Preview("Searching") {
    VStack {
        Spacer()

        SearchResultsView(
            results: [],
            isSearching: true,
            userLocation: nil,
            onSelect: { _ in }
        )
        .padding()

        Spacer()
    }
}

#Preview("No Results") {
    VStack {
        Spacer()

        SearchResultsView(
            results: [],
            isSearching: false,
            userLocation: nil,
            onSelect: { _ in }
        )
        .padding()

        Spacer()
    }
}
