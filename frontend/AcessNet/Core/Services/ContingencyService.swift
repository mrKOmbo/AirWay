//
//  ContingencyService.swift
//  AcessNet
//
//  Cliente HTTP para el endpoint /api/v1/contingency/forecast
//  Devuelve pronóstico probabilístico multi-horizon (24/48/72h).
//

import Foundation

enum ContingencyServiceError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(String)
    case networkError(String)
    case modelsNotReady

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "URL inválida."
        case .httpError(let code): return "Error HTTP \(code)"
        case .decodingError(let m): return "Error decodificando: \(m)"
        case .networkError(let m): return "Error de red: \(m)"
        case .modelsNotReady:      return "Los modelos de pronóstico aún no están listos."
        }
    }
}

final class ContingencyService {

    static let shared = ContingencyService()

    /// Producción por default. Para apuntar al backend local durante desarrollo:
    ///   UserDefaults.standard.set("http://localhost:8000/api/v1", forKey: "contingency_api_base")
    private let baseURL: String = {
        if let override = UserDefaults.standard.string(forKey: "contingency_api_base"),
           !override.isEmpty {
            return override
        }
        return "https://airway-api.onrender.com/api/v1"
    }()

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Public API

    /// Obtiene pronóstico de contingencia para una ubicación.
    /// - Parameters:
    ///   - lat: latitud (default CDMX Centro)
    ///   - lon: longitud
    ///   - hologram: "0", "00", "1", "2" — para personalizar recomendaciones
    func fetchForecast(
        lat: Double = 19.4326,
        lon: Double = -99.1332,
        hologram: String? = nil
    ) async throws -> ContingencyForecastResponse {

        var components = URLComponents(string: "\(baseURL)/contingency/forecast")
        var items = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
        ]
        if let hologram {
            items.append(URLQueryItem(name: "hologram", value: hologram))
        }
        components?.queryItems = items

        guard let url = components?.url else {
            throw ContingencyServiceError.invalidURL
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ContingencyServiceError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContingencyServiceError.networkError("Respuesta no HTTP.")
        }

        // 503 = modelos no entrenados
        if httpResponse.statusCode == 503 {
            throw ContingencyServiceError.modelsNotReady
        }

        guard httpResponse.statusCode == 200 else {
            throw ContingencyServiceError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ContingencyForecastResponse.self, from: data)
        } catch {
            throw ContingencyServiceError.decodingError(error.localizedDescription)
        }
    }

    /// Chequea si el backend tiene los modelos cargados.
    func health() async -> Bool {
        guard let url = URL(string: "\(baseURL)/contingency/health") else {
            return false
        }
        do {
            let (_, resp) = try await session.data(from: url)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
