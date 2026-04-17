//
//  Vehicle3DAsset.swift
//  AcessNet
//
//  Registry de modelos 3D (USDZ) disponibles en el bundle.
//  Mapea un VehicleProfile al asset más apropiado mediante heurística.
//

import Foundation

enum Vehicle3DAsset: String, CaseIterable, Identifiable {
    case sedan        = "CAR Model"
    case convertible  = "Convertible"

    var id: String { rawValue }
    var fileExtension: String { "usdz" }
    var assetName: String { rawValue }

    var displayName: String {
        switch self {
        case .sedan:       return "Sedán"
        case .convertible: return "Convertible"
        }
    }

    var subtitle: String {
        switch self {
        case .sedan:       return "Silueta estándar · 4 puertas"
        case .convertible: return "Deportivo · techo abatible"
        }
    }

    var systemIcon: String {
        switch self {
        case .sedan:       return "car.fill"
        case .convertible: return "car.side.rear.and.collision.and.car.side.front"
        }
    }

    var tags: [String] {
        switch self {
        case .sedan:       return ["sedán", "hatchback", "suv", "estándar"]
        case .convertible: return ["convertible", "roadster", "deportivo", "sport", "coupé"]
        }
    }

    /// Heurística que elige el modelo 3D a partir del perfil del vehículo.
    static func forProfile(_ profile: VehicleProfile) -> Vehicle3DAsset {
        let haystack = "\(profile.make) \(profile.model)".lowercased()
        let sportKeywords = [
            "convertible", "roadster", "miata", "mx-5", "mx5",
            "corvette", "mustang", "camaro", "challenger", "370z", "370-z", "350z",
            "nsx", "boxster", "cayman", "911", "porsche", "ferrari",
            "aston", "mclaren", "spider", "spyder", "supra", "brz", "gt-r", "gtr",
            "lotus", "viper"
        ]
        if sportKeywords.contains(where: { haystack.contains($0) }) {
            return .convertible
        }
        return .sedan
    }

    static var fallback: Vehicle3DAsset { .sedan }

    /// Perfil demo realista asociado a cada modelo 3D.
    var demoProfile: VehicleProfile {
        switch self {
        case .sedan:
            return VehicleProfile(
                make: "Lada",
                model: "Samara",
                year: 1998,
                fuelType: .magna,
                conueeKmPerL: 11.5,
                engineCc: 1500,
                transmission: "manual",
                weightKg: 1015,
                dragCoefficient: 0.46,
                drivingStyle: 1.0,
                nickname: "Mi Lada",
                odometerKm: 45200,
                licensePlate: "ABC-123-A",
                color: "Rojo",
                fuelTankCapacityL: 43
            )
        case .convertible:
            return VehicleProfile(
                make: "Mazda",
                model: "MX-5 Miata",
                year: 2020,
                fuelType: .premium,
                conueeKmPerL: 13.8,
                engineCc: 2000,
                transmission: "manual",
                weightKg: 1058,
                dragCoefficient: 0.36,
                drivingStyle: 1.10,
                nickname: "Miata",
                odometerKm: 18500,
                licensePlate: "NX5-MX-22",
                color: "Rojo",
                fuelTankCapacityL: 45
            )
        }
    }
}
