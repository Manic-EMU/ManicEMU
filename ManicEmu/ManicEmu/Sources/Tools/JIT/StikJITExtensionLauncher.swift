//
//  StikJITExtensionLauncher.swift
//  ManicEmu
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#if SIDE_LOAD
import Foundation
import ObjectiveC.runtime

/// Starts the JITEnabler appex via private NSExtension APIs and hands back an XPC runner.
final class StikJITExtensionLauncher: NSObject, NSXPCListenerDelegate {
    private weak var host: StikJITHostXPCProtocol?
    private var listener: NSXPCListener?
    private var connection: NSXPCConnection?
    private var extensionObject: NSObject?
    private var requestId: NSUUID?
    private var childPID: Int32 = -1
    private var completed = false
    private var launchCompletion: ((Int32, StikJITRunnerXPCProtocol?, Error?) -> Void)?

    init(host: StikJITHostXPCProtocol) {
        self.host = host
        super.init()
    }

    func launch(completion: @escaping (Int32, StikJITRunnerXPCProtocol?, Error?) -> Void) {
        launchCompletion = completion

        let listener = NSXPCListener.anonymous()
        listener.delegate = self
        listener.resume()
        self.listener = listener

        guard let identifier = childBundleIdentifier() else {
            finish(-1, runner: nil, error: launcherError(code: 1, "StikJIT runner .appex not found"))
            return
        }

        var createError: NSError?
        guard let ext = createExtension(identifier: identifier, error: &createError) else {
            let reason = createError?.localizedDescription ?? "NSExtension creation failed"
            finish(-1, runner: nil, error: createError ?? launcherError(code: 2, reason))
            return
        }
        extensionObject = ext

        let interruptSel = NSSelectorFromString("setRequestInterruptionBlock:")
        if ext.responds(to: interruptSel) {
            let block: @convention(block) (NSUUID?) -> Void = { [weak self] _ in
                self?.finish(-1, runner: nil, error: self?.launcherError(code: 3, "runner interrupted before bootstrap"))
            }
            typealias SetBlock = @convention(c) (AnyObject, Selector, @convention(block) (NSUUID?) -> Void) -> Void
            if let method = class_getInstanceMethod(type(of: ext), interruptSel) {
                unsafeBitCast(method_getImplementation(method), to: SetBlock.self)(ext, interruptSel, block)
            }
        }

        let input = NSExtensionItem()
        input.userInfo = [kManicStikJITListenerEndpointKey: listener.endpoint]

        var requestError: NSError?
        let beginSel = NSSelectorFromString("beginExtensionRequestWithInputItems:error:")
        if ext.responds(to: beginSel) {
            typealias BeginFn = @convention(c) (AnyObject, Selector, NSArray, AutoreleasingUnsafeMutablePointer<NSError?>) -> AnyObject?
            let impl = class_getInstanceMethod(type(of: ext), beginSel).map { method_getImplementation($0) }
            if let impl {
                var err: NSError?
                let fn = unsafeBitCast(impl, to: BeginFn.self)
                let req = fn(ext, beginSel, [input] as NSArray, &err)
                requestId = req as? NSUUID
                requestError = err
            }
        } else {
            let sel = NSSelectorFromString("beginRequestWithInputItems:")
            if ext.responds(to: sel) {
                if let result = ext.perform(sel, with: [input])?.takeUnretainedValue() as? NSUUID {
                    requestId = result
                }
            }
        }

        guard requestId != nil else {
            let reason = requestError?.localizedDescription ?? "begin extension request failed"
            finish(-1, runner: nil, error: requestError ?? launcherError(code: 4, reason))
            return
        }

        // pidForRequestIdentifier: returns pid_t, not an object. NSObject.perform would
        // treat that integer as a pointer and crash in swift_unknownObjectRetain.
        let pidSel = NSSelectorFromString("pidForRequestIdentifier:")
        if ext.responds(to: pidSel), let requestId,
           let method = class_getInstanceMethod(type(of: ext), pidSel) {
            typealias PIDFn = @convention(c) (AnyObject, Selector, NSUUID) -> Int32
            childPID = unsafeBitCast(method_getImplementation(method), to: PIDFn.self)(ext, pidSel, requestId)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.finish(-1, runner: nil, error: self?.launcherError(code: 5, "timed out waiting for runner"))
        }
    }

    func invalidate() {
        connection?.invalidate()
        connection = nil
        if let ext = extensionObject, ext.responds(to: NSSelectorFromString("_kill:")) {
            let sel = NSSelectorFromString("_kill:")
            if let method = class_getInstanceMethod(type(of: ext), sel) {
                typealias KillFn = @convention(c) (AnyObject, Selector, Int32) -> Void
                unsafeBitCast(method_getImplementation(method), to: KillFn.self)(ext, sel, 9)
            }
        }
        extensionObject = nil
        listener?.invalidate()
        listener = nil
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        if connection != nil {
            newConnection.invalidate()
            return false
        }
        connection = newConnection
        newConnection.exportedInterface = NSXPCInterface(with: StikJITHostXPCProtocol.self)
        newConnection.exportedObject = host
        newConnection.remoteObjectInterface = NSXPCInterface(with: StikJITRunnerXPCProtocol.self)
        newConnection.resume()
        let runner = newConnection.remoteObjectProxyWithErrorHandler { _ in } as? StikJITRunnerXPCProtocol
        finish(childPID, runner: runner, error: nil)
        return true
    }

    private func finish(_ pid: Int32, runner: StikJITRunnerXPCProtocol?, error: Error?) {
        guard !completed else { return }
        completed = true
        launchCompletion?(pid, runner, error)
        launchCompletion = nil
    }

    private func childBundleIdentifier() -> String? {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(
                at: plugins,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles) else {
            return nil
        }
        for url in items where url.pathExtension == "appex" {
            if let identifier = Bundle(url: url)?.bundleIdentifier,
               identifier.hasSuffix(".JITEnabler") {
                return identifier
            }
        }
        return items.compactMap { url -> String? in
            guard url.pathExtension == "appex" else { return nil }
            return Bundle(url: url)?.bundleIdentifier
        }.first
    }

    private func createExtension(identifier: String, error: inout NSError?) -> NSObject? {
        guard let cls = NSClassFromString("NSExtension") as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString("extensionWithIdentifier:excludingDisabledExtensions:error:")
        guard let method = class_getClassMethod(cls, sel) else { return nil }
        typealias CreateFn = @convention(c) (AnyClass, Selector, NSString, Bool, AutoreleasingUnsafeMutablePointer<NSError?>) -> AnyObject?
        let fn = unsafeBitCast(method_getImplementation(method), to: CreateFn.self)
        var err: NSError?
        let ext = fn(cls, sel, identifier as NSString, false, &err)
        error = err
        return ext as? NSObject
    }

    private func launcherError(code: Int, _ message: String) -> NSError {
        NSError(domain: "StikJITLauncher", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
#endif
