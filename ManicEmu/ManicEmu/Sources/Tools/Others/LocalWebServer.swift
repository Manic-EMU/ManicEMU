//
//  LocalWebServer.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import GCDWebServer

class LocalWebServer {
    enum ServerType {
        case JGenesis, RomPatcher, J2meJS, freej2meWeb, Ruffle
    }
    
    private var server: GCDWebServer?
    var port: UInt = 8080
    private var files: [String: String] = [:] // fileId -> filePath
    
    func start(serverType: ServerType) throws {
        server = GCDWebServer()
        
        let resourcePath: String
        switch serverType {
        case .JGenesis:
            resourcePath = R.Path.JGenesis
            
            // 首先添加通用的目录处理器（优先级最低）
            server?.addGETHandler(forBasePath: "/",
                                  directoryPath: resourcePath,
                                  indexFilename: nil,
                                  cacheAge: 0,
                                  allowRangeRequests: true)
            
            // 然后添加特定文件类型的处理器（优先级更高）
            // HTML 文件处理器
            server?.addHandler(forMethod: "GET", pathRegex: "/.*\\.html", request: GCDWebServerRequest.self) { request in
                let response = GCDWebServerDataResponse.init(htmlTemplate: resourcePath.appendingPathComponent(request.path), variables: [:])
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                return response
            }
            
            // WASM 文件处理器，设置正确的 MIME type（优先级最高）
            server?.addHandler(forMethod: "GET", pathRegex: "/.*\\.wasm", request: GCDWebServerRequest.self) { request in
                let wasmPath = resourcePath.appendingPathComponent(request.path)
                guard FileManager.default.fileExists(atPath: wasmPath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                let response = GCDWebServerFileResponse(file: wasmPath)
                // 直接设置 contentType 属性，而不是通过 header
                response?.contentType = "application/wasm"
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                return response
            }
            
            // ROM 文件流式处理器
            server?.addHandler(forMethod: "GET", pathRegex: "/file/.*", request: GCDWebServerRequest.self) { [weak self] request in
                guard let self else { return nil }
                let fileId = request.path.lastPathComponent
                guard let filePath = self.files[fileId] else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                
                guard FileManager.default.fileExists(atPath: filePath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                
                let response = GCDWebServerFileResponse(file: filePath)
                response?.cacheControlMaxAge = 0
                response?.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
                response?.setValue("no-cache", forAdditionalHeader: "Pragma")
                response?.setValue("0", forAdditionalHeader: "Expires")
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                response?.contentType = "application/octet-stream"
                return response
            }
            
        case .RomPatcher:
            port = 8083
            resourcePath = R.Path.RomPatcher
            
            // 首先添加通用的目录处理器（优先级最低）
            server?.addGETHandler(forBasePath: "/",
                                  directoryPath: resourcePath,
                                  indexFilename: nil,
                                  cacheAge: 0,
                                  allowRangeRequests: true)
        case .J2meJS:
            port = 8081
            resourcePath = R.Path.J2meJS

            // Add generic directory handler
            server?.addGETHandler(forBasePath: "/",
                                  directoryPath: resourcePath,
                                  indexFilename: nil,
                                  cacheAge: 0,
                                  allowRangeRequests: true)

            // JAR file handler for game loading
            server?.addHandler(forMethod: "GET", pathRegex: "/file/.*", request: GCDWebServerRequest.self) { [weak self] request in
                guard let self else { return nil }
                let fileId = request.path.lastPathComponent
                guard let filePath = self.files[fileId] else {
                    return GCDWebServerResponse(statusCode: 404)
                }

                guard FileManager.default.fileExists(atPath: filePath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }

                let response = GCDWebServerFileResponse(file: filePath)
                response?.cacheControlMaxAge = 0
                response?.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
                response?.contentType = "application/java-archive"
                return response
            }

        case .freej2meWeb:
            port = 8082
            resourcePath = R.Path.Freej2meWeb

            // Add generic directory handler
            server?.addGETHandler(forBasePath: "/",
                                  directoryPath: resourcePath,
                                  indexFilename: nil,
                                  cacheAge: 3600,
                                  allowRangeRequests: true)

            // WASM file handler with correct MIME type
            server?.addHandler(forMethod: "GET", pathRegex: "/.*\\.wasm", request: GCDWebServerRequest.self) { request in
                let wasmPath = resourcePath.appendingPathComponent(request.path)
                guard FileManager.default.fileExists(atPath: wasmPath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                let response = GCDWebServerFileResponse(file: wasmPath)
                response?.contentType = "application/wasm"
                return response
            }

            // JAR file handler for game loading
            server?.addHandler(forMethod: "GET", pathRegex: "/file/.*", request: GCDWebServerRequest.self) { [weak self] request in
                guard let self else { return nil }
                let fileId = request.path.lastPathComponent
                guard let filePath = self.files[fileId] else {
                    return GCDWebServerResponse(statusCode: 404)
                }

                guard FileManager.default.fileExists(atPath: filePath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }

                let response = GCDWebServerFileResponse(file: filePath)
                response?.cacheControlMaxAge = 0
                response?.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
                response?.contentType = "application/java-archive"
                return response
            }

        case .Ruffle:
            port = 8084
            resourcePath = R.Path.Ruffle

            server?.addGETHandler(forBasePath: "/",
                                  directoryPath: resourcePath,
                                  indexFilename: nil,
                                  cacheAge: 0,
                                  allowRangeRequests: true)

            server?.addHandler(forMethod: "GET", pathRegex: "/.*\\.html", request: GCDWebServerRequest.self) { request in
                let htmlPath = resourcePath.appendingPathComponent(request.path)
                guard FileManager.default.fileExists(atPath: htmlPath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                let response = GCDWebServerFileResponse(file: htmlPath)
                response?.contentType = "text/html; charset=utf-8"
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                return response
            }

            server?.addHandler(forMethod: "GET", pathRegex: "/.*\\.wasm", request: GCDWebServerRequest.self) { request in
                let wasmPath = resourcePath.appendingPathComponent(request.path)
                guard FileManager.default.fileExists(atPath: wasmPath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                let response = GCDWebServerFileResponse(file: wasmPath)
                response?.contentType = "application/wasm"
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                return response
            }

            server?.addHandler(forMethod: "GET", pathRegex: "/.*\\.js", request: GCDWebServerRequest.self) { request in
                let jsPath = resourcePath.appendingPathComponent(request.path)
                guard FileManager.default.fileExists(atPath: jsPath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }
                let response = GCDWebServerFileResponse(file: jsPath)
                response?.contentType = "text/javascript"
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                return response
            }

            server?.addHandler(forMethod: "GET", pathRegex: "/file/.*", request: GCDWebServerRequest.self) { [weak self] request in
                guard let self else { return nil }
                let fileId = request.path.lastPathComponent
                guard let filePath = self.files[fileId] else {
                    return GCDWebServerResponse(statusCode: 404)
                }

                guard FileManager.default.fileExists(atPath: filePath) else {
                    return GCDWebServerResponse(statusCode: 404)
                }

                let response = GCDWebServerFileResponse(file: filePath)
                response?.cacheControlMaxAge = 0
                response?.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
                response?.setValue("no-cache", forAdditionalHeader: "Pragma")
                response?.setValue("0", forAdditionalHeader: "Expires")
                response?.setValue("same-origin", forAdditionalHeader: "Cross-Origin-Opener-Policy")
                response?.setValue("require-corp", forAdditionalHeader: "Cross-Origin-Embedder-Policy")
                response?.contentType = "application/x-shockwave-flash"
                return response
            }
        }

        try server?.start(options: [
            GCDWebServerOption_Port: port,
            GCDWebServerOption_BindToLocalhost: true
        ])
        
        Log.debug("✅ 服务器启动: http://127.0.0.1:\(port)")
    }
    
    func stop() {
        DispatchQueue.global(qos: .utility).async {
            self.server?.stop()
        }
    }
    
    func getURL() -> URL? {
        return URL(string: "http://127.0.0.1:\(port)/index.html")
    }

    /// Same host as `getURL()` so WKWebView fetch stays same-origin (`localhost` ≠ `127.0.0.1`).
    func fileURL(for fileId: String) -> String {
        "http://127.0.0.1:\(port)/file/\(fileId)"
    }
    
    /// Registers a ROM file and returns a unique file ID.
    func registerFile(filePath: String) -> String {
        let fileId = "\(filePath.lastPathComponent.sha256())"
        files[fileId] = filePath
        return fileId
    }
}
