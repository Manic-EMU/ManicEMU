//
//  StikJITXPC.swift
//  ManicEmu
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#if SIDE_LOAD
import Foundation

let kManicStikJITListenerEndpointKey = "ManicStikJITListenerEndpoint"

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
#endif
