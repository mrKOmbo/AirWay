//
//  BodyScanStorage.swift
//  AcessNet
//
//  Persistencia del único escaneo USDZ del usuario en Documents/BodyScan/.
//  Cada escaneo nuevo sobreescribe el anterior.
//

import Foundation
import Combine

@MainActor
final class BodyScanStorage: ObservableObject {

    static let shared = BodyScanStorage()

    @Published private(set) var hasSavedScan: Bool = false
    @Published private(set) var savedMetadata: BodyScanMetadata?

    private init() {
        refreshState()
    }

    // MARK: - Paths

    private var scansDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("BodyScan", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir,
                                                     withIntermediateDirectories: true)
        }
        return dir
    }

    var scanURL: URL {
        scansDirectory.appendingPathComponent("body_scan.usdz")
    }

    private var metadataURL: URL {
        scansDirectory.appendingPathComponent("metadata.json")
    }

    // MARK: - Public API

    func saveScan(from sourceURL: URL,
                  metadata: BodyScanMetadata) throws {
        let fm = FileManager.default

        // Reemplazar escaneo anterior
        if fm.fileExists(atPath: scanURL.path) {
            try fm.removeItem(at: scanURL)
        }
        try fm.copyItem(at: sourceURL, to: scanURL)

        // Escribir metadata
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: .atomic)

        refreshState()
    }

    func deleteScan() {
        let fm = FileManager.default
        try? fm.removeItem(at: scanURL)
        try? fm.removeItem(at: metadataURL)
        refreshState()
    }

    func loadMetadata() -> BodyScanMetadata? {
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(BodyScanMetadata.self, from: data)
    }

    // MARK: - State

    private func refreshState() {
        let exists = FileManager.default.fileExists(atPath: scanURL.path)
        hasSavedScan = exists
        savedMetadata = exists ? loadMetadata() : nil
    }
}

// MARK: - Metadata

struct BodyScanMetadata: Codable, Equatable {
    let createdAt: Date
    let vertexCount: Int?
    let estimatedHeightMeters: Double?
    let deviceModel: String

    init(createdAt: Date = Date(),
         vertexCount: Int?,
         estimatedHeightMeters: Double?,
         deviceModel: String) {
        self.createdAt = createdAt
        self.vertexCount = vertexCount
        self.estimatedHeightMeters = estimatedHeightMeters
        self.deviceModel = deviceModel
    }
}
