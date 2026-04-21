//
//  AnatomyLog.swift
//  AcessNet
//
//  Helper de logging dual: os.Logger (unified logging) + print() para que
//  aparezcan en la consola de Xcode al correr en device físico.
//

import Foundation
import os

enum AnatomyLog {
    enum Category {
        case coordinator, loader, shader

        var tag: String {
            switch self {
            case .coordinator: return "AR"
            case .loader:      return "LOAD"
            case .shader:      return "SHADER"
            }
        }
    }

    private static let coord = Logger(subsystem: "xyz.KOmbo.AirWay", category: "Anatomy")
    private static let loader = Logger(subsystem: "xyz.KOmbo.AirWay", category: "AnatomyLoader")
    private static let shader = Logger(subsystem: "xyz.KOmbo.AirWay", category: "XRayShader")

    // MARK: - Emisión

    private static func emit(_ level: Level, _ msg: String, category: Category) {
        let logger = logger(for: category)
        switch level {
        case .info:  logger.info("\(msg, privacy: .public)")
        case .warn:  logger.warning("\(msg, privacy: .public)")
        case .error: logger.error("\(msg, privacy: .public)")
        }
        // Los print() garantizan que Xcode los muestre en su consola cuando se
        // corre en device físico (unified logging por sí solo no aparece allí).
        print("[AirWay:\(category.tag)] \(level.icon) \(msg)")
    }

    enum Level {
        case info, warn, error
        var icon: String {
            switch self {
            case .info:  return "ℹ️"
            case .warn:  return "⚠️"
            case .error: return "🔴"
            }
        }
    }

    // MARK: - Firmas públicas (aceptan category primero o con default)

    static func info(_ msg: String, category: Category = .coordinator) {
        emit(.info, msg, category: category)
    }

    static func warn(_ msg: String, category: Category = .coordinator) {
        emit(.warn, msg, category: category)
    }

    static func error(_ msg: String, category: Category = .coordinator) {
        emit(.error, msg, category: category)
    }

    // Variantes con category primero (usadas por loader y shader).
    static func info(category: Category, _ msg: String) {
        emit(.info, msg, category: category)
    }

    static func warn(category: Category, _ msg: String) {
        emit(.warn, msg, category: category)
    }

    static func error(category: Category, _ msg: String) {
        emit(.error, msg, category: category)
    }

    // MARK: - Internal

    private static func logger(for category: Category) -> Logger {
        switch category {
        case .coordinator: return coord
        case .loader:      return loader
        case .shader:      return shader
        }
    }
}
