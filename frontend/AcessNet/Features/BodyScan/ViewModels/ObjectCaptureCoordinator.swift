//
//  ObjectCaptureCoordinator.swift
//  AcessNet
//
//  Wrapper alrededor de ObjectCaptureSession + PhotogrammetrySession (WWDC23).
//  Maneja el ciclo de vida completo: directorio temporal → captura → reconstrucción
//  → guardado en BodyScanStorage como USDZ único.
//

import Foundation
import RealityKit
import Combine
import SwiftUI
import os

@MainActor
@Observable
final class ObjectCaptureCoordinator {

    // MARK: - State

    enum Phase: Equatable {
        case preparing
        case ready              // bounding box no detectada aún
        case detecting          // bounding box detectada, esperar tap
        case capturing(progress: Double)
        case finishing
        case reconstructing(progress: Double)
        case completed
        case failed(String)
    }

    var session: ObjectCaptureSession?
    var phase: Phase = .preparing
    var photogrammetrySession: PhotogrammetrySession?

    private(set) var captureDirectory: URL?
    private(set) var imagesDirectory: URL?
    private(set) var modelOutputURL: URL?
    private var stateObservationTask: Task<Void, Never>?
    private var passObservationTask: Task<Void, Never>?

    private let log = Logger(subsystem: "xyz.KOmbo.AirWay", category: "ObjectCapture")

    // MARK: - Support

    static var isSupported: Bool {
        ObjectCaptureSession.isSupported
    }

    /// `true` cuando la sesión está en una fase donde el usuario debe enfocarse
    /// en el viewfinder sin distracciones (ocultar chrome de navegación).
    var isScanningActive: Bool {
        switch phase {
        case .capturing, .finishing, .reconstructing:
            return true
        default:
            return false
        }
    }

    var isCompleted: Bool {
        if case .completed = phase { return true }
        return false
    }

    // MARK: - Lifecycle

    func start() {
        guard Self.isSupported else {
            phase = .failed("Object Capture requiere iPhone 12 Pro o superior con LiDAR")
            return
        }

        do {
            let dir = try createScanDirectory()
            captureDirectory = dir
            imagesDirectory = dir.appendingPathComponent("Images", isDirectory: true)
            modelOutputURL = dir.appendingPathComponent("model.usdz")
            try FileManager.default.createDirectory(at: imagesDirectory!,
                                                    withIntermediateDirectories: true)

            let newSession = ObjectCaptureSession()
            self.session = newSession
            newSession.start(imagesDirectory: imagesDirectory!)

            observeState()
            phase = .ready
        } catch {
            phase = .failed("No se pudo iniciar: \(error.localizedDescription)")
        }
    }

    func cancel() {
        stateObservationTask?.cancel()
        passObservationTask?.cancel()
        session?.cancel()
        session = nil
        photogrammetrySession?.cancel()
        photogrammetrySession = nil
        cleanupTemporaryDirectory()
    }

    // MARK: - User actions

    func startDetecting() {
        guard let session, session.state == .ready else { return }
        let ok = session.startDetecting()
        log.info("startDetecting → \(ok)")
        if ok { phase = .detecting }
    }

    func startCapturing() {
        guard let session, session.state == .detecting else { return }
        session.startCapturing()
        phase = .capturing(progress: 0)
    }

    func finish() {
        guard let session else { return }
        phase = .finishing
        session.finish()
    }

    // MARK: - State observation

    private func observeState() {
        guard let session else { return }

        stateObservationTask?.cancel()
        stateObservationTask = Task { @MainActor [weak self] in
            for await state in session.stateUpdates {
                guard let self else { return }
                self.handleStateChange(state)
            }
        }

        passObservationTask?.cancel()
        passObservationTask = Task { @MainActor [weak self] in
            for await completed in session.userCompletedScanPassUpdates {
                guard let self else { return }
                if completed {
                    // Apple recomienda 3 pasadas (low / normal / high). Por simplicidad
                    // finalizamos tras la primera. El usuario puede repetir capturas.
                    self.finish()
                }
            }
        }
    }

    private func handleStateChange(_ state: ObjectCaptureSession.CaptureState) {
        log.info("ObjectCapture state → \(String(describing: state))")
        switch state {
        case .initializing:
            phase = .preparing
        case .ready:
            phase = .ready
        case .detecting:
            phase = .detecting
        case .capturing:
            // El progreso de cobertura no está expuesto directamente como Double;
            // mantenemos un estimado basado en numberOfShotsTaken.
            let shots = Double(session?.numberOfShotsTaken ?? 0)
            let target = 50.0
            phase = .capturing(progress: min(shots / target, 1.0))
        case .finishing:
            phase = .finishing
        case .completed:
            Task { await self.runReconstruction() }
        case .failed(let error):
            phase = .failed(error.localizedDescription)
        @unknown default:
            phase = .failed("Estado desconocido")
        }
    }

    // MARK: - Reconstruction (PhotogrammetrySession)

    private func runReconstruction() async {
        guard let imagesDirectory, let modelOutputURL else {
            phase = .failed("Falta directorio de captura")
            return
        }

        phase = .reconstructing(progress: 0)
        // Liberar el ObjectCaptureSession antes de procesar (libera recursos LiDAR).
        session = nil

        do {
            let photogrammetry = try PhotogrammetrySession(input: imagesDirectory)
            self.photogrammetrySession = photogrammetry

            try photogrammetry.process(requests: [
                .modelFile(url: modelOutputURL, detail: .reduced)
            ])

            for try await output in photogrammetry.outputs {
                switch output {
                case .processingComplete:
                    await commitToStorage()
                case .requestProgress(_, let fraction):
                    phase = .reconstructing(progress: fraction)
                case .requestError(_, let error):
                    phase = .failed("Reconstrucción falló: \(error.localizedDescription)")
                    return
                case .processingCancelled:
                    phase = .failed("Reconstrucción cancelada")
                    return
                default:
                    break
                }
            }
        } catch {
            phase = .failed("PhotogrammetrySession: \(error.localizedDescription)")
        }
    }

    private func commitToStorage() async {
        guard let modelOutputURL else { return }
        do {
            let metadata = BodyScanMetadata(
                vertexCount: nil,
                estimatedHeightMeters: nil,
                deviceModel: UIDevice.current.model
            )
            try BodyScanStorage.shared.saveScan(from: modelOutputURL, metadata: metadata)
            phase = .completed
            cleanupTemporaryDirectory()
        } catch {
            phase = .failed("Guardado falló: \(error.localizedDescription)")
        }
    }

    // MARK: - File management

    private func createScanDirectory() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        let root = docs.appendingPathComponent("ObjectCaptureWorkspace", isDirectory: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let dir = root.appendingPathComponent(stamp, isDirectory: true)
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        return dir
    }

    private func cleanupTemporaryDirectory() {
        guard let captureDirectory else { return }
        try? FileManager.default.removeItem(at: captureDirectory)
        self.captureDirectory = nil
        self.imagesDirectory = nil
        self.modelOutputURL = nil
    }
}
