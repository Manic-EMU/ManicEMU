//
//  ImportError.swift
//  ManicEmu
//
//  Created by Max on 2025/1/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

enum ImportError: Error, LocalizedError {
    case fileExist(fileName: String)
    case badCopy(fileName: String)
    case badExtension(fileName: String)
    case noPermission(fileUrl: URL)
    case unableToHash(fileName: String)
    case writeDatabase(fileName: String)
    case badFile(fileName: String)
    case decryptFailed(fileName: String)
    case ciaGameNotExist(fileName: String)
    case missingFile(errorFileName:String, missingFileName: String)
    case skinIdentifierConflict(identifier: String)
    case badMultiFile(fileName: String)
    
    case saveNoMatchGames(gameSaveUrl: URL)
    case saveAlreadyExist(gameSaveUrl: URL, game: Game)
    case saveMatchToMuch(gameSaveUrl: URL, games: [Game])
    
    case skinBadFile(fileName: String)
    
    case pasteNoMatchContent
    
    case downloadExist(fileName: String)
    case downloadError(filenames: String)
    
    //smb
    case lanServiceInitFailed(serviceName: String)
    case smbLoginFailed(reason: String)
    case smbListFilesFailed(reason: String)
    
    var localizedDescription: String? {
        return errorDescription
    }
    
    var errorDescription: String? {
        switch self {
        case .fileExist(let string):
            R.string.localizable.filesImporterErrorFileExist(string)
        case .badCopy(let string):
            R.string.localizable.filesImporterErrorBadCopy(string)
        case .badExtension(let string):
            R.string.localizable.filesImporterErrorBadExtension(string)
        case .noPermission(let url):
            R.string.localizable.filesImporterErrorNoPermission(url.path)
        case .unableToHash(let string):
            R.string.localizable.filesImporterErrorUnableToHash(string)
        case .writeDatabase(let string):
            R.string.localizable.filesImporterErrorWriteDatabase(string)
        case .badFile(let string):
            R.string.localizable.gameImportBadFile(string)
        case .decryptFailed(let string):
            R.string.localizable.game3DSDecryptFailed(string) + "\n\n" + R.string.localizable.game3DSEncryptedTips()
        case .ciaGameNotExist(let string):
            R.string.localizable.game3DSGameNotExist(string)
        case .saveNoMatchGames(let url):
            R.string.localizable.filesImporterErrorSaveNoMatchGames(url.lastPathComponent)
        case .saveAlreadyExist(let gameSaveUrl, _):
            R.string.localizable.filesImporterErrorSaveAlreadyExist(gameSaveUrl.lastPathComponent)
        case .saveMatchToMuch(gameSaveUrl: let gameSaveUrl, games: _):
            R.string.localizable.filesImporterErrorSaveMathToMuch(gameSaveUrl.lastPathComponent)
        case .skinBadFile(fileName: let fileName):
            R.string.localizable.filesImporterErrorSkinBadFile(fileName)
        case .pasteNoMatchContent:
            R.string.localizable.pasteImporterErrorNoMatchContent()
        case .downloadExist(fileName: let fileName):
            R.string.localizable.filesDownloadErrorFileExist(fileName)
        case .lanServiceInitFailed(serviceName: let serviceName):
            R.string.localizable.lanServiceInitFailed(serviceName)
        case .smbLoginFailed(reason: let reason):
            R.string.localizable.smbLoginFailed(reason)
        case .smbListFilesFailed(reason: let reason):
            R.string.localizable.smbListFilesFailed(reason)
        case .downloadError(filenames: let fileNames):
            R.string.localizable.importDownloadError(fileNames)
        case .missingFile(let errorFileName, let missingFileName):
            R.string.localizable.importMissingFile(errorFileName, missingFileName)
        case .skinIdentifierConflict(let identifier):
            R.string.localizable.skinIdentifierExist(identifier)
        case .badMultiFile(let string):
            R.string.localizable.filesImporterErrorBadCue(string)
        }
    }
}
