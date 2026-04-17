//
//  VehicleProfile.swift
//  AcessNet
//
//  Perfil del vehículo del usuario para estimación de combustible (GasolinaMeter).
//  Fuente de datos base: catálogo CONUEE (backend /fuel/catalog).
//  Persistido en UserDefaults via VehicleProfileService.
//

import Foundation

// MARK: - Fuel Type

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case magna = "magna"
    case premium = "premium"
    case diesel = "diesel"
    case hybrid = "hybrid"
    case electric = "electric"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .magna: return "Magna (87)"
        case .premium: return "Premium (93)"
        case .diesel: return "Diésel"
        case .hybrid: return "Híbrido"
        case .electric: return "Eléctrico"
        }
    }

    var systemIcon: String {
        switch self {
        case .electric: return "bolt.fill"
        case .hybrid: return "leaf.fill"
        case .diesel: return "fuelpump.circle.fill"
        default: return "fuelpump.fill"
        }
    }

    var pricePerLiterDefault: Double {
        switch self {
        case .magna: return 23.80
        case .premium: return 28.42
        case .diesel: return 28.28
        case .hybrid: return 23.80
        case .electric: return 2.85  // MXN por kWh aprox CFE DAC-1
        }
    }
}

// MARK: - Vehicle Profile

struct VehicleProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var make: String
    var model: String
    var year: Int
    var fuelType: FuelType
    var conueeKmPerL: Double
    var engineCc: Int
    var transmission: String
    var weightKg: Int
    var dragCoefficient: Double
    var drivingStyle: Double        // 0.85..1.25 (EMA)
    var nickname: String?
    var odometerKm: Int?
    var licensePlate: String?       // matrícula / placa
    var color: String?              // nombre color (ej. "Rojo") o hex (#AABBCC)
    var fuelTankCapacityL: Double?  // capacidad tanque en litros
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        fuelType: FuelType = .magna,
        conueeKmPerL: Double = 14.0,
        engineCc: Int = 1600,
        transmission: String = "manual",
        weightKg: Int = 1150,
        dragCoefficient: Double = 0.33,
        drivingStyle: Double = 1.0,
        nickname: String? = nil,
        odometerKm: Int? = nil,
        licensePlate: String? = nil,
        color: String? = nil,
        fuelTankCapacityL: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.fuelType = fuelType
        self.conueeKmPerL = conueeKmPerL
        self.engineCc = engineCc
        self.transmission = transmission
        self.weightKg = weightKg
        self.dragCoefficient = dragCoefficient
        self.drivingStyle = drivingStyle
        self.nickname = nickname
        self.odometerKm = odometerKm
        self.licensePlate = licensePlate
        self.color = color
        self.fuelTankCapacityL = fuelTankCapacityL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed

    var displayName: String {
        nickname ?? "\(make) \(model) \(year)"
    }

    var fullDisplayName: String {
        "\(make) \(model) \(year)"
    }

    var isElectric: Bool { fuelType == .electric }
    var isDiesel: Bool { fuelType == .diesel }

    var drivingStyleLabel: String {
        switch drivingStyle {
        case ..<0.92: return "Muy suave"
        case 0.92..<1.02: return "Suave"
        case 1.02..<1.12: return "Normal"
        case 1.12..<1.22: return "Agresivo"
        default: return "Muy agresivo"
        }
    }

    var formattedLicensePlate: String? {
        guard let plate = licensePlate?.trimmingCharacters(in: .whitespaces),
              !plate.isEmpty else { return nil }
        return plate.uppercased()
    }

    /// Autonomía estimada por tanque completo (km).
    var rangePerTankKm: Double? {
        guard let cap = fuelTankCapacityL, cap > 0 else { return nil }
        return cap * conueeKmPerL
    }

    // MARK: - Serialization para backend

    func toAPIDictionary() -> [String: Any] {
        [
            "make": make,
            "model": model,
            "year": year,
            "fuel_type": fuelType.rawValue,
            "conuee_km_per_l": conueeKmPerL,
            "engine_cc": engineCc,
            "transmission": transmission,
            "weight_kg": weightKg,
            "drag_coefficient": dragCoefficient,
            "driving_style": drivingStyle,
            "nickname": nickname as Any,
            "odometer_km": odometerKm as Any,
            "license_plate": licensePlate as Any,
            "color": color as Any,
            "fuel_tank_capacity_l": fuelTankCapacityL as Any,
        ]
    }

    // MARK: - Samples

    static let sample = VehicleProfile(
        make: "Chevrolet",
        model: "Aveo",
        year: 2018,
        fuelType: .magna,
        conueeKmPerL: 14.2,
        engineCc: 1600,
        transmission: "manual",
        weightKg: 1150
    )

    static let samples: [VehicleProfile] = [
        sample,
        VehicleProfile(make: "Nissan", model: "Versa", year: 2019,
                       fuelType: .magna, conueeKmPerL: 15.1, engineCc: 1600,
                       transmission: "manual", weightKg: 1104),
        VehicleProfile(make: "Toyota", model: "Prius", year: 2021,
                       fuelType: .hybrid, conueeKmPerL: 26.0, engineCc: 1800,
                       transmission: "cvt", weightKg: 1395),
    ]
}

// MARK: - CONUEE Catalog Entry (para fetch del backend)

struct ConueeVehicleEntry: Codable, Identifiable, Hashable {
    var id: String { "\(make)-\(model)-\(year)" }
    let make: String
    let model: String
    let year: Int
    let fuelType: FuelType
    let conueeKmPerL: Double
    let engineCc: Int
    let transmission: String
    let weightKg: Int

    enum CodingKeys: String, CodingKey {
        case make, model, year
        case fuelType = "fuel_type"
        case conueeKmPerL = "conuee_km_per_l"
        case engineCc = "engine_cc"
        case transmission
        case weightKg = "weight_kg"
    }

    func toVehicleProfile(nickname: String? = nil) -> VehicleProfile {
        VehicleProfile(
            make: make,
            model: model,
            year: year,
            fuelType: fuelType,
            conueeKmPerL: conueeKmPerL,
            engineCc: engineCc,
            transmission: transmission,
            weightKg: weightKg,
            nickname: nickname
        )
    }
}
