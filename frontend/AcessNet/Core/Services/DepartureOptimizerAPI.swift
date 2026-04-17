//
//  DepartureOptimizerAPI.swift
//  AcessNet
//
//  Cliente para /api/v1/fuel/optimal_departure.
//

import Foundation
import CoreLocation
import os

final class DepartureOptimizerAPI {
    static let shared = DepartureOptimizerAPI()

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var baseURL: URL { AppConfig.backendBaseURL }

    func suggest(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        vehicle: VehicleProfile,
        earliest: Date,
        latest: Date,
        stepMin: Int = 30,
        userProfile: [String: Any]? = nil
    ) async throws -> OptimalDepartureResponse {
        let url = baseURL.appendingPathComponent("api/v1/fuel/optimal_departure")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]

        var body: [String: Any] = [
            "origin": ["lat": origin.latitude, "lon": origin.longitude],
            "destination": ["lat": destination.latitude, "lon": destination.longitude],
            "vehicle": vehicle.toAPIDictionary(),
            "earliest": fmt.string(from: earliest),
            "latest": fmt.string(from: latest),
            "step_min": stepMin,
        ]
        if let up = userProfile { body["user_profile"] = up }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        AirWayLogger.departure.info(
            "DepartureOptimizerAPI.suggest vehicle=\(vehicle.fullDisplayName, privacy: .public) window=\(Int(latest.timeIntervalSince(earliest) / 60), privacy: .public)min step=\(stepMin, privacy: .public)min profile=\(userProfile != nil, privacy: .public)"
        )
        AirWayLogger.network.httpRequest(method: "POST", url: url, bodySize: req.httpBody?.count)

        let startT = Date()
        let (data, resp) = try await session.data(for: req)
        let elapsedMs = Date().timeIntervalSince(startT) * 1000
        guard let http = resp as? HTTPURLResponse else {
            AirWayLogger.departure.error("DepartureOptimizerAPI invalid response")
            throw FuelAPIError.invalidResponse
        }
        AirWayLogger.network.httpResponse(url: url, status: http.statusCode,
                                          bytes: data.count, durationMs: elapsedMs)
        guard (200..<300).contains(http.statusCode) else {
            let errText = String(data: data, encoding: .utf8)
            AirWayLogger.departure.error("DepartureOptimizerAPI \(http.statusCode): \(errText ?? "", privacy: .public)")
            throw FuelAPIError.serverError(http.statusCode, errText)
        }

        // Check for {"error": "..."} response with 200 status (backend fallback)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errMsg = json["error"] as? String {
            AirWayLogger.departure.error("DepartureOptimizerAPI error in body: \(errMsg, privacy: .public)")
            throw FuelAPIError.serverError(200, errMsg)
        }

        let response = try decoder.decode(OptimalDepartureResponse.self, from: data)
        AirWayLogger.departure.info(
            "DepartureOptimizerAPI result windows=\(response.windows.count, privacy: .public) best_at=\(response.best?.departTimeLabel ?? "-", privacy: .public) score=\(String(format: "%.1f", response.best?.score ?? 0), privacy: .public)"
        )
        return response
    }
}
