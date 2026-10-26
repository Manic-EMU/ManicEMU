//
//  ThreeDS.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation
#if !SIMULATOR
import Citra
#endif
import MetalKit

extension GameType
{
    static let _3ds = GameType("public.aoshuang.game.3ds")
}

@objc enum ThreeDSGameInput: Int, Input, CaseIterable {
    case a = 700
    case b = 701
    case x = 702
    case y = 703
    case start = 704
    case select = 705
    case home = 706
    case menu = 1
    case l2 = 707
    case r2 = 708
    case up = 709
    case down = 710
    case left = 711
    case right = 712
    case l1 = 773
    case r1 = 774
    case CirclePad = 713
    case leftThumbstickUp = 714
    case leftThumbstickDown = 715
    case leftThumbstickLeft = 716
    case leftThumbstickRight = 717
    case CStick = 718
    case rightThumbstickUp = 719
    case rightThumbstickDown = 720
    case rightThumbstickLeft = 771
    case rightThumbstickRight = 772
    
    case touchScreenX = 4096
    case touchScreenY = 8192
    
    case flex = 0

    var type: InputType {
        return .game(._3ds)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        case .touchScreenX, .touchScreenY: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "home" { self = .home }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "r2" { self = .r2 }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "CirclePad" { self = .CirclePad }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "CStick" { self = .CStick }
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp }
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown }
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft }
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight }
        else if stringValue == "touchScreenX" { self = .touchScreenX }
        else if stringValue == "touchScreenY" { self = .touchScreenY }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct ThreeDS: DeltaCoreProtocol {
    /// Library entry for a Home Menu that already lives in NAND.
    /// `.app` romUrl points at that NAND content, so copying it with replacement deletes the source.
    static func registerInstalledHomeMenu(at fileURL: URL, identifier: UInt64) {
        let titleLow = String(format: "%08x", UInt32(identifier & 0xFFFFFFFF))
        let regionByTitle = [
            "00008202": "JPN",
            "00008f02": "USA",
            "00009802": "EUR",
            "0000a102": "CHN",
            "0000a902": "KOR",
            "0000b102": "TWN"
        ]
        guard let region = regionByTitle[titleLow] else { return }
        guard let hash = FileHashUtil.truncatedHash(url: fileURL) else { return }
        let realm = Database.realm
        if let game = realm.object(ofType: Game.self, forPrimaryKey: hash) {
            if game.isDeleted {
                try? realm.write { game.isDeleted = false }
            }
            return
        }
        let game = Game()
        game.id = hash
        game.name = fileURL.deletingPathExtension().lastPathComponent
        game.fileExtension = fileURL.pathExtension
        game.gameType = ._3ds
        game.extras = [
            ExtraKey.identifier.rawValue: identifier,
            ExtraKey.regions.rawValue: region
        ].jsonData()
        game.aliasName = "Home Menu (\(region))"
        game.importDate = Date()
        if let index = GlobalCoreSwitch.getConfig(realm: realm).getUsingCoreIndex(gameType: ._3ds) {
            game.defaultCore = index
        }
        try? realm.write { realm.add(game) }
    }

    static func generate3DSHomeMenu() {
        let homeMenus = [
            "JPN": "/00008202/",
            "USA": "/00008f02/",
            "EUR": "/00009802/",
            "CHN": "/0000a102/",
            "KOR": "/0000a902/",
            "TWN": "/0000b102/"
        ]
        
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: R.Path.Document.appendingPathComponent("3DS/nand/00000000000000000000000000000000/title/00040030")), includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard !isDirectory else { continue }
                guard fileURL.pathExtension.lowercased() == "app" else { continue }
                for (region, path) in homeMenus {
                    if fileURL.path.contains(path, caseSensitive: false) {
                        print("发现home menu")
                        let realm = Database.realm
                        if let hash = FileHashUtil.truncatedHash(url: fileURL) {
                            if let _ = realm.object(ofType: Game.self, forPrimaryKey: hash) {
                                continue
                            } else {
                                let game = Game()
                                game.id = hash
                                game.name = fileURL.deletingPathExtension().lastPathComponent
                                game.fileExtension = fileURL.pathExtension
                                game.gameType = ._3ds
                                game.extras = [
                                    ExtraKey.identifier.rawValue: R.Numbers.ThreeDSHomeMenuIdentifiers[R.Strings.ThreeDSHomeMenuRegions.firstIndex(where: { $0 == region }) ?? 0],
                                    ExtraKey.regions.rawValue: region
                                ].jsonData()
                                game.aliasName = "Home Menu (\(region))"
                                game.importDate = Date()
                                game.defaultCore = 1
                                try? realm.write { realm.add(game) }
                            }
                        }
                    }
                }
            }
        }
    }
    
    static let core = ThreeDS()
    
    var name: String { "3DS" }
    var identifier: String { "com.aoshuang.3DSCore" }
    var version: String? { "1.7.0" }
    
    var gameType: GameType { GameType._3ds }
    var gameInputType: Input.Type { ThreeDSGameInput.self }
    var allInputs: [Input] { ThreeDSGameInput.allCases }
    var gameSaveFileExtension: String { "3ds.sav" }
    
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 400, height: 480))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Gateshark", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .gateshark)
        return [actionReplayFormat]
    }
    
    static var isAzaharCore: Bool = false
    
    var emulatorBridge: EmulatorBridging {
        if Self.isAzaharCore {
            return AzaharEmulatorBridge.shared
        } else {
            return ThreeDSEmulatorBridge.shared
        }
    }
    
    private init()
    {
    }
    
    //For Citra
    static func setupCheats(identifier: UInt64, cheatsTxt: String, enableCheats: [String]) {
#if !SIMULATOR
        let manager = CitraCheatsManager(identifier: identifier)
        let path = manager.cheatFilePath()
        try? cheatsTxt.writeWithCompletePath(to: URL(fileURLWithPath: path))
        manager.loadCheats()
        let cheats = manager.getCheats()
        for (index, cheat) in cheats.enumerated() {
            if enableCheats.contains(where: { $0.contains(cheat.name) }) {
                cheat.enabled = true
            } else {
                cheat.enabled = false
            }
            manager.update(cheat, at: index)
        }
        manager.saveCheats()
#endif
    }
    
    struct Cheat {
        let name: String
        let code: String
    }

    static func parseCheatFile(_ text: String) -> [Cheat] {
        let pattern = #"\[(.*?)\]\s*([\s\S]*?)(?=\n\s*\[|$)"#

        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        return matches.compactMap { match in
            guard match.numberOfRanges == 3 else { return nil }

            let title = nsText.substring(with: match.range(at: 1))

            let rawCode = nsText.substring(with: match.range(at: 2))
            let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)

            return Cheat(name: title, code: code)
        }
    }

    /// User-supplied key file Citra reads from sysdata. A copy left by an older build counts.
    static var hasAesKeys: Bool {
        FileManager.default.fileExists(atPath: R.Path.ThreeDSSystemData.appendingPathComponent("aes_keys.txt"))
    }

    /// Header-only. `.3dsx` and anything that is not an NCCH, NCSD, or CIA is reported as not encrypted.
    static func isEncryptedROM(at url: URL) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        if url.pathExtension.lowercased() == "cia" {
            return isEncryptedCIA(handle)
        }
        return ncchIsEncrypted(handle, at: 0)
    }

    /// `no_crypto` (NCCH flags bit 2) clear means ExHeader/ExeFS/RomFS are still ciphertext.
    private static func ncchIsEncrypted(_ handle: FileHandle, at offset: UInt64) -> Bool {
        guard let header = read(handle, at: offset, count: 0x200), header.count == 0x200 else { return false }
        let magic = header.subdata(in: 0x100..<0x104)
        if magic == Data("NCSD".utf8) {
            // Only the file start is an NCSD. Partition 0 holds the game NCCH.
            guard offset == 0 else { return false }
            let partition = UInt64(u32LE(header, 0x120)) * 0x200
            guard partition != 0 else { return false }
            return ncchIsEncrypted(handle, at: partition)
        }
        guard magic == Data("NCCH".utf8) else { return false }
        return (header[0x18F] & 0x04) == 0
    }

    /// CIA content encryption (TMD type bit 0) or an inner NCCH that is still encrypted.
    private static func isEncryptedCIA(_ handle: FileHandle) -> Bool {
        guard let header = read(handle, at: 0, count: 0x2020), header.count == 0x2020 else { return false }
        let headerSize = UInt64(u32LE(header, 0x00))
        let certSize = UInt64(u32LE(header, 0x08))
        let ticketSize = UInt64(u32LE(header, 0x0C))
        let tmdSize = UInt64(u32LE(header, 0x10))
        guard headerSize >= 0x20, tmdSize > 0 else { return false }

        let certificateOffset = align64(headerSize)
        let ticketOffset = align64(certificateOffset + certSize)
        let tmdOffset = align64(ticketOffset + ticketSize)
        guard let signature = read(handle, at: tmdOffset, count: 4), signature.count == 4 else { return false }
        let signatureSize: UInt64
        switch u32BE(signature, 0) {
        case 0x10000, 0x10003: signatureSize = 0x200
        case 0x10001, 0x10004: signatureSize = 0x100
        case 0x10002, 0x10005: signatureSize = 0x3C
        default: return false
        }
        let body = align64(4 + signatureSize)
        guard let countData = read(handle, at: tmdOffset + body + 0x9E, count: 2), countData.count == 2 else { return false }
        let contentCount = Int(u16BE(countData, 0))
        // Retail titles have a handful of contents. A huge count is a bad header, not an encrypted ROM.
        guard contentCount > 0, contentCount <= 256 else { return false }
        let chunksOffset = tmdOffset + body + 0x9C4
        let chunksSize = contentCount * 0x30
        guard chunksOffset + UInt64(chunksSize) <= tmdOffset + tmdSize,
              let chunks = read(handle, at: chunksOffset, count: chunksSize),
              chunks.count == chunksSize else { return false }

        var contentOffset = align64(tmdOffset + tmdSize)
        for index in 0..<contentCount {
            let base = index * 0x30
            let contentIndex = Int(u16BE(chunks, base + 4))
            let type = u16BE(chunks, base + 6)
            let size = u64BE(chunks, base + 8)
            if ciaContains(header, contentIndex), (type & 1) != 0 {
                return true
            }
            // Absent slots contribute no bytes, matching CIAContainer::GetContentOffset.
            let slotSize = ciaContains(header, index) ? size : 0
            if slotSize > 0, ncchIsEncrypted(handle, at: contentOffset) {
                return true
            }
            contentOffset += slotSize
        }
        return false
    }

    /// CIA `content_present`: index 0 is the high bit of the first byte.
    private static func ciaContains(_ header: Data, _ index: Int) -> Bool {
        guard index >= 0, index < 0x10000 else { return false }
        let byte = header[0x20 + (index >> 3)]
        return (byte & UInt8(0x80 >> (index & 7))) != 0
    }

    private static func align64(_ value: UInt64) -> UInt64 {
        (value + 0x3F) & ~0x3F
    }

    private static func read(_ handle: FileHandle, at offset: UInt64, count: Int) -> Data? {
        guard count > 0 else { return Data() }
        do {
            try handle.seek(toOffset: offset)
            return try handle.read(upToCount: count)
        } catch {
            return nil
        }
    }

    private static func u16BE(_ data: Data, _ offset: Int) -> UInt16 {
        (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private static func u32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func u32BE(_ data: Data, _ offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func u64BE(_ data: Data, _ offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for byte in data[offset..<(offset + 8)] {
            value = (value << 8) | UInt64(byte)
        }
        return value
    }
}

class ThreeDSEmulatorBridge : EmulatorBridgeBase {
    
    static let shared = ThreeDSEmulatorBridge()
#if !SIMULATOR
    private let citraCore = CitraCore.shared()
#endif
    private var enableControl = false
    
    private var thumbstickPosition: CGPoint = .zero
    private var cstickPosition: CGPoint = .zero
    private var touchPosition: CGPoint = .zero
    
    private weak var metalView: MTKView? = nil
    
    private var topRect: CGRect = .zero
    private var bottomRect: CGRect = .zero
    
    private var isAdvancedMode: Bool = false
    
    func setSimBlowing(start: Bool) {
#if !SIMULATOR
        citraCore.setSimBlowing(start: start)
#endif
    }

    /// 0=portrait, 1=landscapeLeft, 2=upside down, 3=landscapeRight.
    func setMotionRotation(_ rotation: Int) {
#if !SIMULATOR
        citraCore.setMotionRotation(rotation)
#endif
    }

    func applyCurrentMotionRotation(
        _ orientation: UIInterfaceOrientation = UIDevice.currentOrientation
    ) {
#if !SIMULATOR
        switch orientation {
        case .portrait:
            citraCore.setMotionRotation(0)
        case .landscapeLeft:
            citraCore.setMotionRotation(1)
        case .portraitUpsideDown:
            citraCore.setMotionRotation(2)
        case .landscapeRight:
            citraCore.setMotionRotation(3)
        default:
            citraCore.setMotionRotation(3)
        }
#endif
    }

    func setFrameLimit(_ limit: UInt16) {
#if !SIMULATOR
        citraCore.setFrameLimit(limit)
#endif
    }
    
    func jumpToHome() {
#if !SIMULATOR
        citraCore.jumpToHome()
#endif
    }
    
    func loadAmiibo(path: String) {
#if !SIMULATOR
        citraCore.loadAmiibo(path: path)
#endif
    }
    
    func isAmiiboSearching() -> Bool {
#if !SIMULATOR
        return citraCore.isSearchingAmiibo()
#else
        return false
#endif
    }
    
    func setResolution(resolution: GameOption.Resolution) {
        updateConfig(["ManicEMU.resolutionFactor": resolution.rawValue])
    }
    
#if !SIMULATOR
    func openKeyboardAction(_ action: ((CitraKeyboardConfig) -> Void)? = nil) {
        CitraCore.openKeyboardAction = { config in
            guard let action else { return }
            if Thread.isMainThread {
                action(config)
            } else {
                DispatchQueue.main.async {
                    action(config)
                }
            }
        }
    }
#endif
    
    func start(withGameURL gameURL: URL,
               metalView: MTKView,
               metalViewFrame: CGRect,
               topRect: CGRect,
               bottomRect: CGRect,
               mute: Bool,
               resolution: GameOption.Resolution = .one,
               jit: Bool = false,
               accurateShaders: Bool = false,
               language: Int = -1,
               renderRightEye: Bool = false,
               advancedMode: Bool = Settings.defalut.threeDSAdvancedSettingMode) {
#if !SIMULATOR
        self.topRect = topRect
        self.bottomRect = bottomRect
        self.gameURL = gameURL
        self.isAdvancedMode = advancedMode
        var appendConfig: [String: Any] = ["ManicEMU.audioMuted": mute, "ManicEMU.resolutionFactor": resolution.rawValue < GameOption.Resolution.one.rawValue ? 1 : resolution.rawValue]
        if jit {
            appendConfig["ManicEMU.cpuJIT"] = true
            switch Settings.defalut.threeDSMode {
            case .compatibility:
                appendConfig["ManicEMU.cpuClockPercentage"] = 60
            case .performance:
                appendConfig["ManicEMU.cpuClockPercentage"] = 50
            case .quality:
                appendConfig["ManicEMU.cpuClockPercentage"] = 75
            }
        } else {
            appendConfig["ManicEMU.cpuJIT"] = false
            switch Settings.defalut.threeDSMode {
            case .performance:
                appendConfig["ManicEMU.cpuClockPercentage"] = 15
            case .compatibility:
                appendConfig["ManicEMU.cpuClockPercentage"] = 20
            case .quality:
                appendConfig["ManicEMU.cpuClockPercentage"] = 25
            }
        }
        if accurateShaders {
            appendConfig["ManicEMU.useShadersAccurateMul"] = true
        } else {
            appendConfig["ManicEMU.useShadersAccurateMul"] = false
        }
        if renderRightEye {
            appendConfig["ManicEMU.disableRightEyeRender"] = false
        } else {
            appendConfig["ManicEMU.disableRightEyeRender"] = true
        }
        appendConfig["ManicEMU.regionValue"] = language
#if DEBUG
        appendConfig["ManicEMU.logLevel"] = 0
#else
        appendConfig["ManicEMU.logLevel"] = 6
#endif
        updateConfig(appendConfig)
        citraCore.allocateVulkanLibrary()
        self.metalView = metalView
        let metalLayer = metalView.layer as! CAMetalLayer
        citraCore.allocateMetalLayer(for: metalLayer, with: metalViewFrame.size, isSecondary: false)
        applyCurrentMotionRotation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Thread.setThreadPriority(1.0)
            Thread.detachNewThread {
                self.citraCore.insertCartridgeAndBoot(with: gameURL, advancedMode: advancedMode, jitSupport: LibretroCore.jitAvailable())
            }
        }
        DispatchQueue.main.asyncAfter(delay: 3.25) {
            self.citraCore.orientationChange(with: UIDevice.currentOrientation, using: metalView)
            self.enableControl = true
        }
#endif
    }
    
    func destory() {
#if !SIMULATOR
        citraCore.deallocateVulkanLibrary()
        citraCore.deallocateMetalLayers()
#endif
    }
    
    override func stop() {
#if !SIMULATOR
        citraCore.stop()
#endif
    }
    
    override func pause() {
#if !SIMULATOR
        if citraCore.stopped() {
            return
        }
        if !citraCore.isPaused() {
            citraCore.pausePlay(false)
        }
#endif
    }
    
    var isPaused: Bool {
#if !SIMULATOR
        citraCore.isPaused()
#else
        return false
#endif
    }
    
    override func resume() {
#if !SIMULATOR
        if citraCore.stopped() {
            return
        }
        if citraCore.isPaused() {
            citraCore.pausePlay(true)
        }
#endif
    }
    
    var saveStateCount: Int {
#if !SIMULATOR
        return citraCore.saveStateCount
#else
        return 0
#endif
    }
    
    func addSaveState(fileUrl: URL, slot: UInt32) {
#if !SIMULATOR
        if let path = citraCore.saveStatePathForRunningGame(slot: slot) {
            try? FileManager.safeCopyItem(at: fileUrl, to: URL(fileURLWithPath: path), shouldReplace: true)
        }
#endif
    }
    
    func saveState() -> (isSuccess: Bool, path: String) {
#if !SIMULATOR
        let state = citraCore.saveState()
        return (state.isSuccess, state.path)
#else
        return (false, "")
#endif
    }
    
    @discardableResult func loadState(_ slot: UInt32? = nil) -> Bool {
#if !SIMULATOR
        if let slot {
            return citraCore.loadState(slot)
        } else {
            return citraCore.loadState()
        }
#else
        return false
#endif
    }
    
    func enableVolume() {
        updateConfig(["ManicEMU.audioMuted": false])
    }
    
    func disableVolume() {
        updateConfig(["ManicEMU.audioMuted": true])
    }
    
#if !SIMULATOR
    func gameInputToCoreInput(gameInput: ThreeDSGameInput) -> CitraVirtualControllerButtonType {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .l2 { return .triggerZL }
        else if gameInput == .r2 { return .triggerZR }
        else if gameInput == .up { return .directionalPadUp }
        else if gameInput == .down { return .directionalPadDown }
        else if gameInput == .left { return .directionalPadLeft }
        else if gameInput == .right { return .directionalPadRight }
        else if gameInput == .l1 { return .triggerL }
        else if gameInput == .r1 { return .triggerR }
        else { return .debug }
    }
#endif
    
    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
#if !SIMULATOR
        guard enableControl else { return }
        /**
         摇杆坐标
         0,1
         
   -1,0  0,0  1,0
         
         0,-1
         */
        if input == ThreeDSGameInput.leftThumbstickUp || input == ThreeDSGameInput.leftThumbstickDown {

            thumbstickPosition.y = input == ThreeDSGameInput.leftThumbstickUp ? value : -value
            citraCore.thumbstickMoved(.circlePad, x: Float(thumbstickPosition.x), y: Float(thumbstickPosition.y))
            
        } else if input == ThreeDSGameInput.leftThumbstickLeft || input == ThreeDSGameInput.leftThumbstickRight {
            
            thumbstickPosition.x = input == ThreeDSGameInput.leftThumbstickRight ? value : -value
            citraCore.thumbstickMoved(.circlePad, x: Float(thumbstickPosition.x), y: Float(thumbstickPosition.y))
            
        } else if input == ThreeDSGameInput.rightThumbstickUp || input == ThreeDSGameInput.rightThumbstickDown {
            
            cstickPosition.y = input == ThreeDSGameInput.rightThumbstickUp ? value : -value
            citraCore.thumbstickMoved(.cStick, x: Float(cstickPosition.x), y: Float(cstickPosition.y))
            
        } else if input == ThreeDSGameInput.rightThumbstickLeft || input == ThreeDSGameInput.rightThumbstickRight {
            
            cstickPosition.x = input == ThreeDSGameInput.rightThumbstickRight ? value : -value
            citraCore.thumbstickMoved(.cStick, x: Float(cstickPosition.x), y: Float(cstickPosition.y))
            
        } else if input == ThreeDSGameInput.touchScreenX || input == ThreeDSGameInput.touchScreenY {
            if input == ThreeDSGameInput.touchScreenX {
                touchPosition.x = value * bottomRect.width + bottomRect.minX
            }
            if input == ThreeDSGameInput.touchScreenY {
                touchPosition.y = value * bottomRect.height + bottomRect.minY
            }
            if touchPosition.x != 0 && touchPosition.y != 0 {
                citraCore.touchBegan(at: touchPosition)
                citraCore.touchMoved(at: touchPosition)
            }
            
        } else {
            if let gameInput = ThreeDSGameInput(rawValue: input) {
                let type = gameInputToCoreInput(gameInput: gameInput)
                if type != .debug {
                    citraCore.virtualControllerButtonDown(type)
                }
            }
            
        }
#endif
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
#if !SIMULATOR
        guard enableControl else { return }
        if input == ThreeDSGameInput.leftThumbstickUp || input == ThreeDSGameInput.leftThumbstickDown {
            thumbstickPosition.y = 0
            citraCore.thumbstickMoved(.circlePad, x: Float(thumbstickPosition.x), y: Float(thumbstickPosition.y))
        } else if input == ThreeDSGameInput.leftThumbstickLeft || input == ThreeDSGameInput.leftThumbstickRight {
            thumbstickPosition.x = 0
            citraCore.thumbstickMoved(.circlePad, x: Float(thumbstickPosition.x), y: Float(thumbstickPosition.y))
        } else if input == ThreeDSGameInput.rightThumbstickUp || input == ThreeDSGameInput.rightThumbstickDown {
            cstickPosition.y = 0
            citraCore.thumbstickMoved(.cStick, x: Float(cstickPosition.x), y: Float(cstickPosition.y))
        } else if input == ThreeDSGameInput.rightThumbstickLeft || input == ThreeDSGameInput.rightThumbstickRight {
            cstickPosition.x = 0
            citraCore.thumbstickMoved(.cStick, x: Float(cstickPosition.x), y: Float(cstickPosition.y))
        } else if input == ThreeDSGameInput.touchScreenX || input == ThreeDSGameInput.touchScreenY {
            touchPosition = .zero
            citraCore.touchEnded()
            
        }  else {
            if let gameInput = ThreeDSGameInput(rawValue: input) {
                let type = gameInputToCoreInput(gameInput: gameInput)
                if type != .debug {
                    citraCore.virtualControllerButtonUp(type)
                }
            }
        }
#endif
    }
    
    func updateViews(topRect: CGRect, bottomRect: CGRect, isAirPlay: Bool = false) {
#if !SIMULATOR
        self.topRect = topRect
        self.bottomRect = bottomRect
        updateConfig(buildLayoutConfig())
        DispatchQueue.main.asyncAfter(delay: 0.75) {
            if let metalView = self.metalView {
                self.citraCore.orientationChange(with: isAirPlay ? .landscapeLeft : UIDevice.currentOrientation, using: metalView)
            }
        }
#endif
    }
    
    func reload() {
#if !SIMULATOR
        citraCore.reset()
#endif
    }

    func updateConfig(_ updates: [String: Any] = [:]) {
#if !SIMULATOR
        var defaultConfigs: [String: Any]
        switch Settings.defalut.threeDSMode {
        case .performance:
            if updates.count > 0 {
                updates.forEach { key, value in
                    PerformanceConfigs[key] = value
                }
            }
            defaultConfigs = PerformanceConfigs
            
        case .compatibility:
            if updates.count > 0 {
                updates.forEach { key, value in
                    CompatibilityConfigs[key] = value
                }
            }
            defaultConfigs = CompatibilityConfigs
            
        case .quality:
            if updates.count > 0 {
                updates.forEach { key, value in
                    QualityConfigs[key] = value
                }
            }
            defaultConfigs = QualityConfigs
        }
        
        defaultConfigs.forEach { key, value in
            UserDefaults.standard.set(value, forKey: "\(key)")
        }
        UserDefaults.standard.synchronize()
        citraCore.updateSettings(advancedMode: isAdvancedMode)
#endif
    }
    
    private func buildLayoutConfig() -> [String: Any] {
        let layout: [String: Any]
        
        layout = ["ManicEMU.customTopLeft" : topRect.minX,
                  "ManicEMU.customTopTop" : topRect.minY,
                  "ManicEMU.customTopRight" : topRect.minX + topRect.width,
                 "ManicEMU.customTopBottom" : topRect.minY + topRect.height,
                  "ManicEMU.customBottomLeft" : bottomRect.minX,
                  "ManicEMU.customBottomTop" : bottomRect.minY,
                  "ManicEMU.customBottomRight" : bottomRect.minX + bottomRect.width,
                  "ManicEMU.customBottomBottom" : bottomRect.minY + bottomRect.height]
        return layout
    }
    
    
    private lazy var PerformanceConfigs: [String: Any] = {
        [
            "ManicEMU.cpuClockPercentage" : 15,
            "ManicEMU.new3DS" : false,
            "ManicEMU.lleApplets" : false,
            "ManicEMU.regionValue" : -1,
            "ManicEMU.layoutOption" : 0,
            "ManicEMU.customLayout" : true,
            "ManicEMU.spirvShaderGeneration" : true,
            "ManicEMU.useAsyncShaderCompilation" : false,
            "ManicEMU.useAsyncPresentation" : true,
            "ManicEMU.useHardwareShaders" : true,
            "ManicEMU.useDiskShaderCache" : true,
            "ManicEMU.useShadersAccurateMul" : false,
            "ManicEMU.useNewVSync" : true,
            "ManicEMU.useShaderJIT" : false,
            "ManicEMU.resolutionFactor" : 1,
            "ManicEMU.textureFilter" : 0,
            "ManicEMU.textureSampling" : 0,
            "ManicEMU.render3D" : 0,
            "ManicEMU.factor3D" : 0,
            "ManicEMU.monoRender" : 0,
            "ManicEMU.preloadTextures" : false,
            "ManicEMU.redEyeRender" : false,
            "ManicEMU.audioMuted" : false,
            "ManicEMU.audioEmulation" : 0,
            "ManicEMU.audioStretching" : false,
            "ManicEMU.realtimeAudio": true,
            "ManicEMU.outputType" : 3,
            "ManicEMU.inputType" : 4,
            "ManicEMU.webAPIURL" : "http://88.198.47.47:5000"
        ] + buildLayoutConfig()
    }()
    
    private lazy var CompatibilityConfigs: [String: Any] = {
        [
            "ManicEMU.cpuClockPercentage" : 20,
            "ManicEMU.new3DS" : true,
            "ManicEMU.lleApplets" : false,
            "ManicEMU.regionValue" : -1,
            "ManicEMU.layoutOption" : 0,
            "ManicEMU.customLayout" : true,
            "ManicEMU.customTopLeft" : 0,
            "ManicEMU.customTopTop" : 0,
            "ManicEMU.spirvShaderGeneration" : true,
            "ManicEMU.useAsyncShaderCompilation" : false,
            "ManicEMU.useAsyncPresentation" : true,
            "ManicEMU.useHardwareShaders" : true,
            "ManicEMU.useDiskShaderCache" : true,
            "ManicEMU.useShadersAccurateMul" : false,
            "ManicEMU.useNewVSync" : true,
            "ManicEMU.useShaderJIT" : false,
            "ManicEMU.resolutionFactor" : 1,
            "ManicEMU.textureFilter" : 0,
            "ManicEMU.textureSampling" : 0,
            "ManicEMU.render3D" : 0,
            "ManicEMU.factor3D" : 0,
            "ManicEMU.monoRender" : 0,
            "ManicEMU.preloadTextures" : false,
            "ManicEMU.redEyeRender" : false,
            "ManicEMU.audioMuted" : false,
            "ManicEMU.audioEmulation" : 0, //"HLE" : 0, "LLE" : 1, "LLE (Multithreaded)" : 2
            "ManicEMU.audioStretching" : false,
            "ManicEMU.realtimeAudio": true,
            "ManicEMU.outputType" : 3, // Auto = 0, Null = 1, Cubeb = 2, OpenAL = 3, SDL3 = 4
            "ManicEMU.inputType" : 4, // Auto = 0, Null = 1, Static = 2, Cubeb = 3, OpenAL = 4
            "ManicEMU.webAPIURL" : "http://88.198.47.47:5000"
        ] + buildLayoutConfig()
    }()
    
    private lazy var QualityConfigs: [String: Any] = {
        [
            "ManicEMU.cpuClockPercentage" : 25,
            "ManicEMU.new3DS" : true,
            "ManicEMU.lleApplets" : false,
            "ManicEMU.regionValue" : -1,
            "ManicEMU.layoutOption" : 0,
            "ManicEMU.customLayout" : true,
            "ManicEMU.customTopLeft" : 0,
            "ManicEMU.customTopTop" : 0,
            "ManicEMU.spirvShaderGeneration" : true,
            "ManicEMU.useAsyncShaderCompilation" : false,
            "ManicEMU.useAsyncPresentation" : true,
            "ManicEMU.useHardwareShaders" : true,
            "ManicEMU.useDiskShaderCache" : true,
            "ManicEMU.useShadersAccurateMul" : false,
            "ManicEMU.useNewVSync" : true,
            "ManicEMU.useShaderJIT" : false,
            "ManicEMU.resolutionFactor" : 1,
            "ManicEMU.textureFilter" : 0,
            "ManicEMU.textureSampling" : 0,
            "ManicEMU.render3D" : 0,
            "ManicEMU.factor3D" : 0,
            "ManicEMU.monoRender" : 0,
            "ManicEMU.preloadTextures" : false,
            "ManicEMU.redEyeRender" : false,
            "ManicEMU.audioMuted" : false,
            "ManicEMU.audioEmulation" : 0,
            "ManicEMU.audioStretching" : false,
            "ManicEMU.realtimeAudio": true,
            "ManicEMU.outputType" : 3,
            "ManicEMU.inputType" : 4,
            "ManicEMU.webAPIURL" : "http://88.198.47.47:5000"
        ] + buildLayoutConfig()
    }()
}

class AzaharEmulatorBridge : EmulatorBridgeBase {
    
    static let shared = AzaharEmulatorBridge()
    
    private var thumbstickPosition: CGPoint = .zero
    private var cstickPosition: CGPoint = .zero
    private var touchPointX: CGFloat? = nil
    private var touchPointY: CGFloat? = nil
    var touchInputFrame: CGRect = .zero
    
    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        /**
         摇杆坐标
         0,1
         
   -1,0  0,0  1,0
         
         0,-1
         */
        if input == ThreeDSGameInput.leftThumbstickUp || input == ThreeDSGameInput.leftThumbstickDown {
            
            thumbstickPosition.y = input == ThreeDSGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
            
            
        } else if input == ThreeDSGameInput.leftThumbstickLeft || input == ThreeDSGameInput.leftThumbstickRight {
            
            thumbstickPosition.x = input == ThreeDSGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
            
        } else if input == ThreeDSGameInput.rightThumbstickUp || input == ThreeDSGameInput.rightThumbstickDown {
            
            cstickPosition.y = input == ThreeDSGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: cstickPosition.x, y: cstickPosition.y, playerIndex: UInt32(playerIndex))
            
        } else if input == ThreeDSGameInput.rightThumbstickLeft || input == ThreeDSGameInput.rightThumbstickRight {
            
            cstickPosition.x = input == ThreeDSGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: cstickPosition.x, y: cstickPosition.y, playerIndex: UInt32(playerIndex))
            
        } else if input == ThreeDSGameInput.touchScreenX || input == ThreeDSGameInput.touchScreenY {
            if input == ThreeDSGameInput.touchScreenX {
                touchPointX = value
            } else if input == ThreeDSGameInput.touchScreenY {
                touchPointY = value
            }
            if let x = touchPointX, let y = touchPointY {
                let touchPoint = CGPoint(x: touchInputFrame.minX + touchInputFrame.width*x, y: touchInputFrame.minY + touchInputFrame.height*y)
                
#if DEBUG
                Log.debug("🎮 \(objectInfo(self))  触摸屏幕:\(touchPoint)")
#endif
                LibretroCore.sharedInstance().sendTouchEventX(touchPoint.x, y: touchPoint.y)
                touchPointX = nil
                touchPointY = nil
            }
        } else if let gameInput = ThreeDSGameInput(rawValue: input),
                  let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
                Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: ThreeDSGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else { return nil }
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == ThreeDSGameInput.leftThumbstickUp || input == ThreeDSGameInput.leftThumbstickDown {
            thumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ThreeDSGameInput.leftThumbstickLeft || input == ThreeDSGameInput.leftThumbstickRight {
            thumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ThreeDSGameInput.rightThumbstickUp || input == ThreeDSGameInput.rightThumbstickDown {
            cstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: cstickPosition.x, y: cstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ThreeDSGameInput.rightThumbstickLeft || input == ThreeDSGameInput.rightThumbstickRight {
            cstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: cstickPosition.x, y: cstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ThreeDSGameInput.touchScreenX || input == ThreeDSGameInput.touchScreenY {
            if input == ThreeDSGameInput.touchScreenX {
                touchPointX = nil
            } else if input == ThreeDSGameInput.touchScreenY {
                touchPointY = nil
            }
            if touchPointX == nil, touchPointY == nil {
                LibretroCore.sharedInstance().releaseTouchEvent()
            }
        } else if let gameInput = ThreeDSGameInput(rawValue: input),
                  let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
