//
//  JITEnablerRequestHandler.swift
//  JITEnabler
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import Darwin
import os.log

@objc(StikJITRunnerXPCProtocol)
protocol StikJITRunnerXPCProtocol {
    func prepareDevice(pairingData: Data)
    func resetCachedDDI()
    func enableJIT(forParentPID pid: Int32, pairingData: Data, forceScript: Bool)
}

@objc(StikJITHostXPCProtocol)
protocol StikJITHostXPCProtocol {
    func preparationProgress(_ stage: String, fraction: Double, detail: String?)
    func preparationFinished(_ readiness: String, reason: String?, txmPresent: NSNumber?)
    func ddiResetFinished(_ ok: Bool, error: String?)
    func jitLog(_ line: String)
    func jitFinished(_ ok: Bool, error: String?)
}

private let kListenerEndpointKey = "ManicStikJITListenerEndpoint"
private let backendSelectedScript: StikJIT.Script = .universal
private let stikJITOSLog = OSLog(subsystem: "com.aoshuang.manicemu.JITEnabler", category: "StikJIT")

private func jitLog(_ message: String) {
#if DEBUG
    os_log(.default, log: stikJITOSLog, "%{public}@", message)
#endif
}

@objc(JITEnablerRequestHandler)
final class JITEnablerRequestHandler: NSObject, NSExtensionRequestHandling, StikJITRunnerXPCProtocol {
    private let operationQueue = DispatchQueue(label: "com.aoshuang.manicemu.jitenabler.stikjit", qos: .userInitiated)
    private var connection: NSXPCConnection?
    private var host: StikJITHostXPCProtocol?

    private let paths: DDIPaths = {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return DDIPaths.default(in: library.appendingPathComponent("StikJIT"))
    }()

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let endpoint = item.userInfo?[kListenerEndpointKey] as? NSXPCListenerEndpoint else {
            jitLog("beginRequest missing XPC endpoint")
            context.cancelRequest(withError: NSError(domain: "JITEnablerRequestHandler", code: 1))
            return
        }

        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.exportedInterface = NSXPCInterface(with: StikJITRunnerXPCProtocol.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: StikJITHostXPCProtocol.self)
        connection.resume()
        self.connection = connection
        self.host = connection.remoteObjectProxyWithErrorHandler { error in
            jitLog("host XPC error: \(error.localizedDescription)")
        } as? StikJITHostXPCProtocol
        jitLog("runner alive pid=\(getpid()) ddiImage=\(paths.imagePath)")
        host?.jitLog("StikJIT runner alive, pid \(getpid())")
    }

    func prepareDevice(pairingData: Data) {
        let host = self.host
        operationQueue.async { [paths] in
            jitLog("prepareDevice pairingBytes=\(pairingData.count)")
            do {
                try Self.withTemporaryPairingFile(pairingData) { pairingFile in
                    jitLog("prepareDevice pairingTemp=\(pairingFile.path)")
                    let readiness = StikJIT.prepareDevice(
                        pairingFile: pairingFile,
                        paths: paths,
                        configuration: .default
                    ) { stage in
                        let update = Self.preparationUpdate(for: stage)
                        jitLog("prepare stage=\(update.stage) fraction=\(update.fraction) detail=\(update.detail ?? "")")
                        host?.preparationProgress(update.stage, fraction: update.fraction, detail: update.detail)
                    }

                    switch readiness {
                    case .unreachable(let reason):
                        jitLog("prepare unreachable: \(reason)")
                        host?.preparationFinished("unreachable", reason: reason, txmPresent: nil)
                    case .preparationFailed(let reason):
                        jitLog("prepare failed: \(reason)")
                        host?.preparationFinished("preparationFailed", reason: reason, txmPresent: nil)
                    case .ready(let securityState):
                        jitLog("prepare ready txm=\(String(describing: securityState.isTXMPresent))")
                        host?.preparationFinished(
                            "ready",
                            reason: nil,
                            txmPresent: securityState.isTXMPresent.map(NSNumber.init(value:)))
                    }
                }
            } catch {
                jitLog("prepare exception: \(error.localizedDescription)")
                host?.preparationFinished("preparationFailed", reason: error.localizedDescription, txmPresent: nil)
            }
        }
    }

    func resetCachedDDI() {
        let host = self.host
        operationQueue.async { [paths] in
            jitLog("resetCachedDDI \(paths.imagePath)")
            do {
                try StikJIT.resetCachedDDI(at: paths)
                jitLog("resetCachedDDI ok")
                host?.ddiResetFinished(true, error: nil)
            } catch {
                jitLog("resetCachedDDI failed: \(error.localizedDescription)")
                host?.ddiResetFinished(false, error: error.localizedDescription)
            }
        }
    }

    func enableJIT(forParentPID pid: Int32, pairingData: Data, forceScript: Bool) {
        let host = self.host
        operationQueue.async { [paths] in
            jitLog("enableJIT pid=\(pid) forceScript=\(forceScript) pairingBytes=\(pairingData.count)")
            do {
                try Self.withTemporaryPairingFile(pairingData) { pairingFile in
                    try StikJIT.enableJIT(
                        targetPID: pid,
                        pairingFile: pairingFile,
                        ddiPaths: paths,
                        script: backendSelectedScript,
                        forceScript: forceScript,
                        preparationProgress: { stage in
                            let update = Self.preparationUpdate(for: stage)
                            let line = update.detail ?? update.stage
                            jitLog("enableJIT prepare \(line)")
                            host?.jitLog(line)
                        },
                        progress: { line in
                            jitLog("enableJIT \(line)")
                            host?.jitLog(line)
                        })
                }
                jitLog("enableJIT finished ok")
                host?.jitFinished(true, error: nil)
            } catch {
                jitLog("enableJIT failed: \(error.localizedDescription)")
                host?.jitLog("enableJIT failed: \(error.localizedDescription)")
                host?.jitFinished(false, error: error.localizedDescription)
            }
        }
    }

    private static func withTemporaryPairingFile<T>(_ data: Data, operation: (URL) throws -> T) throws -> T {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("jitenabler-pairing-\(UUID().uuidString).plist")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        return try operation(url)
    }

    private static func preparationUpdate(for stage: StikJIT.PreparationStage) ->
        (stage: String, fraction: Double, detail: String?) {
        switch stage {
        case .checkingReachability:
            return ("Checking Network", 0, nil)
        case .checkingDDI:
            return ("Checking DDI", 0, nil)
        case .downloadingDDI(let fraction, let status):
            return ("Downloading", fraction, status)
        case .mountingDDI(let fraction):
            return ("Mounting", fraction, nil)
        case .verifyingDDI:
            return ("Verifying", 1, nil)
        case .ready:
            return ("Ready", 1, nil)
        }
    }
}
