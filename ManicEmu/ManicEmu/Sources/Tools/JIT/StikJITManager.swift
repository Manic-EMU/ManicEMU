//
//  StikJITManager.swift
//  ManicEmu
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#if SIDE_LOAD
import UIKit
import UniformTypeIdentifiers
import Darwin

enum JITLaunchMode: Int {
    /// Includes the former Wait for Debugger (0) and StikDebug (1) stored values.
    case externalDebugger = 1
    case builtInDebugger = 2
}

final class StikJITManager: NSObject {
    static let shared = StikJITManager()

    private let kJITLaunchModeDefaultsKey = "jit_launch_mode"
    private let kPairingFileDisplayNameDefaultsKey = "stikjit_pairing_file_display_name"
    private let pairingFolderURL: URL
    private let pairingFileURL: URL
    private var pairingPickerHandler: ((URL?) -> Void)?

    private(set) var preparationStatus = ""
    private(set) var preparationFailureReason = ""

    override init() {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        pairingFolderURL = library.appendingPathComponent("StikJIT")
        pairingFileURL = pairingFolderURL.appendingPathComponent("pairingFile.plist")
        super.init()
        Self.migratePairingFileIfNeeded(to: pairingFileURL)
        try? FileManager.default.createDirectory(at: pairingFolderURL, withIntermediateDirectories: true)
        preparationStatus = R.string.localizable.jitPrepareNotChecked()
    }

    var showsMethodPicker: Bool {
        if #available(iOS 17.4, tvOS 17.4, *) {
            return true
        }
        return false
    }

    var isBuiltInAvailable: Bool {
        if isRunningInLiveContainer {
            return false
        }
        return showsMethodPicker
    }

    var isRunningInLiveContainer: Bool {
        getenv("LC_HOME_PATH") != nil
    }

    var jitLaunchMode: JITLaunchMode {
        get {
            guard isBuiltInAvailable else { return .externalDebugger }
            let stored: JITLaunchMode
            if let value = UserDefaults.standard.object(forKey: kJITLaunchModeDefaultsKey) as? NSNumber {
                stored = Self.mode(fromStoredValue: value.intValue)
            } else {
                stored = .builtInDebugger
            }
            if stored == .builtInDebugger && !isBuiltInAvailable {
                return .externalDebugger
            }
            return stored
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: kJITLaunchModeDefaultsKey)
        }
    }

    /// Old: 0 wait / 1 StikDebug / 2 built-in. 0 and 1 both map to external.
    private static func mode(fromStoredValue value: Int) -> JITLaunchMode {
        value == JITLaunchMode.builtInDebugger.rawValue ? .builtInDebugger : .externalDebugger
    }

    /// TXM needs universal.js; legacy JIT and PPL attach without a script.
    var shouldForceScript: Bool {
        ProcessInfo.processInfo.hasTXM
    }

    var hasPairingFile: Bool {
        FileManager.default.fileExists(atPath: pairingFileURL.path)
    }

    var pairingFileDisplayName: String {
        guard hasPairingFile else { return R.string.localizable.jitPairingNotImported() }
        return UserDefaults.standard.string(forKey: kPairingFileDisplayNameDefaultsKey)
            ?? pairingFileURL.lastPathComponent
    }

    func currentPairingFileURL() -> URL? {
        hasPairingFile ? pairingFileURL : nil
    }

    func importPairingFile(_ sourceURL: URL) throws {
        try FileManager.default.createDirectory(at: pairingFolderURL, withIntermediateDirectories: true)
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: pairingFileURL, options: .atomic)
        UserDefaults.standard.set(sourceURL.lastPathComponent, forKey: kPairingFileDisplayNameDefaultsKey)
        invalidateReadiness()
    }

    /// Documents/StikJIT was visible in Files sharing; Library is the canonical store.
    private static func migratePairingFileIfNeeded(to destination: URL) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyFolder = documents.appendingPathComponent("StikJIT")
        let legacyFile = legacyFolder.appendingPathComponent("pairingFile.plist")
        let fm = FileManager.default
        if fm.fileExists(atPath: legacyFile.path) {
            try? fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try? fm.removeItem(at: legacyFile)
            } else {
                try? fm.moveItem(at: legacyFile, to: destination)
            }
        }
        if let contents = try? fm.contentsOfDirectory(atPath: legacyFolder.path), contents.isEmpty {
            try? fm.removeItem(at: legacyFolder)
        }
    }

    func presentPairingFilePicker(completion: @escaping (Bool, String?) -> Void) {
        let types: [UTType] = [.propertyList, UTType(filenameExtension: "plist")].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        pairingPickerHandler = { [weak self] url in
            guard let self, let url else {
                completion(false, nil)
                return
            }
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try self.importPairingFile(url)
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
            }
        }
        topViewController()?.present(picker, animated: true)
    }

    func invalidateReadiness() {
        preparationStatus = R.string.localizable.jitPrepareNotChecked()
        preparationFailureReason = ""
    }

    func updateReadiness(status: String, reason: String?) {
        preparationStatus = status
        preparationFailureReason = reason ?? ""
    }

    func title(for mode: JITLaunchMode) -> String {
        switch mode {
        case .externalDebugger:
            return R.string.localizable.jitMethodExternalDebugger()
        case .builtInDebugger:
            return R.string.localizable.jitMethodBuiltInDebugger()
        }
    }

    func info(for mode: JITLaunchMode) -> String {
        switch mode {
        case .externalDebugger:
            return R.string.localizable.jitMethodExternalInfo()
        case .builtInDebugger:
            return R.string.localizable.jitMethodBuiltInInfo()
        }
    }
}

extension StikJITManager: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pairingPickerHandler?(urls.first)
        pairingPickerHandler = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pairingPickerHandler?(nil)
        pairingPickerHandler = nil
    }
}
#endif
