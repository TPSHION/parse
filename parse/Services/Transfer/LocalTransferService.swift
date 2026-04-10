import Foundation
import Combine
import GCDWebServer
import Darwin
import Network
import UIKit

@MainActor
final class LocalTransferService: NSObject, ObservableObject {
    @Published private(set) var files: [TransferSharedFile] = []
    @Published private(set) var isRunning = false
    @Published private(set) var serverURL: URL?
    @Published private(set) var isClientConnected = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var loopbackCheckMessage = AppLocalizer.localized("未检测")
    @Published private(set) var lanCheckMessage = AppLocalizer.localized("未检测")

    let sharedDirectoryURL: URL

    private var webServer: GCDWebServer?
    private let port: UInt = 8080
    private var permissionProbeConnection: NWConnection?
    private var permissionBrowser: NWBrowser?
    private var permissionListener: NWListener?
    private var clientHeartbeatMonitor: Timer?
    private var lastExternalClientActivityAt: Date?
    private let permissionServiceType = "_preflight_check._tcp"
    private let clientHeartbeatTimeout: TimeInterval = 15
    private let heartbeatIntervalHintSeconds: Int = 5

    private static let webResourceDirectory = "Web/Transfer"

    override init() {
        let baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        sharedDirectoryURL = baseDirectory.appendingPathComponent("TransferShared", isDirectory: true)
        super.init()
        prepareSharedDirectoryIfNeeded()
        refreshFiles()
    }

    var sharedDirectoryName: String {
        sharedDirectoryURL.lastPathComponent
    }

    var accessAddressText: String {
        accessibleURL?.absoluteString ?? AppLocalizer.localized("等待启动")
    }

    var accessibleURL: URL? {
        guard let serverURL else { return nil }

        if let localIPv4Address, var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) {
            components.host = localIPv4Address
            return components.url
        }

        return serverURL
    }

    var loopbackURL: URL? {
        URL(string: "http://127.0.0.1:\(port)/")
    }

    var shareHintText: String {
        if isRunning {
            return AppLocalizer.localized("请让其他设备连接同一 Wi-Fi，然后在浏览器里打开上方地址。")
        }
        return AppLocalizer.localized("启动后会生成局域网访问地址，电脑或其他手机浏览器可直接打开。")
    }

    var filesCountText: String {
        AppLocalizer.formatted("共享文件 %d 个", files.count)
    }

    var totalSizeText: String {
        let totalSize = files.reduce(Int64(0)) { partialResult, file in
            partialResult + file.fileSize
        }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    func refreshFiles() {
        files = Self.readSharedFiles(from: sharedDirectoryURL)
    }

    private func registerClientActivityIfNeeded(for request: GCDWebServerRequest) {
        guard isExternalClientRequest(request) else { return }
        lastExternalClientActivityAt = Date()
        refreshClientConnectionState()
    }

    private func isExternalClientRequest(_ request: GCDWebServerRequest) -> Bool {
        guard let host = normalizedHost(from: request.remoteAddressString) else {
            return false
        }

        if host == "127.0.0.1" || host == "::1" || host == "localhost" {
            return false
        }

        if let localIPv4Address, host == localIPv4Address {
            return false
        }

        return true
    }

    private func normalizedHost(from address: String?) -> String? {
        guard let address, !address.isEmpty else { return nil }

        if let components = URLComponents(string: "http://\(address)"), let host = components.host?.lowercased() {
            return host
        }

        if address.hasPrefix("["),
           let closingBracketIndex = address.firstIndex(of: "]") {
            return String(address[address.index(after: address.startIndex)..<closingBracketIndex]).lowercased()
        }

        if let colonIndex = address.lastIndex(of: ":") {
            return String(address[..<colonIndex]).lowercased()
        }

        return address.lowercased()
    }

    func startServer() {
        guard !isRunning else { return }

        prepareSharedDirectoryIfNeeded()
        requestLocalNetworkPermissionIfNeeded()

        guard let webServer = makeWebServer() else { return }

        lastErrorMessage = nil
        loopbackCheckMessage = AppLocalizer.localized("检测中...")
        lanCheckMessage = AppLocalizer.localized("检测中...")

        if webServer.start(withPort: port, bonjourName: "") {
            self.webServer = webServer
            isRunning = true
            isClientConnected = false
            lastExternalClientActivityAt = nil
            serverURL = webServer.serverURL
            startClientHeartbeatMonitor()
            refreshFiles()
            Task {
                await runConnectivityChecks()
            }
        } else {
            lastErrorMessage = AppLocalizer.localized("传输服务启动失败，请确认当前网络可用后重试。")
            loopbackCheckMessage = AppLocalizer.localized("启动失败")
            lanCheckMessage = AppLocalizer.localized("启动失败")
        }
    }

    func stopServer() {
        guard let webServer else { return }
        webServer.stop()
        self.webServer = nil
        permissionProbeConnection?.cancel()
        permissionProbeConnection = nil
        permissionBrowser?.cancel()
        permissionBrowser = nil
        permissionListener?.cancel()
        permissionListener = nil
        stopClientHeartbeatMonitor()
        lastExternalClientActivityAt = nil
        isRunning = false
        isClientConnected = false
        serverURL = nil
    }

    func toggleServer() {
        isRunning ? stopServer() : startServer()
    }

    func refreshConnectivityChecks() {
        guard isRunning else { return }
        Task {
            await runConnectivityChecks()
        }
    }

    func importFiles(from urls: [URL]) {
        guard !urls.isEmpty else { return }

        var importedCount = 0

        for sourceURL in urls {
            let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let destinationURL = Self.uniqueDestinationURL(for: sourceURL.lastPathComponent, in: sharedDirectoryURL)
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                importedCount += 1
            } catch {
                lastErrorMessage = AppLocalizer.formatted("导入文件失败：%@", error.localizedDescription)
            }
        }

        if importedCount > 0 {
            refreshFiles()
        }
    }

    func deleteFile(_ file: TransferSharedFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            refreshFiles()
        } catch {
            lastErrorMessage = AppLocalizer.formatted("删除文件失败：%@", error.localizedDescription)
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func presentError(_ message: String) {
        lastErrorMessage = message
    }

    private func makeWebServer() -> GCDWebServer? {
        guard
            let indexPath = Self.webResourcePath(named: "index", withExtension: "html"),
            let stylesPath = Self.webResourcePath(named: "styles", withExtension: "css"),
            let scriptPath = Self.webResourcePath(named: "app", withExtension: "js"),
            let mpegtsPath = Self.webResourcePath(named: "mpegts", withExtension: "js")
        else {
            lastErrorMessage = AppLocalizer.localized("网页资源未打包进应用，请检查传输页资源文件。")
            return nil
        }

        let server = GCDWebServer()
        server.delegate = self

        let sharedDirectoryURL = sharedDirectoryURL
        let deviceName = UIDevice.current.name

        server.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            return GCDWebServerFileResponse(file: indexPath)
        }

        server.addHandler(forMethod: "GET", path: "/styles.css", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            return GCDWebServerFileResponse(file: stylesPath)
        }

        server.addHandler(forMethod: "GET", path: "/app.js", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            return GCDWebServerFileResponse(file: scriptPath)
        }

        server.addHandler(forMethod: "GET", path: "/mpegts.js", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            return GCDWebServerFileResponse(file: mpegtsPath)
        }

        server.addHandler(forMethod: "GET", path: "/api/meta", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            let payload = Self.metaPayload(
                sharedDirectoryURL: sharedDirectoryURL,
                deviceName: deviceName,
                host: request.headers["Host"] ?? request.localAddressString,
                isConnected: self.isClientConnected
            )
            return Self.jsonResponse(payload)
        }

        server.addHandler(forMethod: "GET", path: "/api/ping", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            return Self.jsonResponse([
                "ok": true,
                "heartbeatIntervalSeconds": self.heartbeatIntervalHintSeconds,
                "timeoutSeconds": Int(self.clientHeartbeatTimeout),
                "connectionState": self.isClientConnected ? "connected" : "idle"
            ])
        }

        server.addHandler(forMethod: "GET", path: "/api/library/images", request: GCDWebServerRequest.self, asyncProcessBlock: { request, completion in
            self.registerClientActivityIfNeeded(for: request)
            Task {
                let payload = await TransferPhotoLibraryService.fetchLibraryPayload(for: .image)
                completion(Self.jsonResponse(payload))
            }
        })

        server.addHandler(forMethod: "GET", path: "/api/library/videos", request: GCDWebServerRequest.self, asyncProcessBlock: { request, completion in
            self.registerClientActivityIfNeeded(for: request)
            Task {
                let payload = await TransferPhotoLibraryService.fetchLibraryPayload(for: .video)
                completion(Self.jsonResponse(payload))
            }
        })

        server.addHandler(forMethod: "GET", path: "/api/results", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            return Self.jsonResponse([
                "sections": TransferResultArchiveService.allPayload()
            ])
        }

        server.addHandler(forMethod: "GET", path: "/api/results/download", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let category = request.query?["category"],
                let filename = request.query?["name"],
                let fileURL = TransferResultArchiveService.resultFileURL(categoryRawValue: category, filename: filename)
            else {
                return Self.errorResponse(statusCode: 404, message: "Result file not found")
            }

            return GCDWebServerFileResponse(file: fileURL.path, isAttachment: true)
        }

        server.addHandler(forMethod: "GET", path: "/api/results/stream", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let category = request.query?["category"],
                let filename = request.query?["name"],
                let fileURL = TransferResultArchiveService.resultFileURL(categoryRawValue: category, filename: filename)
            else {
                return Self.errorResponse(statusCode: 404, message: "Result stream not found")
            }

            if request.hasByteRange() {
                return GCDWebServerFileResponse(file: fileURL.path, byteRange: request.byteRange, isAttachment: false)
            }
            return GCDWebServerFileResponse(file: fileURL.path, isAttachment: false)
        }

        server.addHandler(forMethod: "GET", path: "/api/results/thumbnail", request: GCDWebServerRequest.self, asyncProcessBlock: { request, completion in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let category = request.query?["category"],
                let filename = request.query?["name"]
            else {
                completion(Self.errorResponse(statusCode: 404, message: "Result thumbnail not found"))
                return
            }

            Task {
                guard let thumbnail = await TransferResultArchiveService.thumbnailData(categoryRawValue: category, filename: filename) else {
                    completion(Self.errorResponse(statusCode: 404, message: "Result thumbnail not found"))
                    return
                }

                let response = GCDWebServerDataResponse(data: thumbnail.data, contentType: thumbnail.mimeType)
                response.cacheControlMaxAge = 60
                completion(response)
            }
        })

        server.addHandler(forMethod: "DELETE", path: "/api/results", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let category = request.query?["category"],
                let filename = request.query?["name"]
            else {
                return Self.errorResponse(statusCode: 400, message: "Invalid result deletion request")
            }

            do {
                try TransferResultArchiveService.deleteResult(categoryRawValue: category, filename: filename)
                return Self.jsonResponse(["success": true])
            } catch {
                return Self.errorResponse(statusCode: 500, message: error.localizedDescription)
            }
        }

        server.addHandler(forMethod: "GET", path: "/api/library/thumbnail", request: GCDWebServerRequest.self, asyncProcessBlock: { request, completion in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let identifier = request.query?["id"],
                let rawKind = request.query?["kind"],
                let kind = TransferLibraryKind(rawValue: rawKind)
            else {
                completion(Self.errorResponse(statusCode: 400, message: "Invalid asset request"))
                return
            }
            TransferPhotoLibraryService.makeThumbnailResponse(identifier: identifier, kind: kind, completion: completion)
        })

        server.addHandler(forMethod: "GET", path: "/api/library/download", request: GCDWebServerRequest.self, asyncProcessBlock: { request, completion in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let identifier = request.query?["id"],
                let rawKind = request.query?["kind"],
                let kind = TransferLibraryKind(rawValue: rawKind)
            else {
                completion(Self.errorResponse(statusCode: 400, message: "Invalid asset request"))
                return
            }
            TransferPhotoLibraryService.makeDownloadResponse(identifier: identifier, kind: kind, completion: completion)
        })

        server.addHandler(forMethod: "GET", path: "/api/files", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            let payload: [String: Any] = [
                "items": Self.webFileItems(from: sharedDirectoryURL)
            ]
            return Self.jsonResponse(payload)
        }

        server.addHandler(forMethod: "GET", path: "/api/download", request: GCDWebServerRequest.self) { request in
            self.registerClientActivityIfNeeded(for: request)
            guard
                let filename = request.query?["name"],
                let fileURL = Self.sharedFileURL(for: filename, in: sharedDirectoryURL),
                FileManager.default.fileExists(atPath: fileURL.path)
            else {
                return Self.errorResponse(statusCode: 404, message: "File not found")
            }

            if request.hasByteRange() {
                return GCDWebServerFileResponse(file: fileURL.path, byteRange: request.byteRange, isAttachment: true)
            }
            return GCDWebServerFileResponse(file: fileURL.path, isAttachment: true)
        }

        server.addHandler(forMethod: "POST", path: "/api/upload", request: GCDWebServerMultiPartFormRequest.self) { [weak self] request in
            guard let request = request as? GCDWebServerMultiPartFormRequest else {
                return Self.errorResponse(statusCode: 400, message: "Invalid upload request")
            }
            self?.registerClientActivityIfNeeded(for: request)

            let result = Self.handleUpload(request: request, sharedDirectoryURL: sharedDirectoryURL)
            if result["uploadedCount"] as? Int ?? 0 > 0 {
                Task { @MainActor [weak self] in
                    self?.refreshFiles()
                }
            }
            return Self.jsonResponse(result, statusCode: (result["failedCount"] as? Int ?? 0) > 0 ? 207 : 200)
        }

        server.addHandler(forMethod: "DELETE", path: "/api/files", request: GCDWebServerRequest.self) { [weak self] request in
            self?.registerClientActivityIfNeeded(for: request)
            guard
                let filename = request.query?["name"],
                let fileURL = Self.sharedFileURL(for: filename, in: sharedDirectoryURL),
                FileManager.default.fileExists(atPath: fileURL.path)
            else {
                return Self.errorResponse(statusCode: 404, message: "File not found")
            }

            do {
                try FileManager.default.removeItem(at: fileURL)
                Task { @MainActor [weak self] in
                    self?.refreshFiles()
                }
                return Self.jsonResponse(["success": true, "name": fileURL.lastPathComponent])
            } catch {
                return Self.errorResponse(statusCode: 500, message: error.localizedDescription)
            }
        }

        server.addHandler(forMethod: "POST", path: "/api/disconnect", request: GCDWebServerDataRequest.self) { [weak self] request in
            self?.registerClientActivityIfNeeded(for: request)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.stopServer()
            }
            return Self.jsonResponse(["success": true])
        }

        return server
    }

    private func prepareSharedDirectoryIfNeeded() {
        do {
            try Self.ensureSharedDirectoryExists(at: sharedDirectoryURL)
        } catch {
            lastErrorMessage = AppLocalizer.formatted("创建共享目录失败：%@", error.localizedDescription)
        }
    }

    private func startClientHeartbeatMonitor() {
        stopClientHeartbeatMonitor()
        clientHeartbeatMonitor = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshClientConnectionState()
            }
        }
    }

    private func stopClientHeartbeatMonitor() {
        clientHeartbeatMonitor?.invalidate()
        clientHeartbeatMonitor = nil
    }

    private func refreshClientConnectionState() {
        let isConnected: Bool
        if let lastExternalClientActivityAt {
            isConnected = isRunning && Date().timeIntervalSince(lastExternalClientActivityAt) <= clientHeartbeatTimeout
        } else {
            isConnected = false
        }

        if self.isClientConnected != isConnected {
            self.isClientConnected = isConnected
        }
    }

    private func runConnectivityChecks() async {
        loopbackCheckMessage = await checkMessage(for: loopbackURL, label: AppLocalizer.localized("本机地址"))
        lanCheckMessage = await checkMessage(for: accessibleURL, label: AppLocalizer.localized("局域网地址"))

        if loopbackCheckMessage.hasPrefix(AppLocalizer.localized("失败")),
           lanCheckMessage.hasPrefix(AppLocalizer.localized("失败")) {
            lastErrorMessage = AppLocalizer.localized("服务已标记为启动，但自检无法访问。请先尝试本机 Safari 打开 127.0.0.1 地址；若仍失败，说明服务监听本身异常。")
        }
    }

    private func requestLocalNetworkPermissionIfNeeded() {
        startBonjourPermissionProbe()

        let host = NWEndpoint.Host(localIPv4Address ?? "255.255.255.255")
        guard let port = NWEndpoint.Port(rawValue: 9) else {
            return
        }
        let parameters = NWParameters.udp

        let connection = NWConnection(host: host, port: port, using: parameters)
        permissionProbeConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready, .failed, .waiting, .cancelled:
                    self.permissionProbeConnection?.cancel()
                    self.permissionProbeConnection = nil
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
        connection.send(content: Data([0x01]), completion: .contentProcessed { _ in })
    }

    private func startBonjourPermissionProbe() {
        guard permissionBrowser == nil, permissionListener == nil else { return }

        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: UUID().uuidString, type: permissionServiceType)
            listener.newConnectionHandler = { connection in
                connection.cancel()
            }

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if case .failed = state {
                        self.permissionListener?.cancel()
                        self.permissionListener = nil
                    }
                }
            }

            let parameters = NWParameters()
            parameters.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: permissionServiceType, domain: nil), using: parameters)
            browser.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .failed, .waiting, .cancelled:
                        self.permissionBrowser?.cancel()
                        self.permissionBrowser = nil
                    default:
                        break
                    }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !results.isEmpty {
                        self.permissionBrowser?.cancel()
                        self.permissionBrowser = nil
                        self.permissionListener?.cancel()
                        self.permissionListener = nil
                    }
                }
            }

            permissionListener = listener
            permissionBrowser = browser
            listener.start(queue: .main)
            browser.start(queue: .main)
        } catch {
            lastErrorMessage = AppLocalizer.formatted("本地网络权限探测初始化失败：%@", error.localizedDescription)
        }
    }

    private func checkMessage(for url: URL?, label: String) async -> String {
        guard let url else {
            return AppLocalizer.formatted("%@：%@", label, AppLocalizer.localized("无可用地址"))
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            let configuration = URLSessionConfiguration.ephemeral
            configuration.waitsForConnectivity = false
            let session = URLSession(configuration: configuration)
            let (_, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return AppLocalizer.formatted("%@：HTTP %d", label, statusCode)
        } catch {
            return AppLocalizer.formatted("%@：失败（%@）", label, error.localizedDescription)
        }
    }

    private var localIPv4Address: String? {
        var address: String?
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfacePointer) == 0, let firstInterface = interfacePointer else {
            return nil
        }
        defer {
            freeifaddrs(interfacePointer)
        }

        let preferredInterfaceNames = ["en0", "en1", "en2", "bridge100"]

        for name in preferredInterfaceNames {
            address = ipv4Address(for: name, startingAt: firstInterface)
            if address != nil {
                return address
            }
        }

        return nil
    }

    private func ipv4Address(for interfaceName: String, startingAt firstInterface: UnsafeMutablePointer<ifaddrs>) -> String? {
        for pointer in sequence(first: firstInterface, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)

            guard
                flags & IFF_UP == IFF_UP,
                flags & IFF_RUNNING == IFF_RUNNING,
                flags & IFF_LOOPBACK == 0,
                interface.ifa_addr.pointee.sa_family == UInt8(AF_INET)
            else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard name == interfaceName else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var address = interface.ifa_addr.pointee
            let result = getnameinfo(
                &address,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                return String(cString: hostname)
            }
        }

        return nil
    }

    private static func metaPayload(sharedDirectoryURL: URL, deviceName: String, host: String, isConnected: Bool) -> [String: Any] {
        let items = readSharedFiles(from: sharedDirectoryURL)
        let totalBytes = items.reduce(Int64(0)) { $0 + $1.fileSize }
        return [
            "deviceName": deviceName,
            "address": "http://\(host)/",
            "note": "Keep the app in the foreground for more stable transfers.",
            "fileCount": items.count,
            "totalBytes": totalBytes,
            "connectionState": isConnected ? "connected" : "idle"
        ]
    }

    private static func webFileItems(from sharedDirectoryURL: URL) -> [[String: Any]] {
        readSharedFiles(from: sharedDirectoryURL).map { item in
            [
                "name": item.filename,
                "bytes": item.fileSize,
                "modifiedAt": item.modifiedAt?.ISO8601Format() ?? "",
                "extension": item.url.pathExtension.lowercased()
            ]
        }
    }

    private static func readSharedFiles(from sharedDirectoryURL: URL) -> [TransferSharedFile] {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: sharedDirectoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            return try urls
                .filter { url in
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                    return values.isRegularFile == true
                }
                .map { url in
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    return TransferSharedFile(
                        url: url,
                        fileSize: Int64(values.fileSize ?? 0),
                        modifiedAt: values.contentModificationDate
                    )
                }
                .sorted { lhs, rhs in
                    let lhsDate = lhs.modifiedAt ?? .distantPast
                    let rhsDate = rhs.modifiedAt ?? .distantPast
                    if lhsDate != rhsDate {
                        return lhsDate > rhsDate
                    }
                    return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
                }
        } catch {
            return []
        }
    }

    private static func ensureSharedDirectoryExists(at sharedDirectoryURL: URL) throws {
        guard !FileManager.default.fileExists(atPath: sharedDirectoryURL.path) else { return }
        try FileManager.default.createDirectory(
            at: sharedDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private static func uniqueDestinationURL(for filename: String, in sharedDirectoryURL: URL) -> URL {
        let candidateURL = sharedDirectoryURL.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: candidateURL.path) else {
            let ext = candidateURL.pathExtension
            let name = candidateURL.deletingPathExtension().lastPathComponent

            for index in 1...999 {
                let renamed = ext.isEmpty ? "\(name)-\(index)" : "\(name)-\(index).\(ext)"
                let url = sharedDirectoryURL.appendingPathComponent(renamed)
                if !FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            return sharedDirectoryURL.appendingPathComponent(UUID().uuidString + "-" + filename)
        }
        return candidateURL
    }

    private static func sharedFileURL(for filename: String, in sharedDirectoryURL: URL) -> URL? {
        guard
            !filename.isEmpty,
            !filename.contains("/"),
            !filename.contains("\\"),
            filename == URL(fileURLWithPath: filename).lastPathComponent
        else {
            return nil
        }
        return sharedDirectoryURL.appendingPathComponent(filename)
    }

    private static func handleUpload(request: GCDWebServerMultiPartFormRequest, sharedDirectoryURL: URL) -> [String: Any] {
        var uploaded: [String] = []
        var failed: [[String: String]] = []

        for file in request.files {
            guard
                !file.fileName.isEmpty,
                let destinationURL = sharedFileURL(for: file.fileName, in: sharedDirectoryURL)
                    .map({ uniqueDestinationURL(for: $0.lastPathComponent, in: sharedDirectoryURL) })
            else {
                failed.append(["name": file.fileName, "reason": "Invalid filename"])
                continue
            }

            do {
                try FileManager.default.moveItem(atPath: file.temporaryPath, toPath: destinationURL.path)
                uploaded.append(destinationURL.lastPathComponent)
            } catch {
                failed.append(["name": file.fileName, "reason": error.localizedDescription])
            }
        }

        return [
            "uploaded": uploaded,
            "uploadedCount": uploaded.count,
            "failed": failed,
            "failedCount": failed.count
        ]
    }

    private static func jsonResponse(_ object: Any, statusCode: Int = 200) -> GCDWebServerDataResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? Data("{}".utf8)
        let response = GCDWebServerDataResponse(data: data, contentType: "application/json; charset=utf-8")
        response.statusCode = statusCode
        return response
    }

    private static func errorResponse(statusCode: Int, message: String) -> GCDWebServerDataResponse {
        jsonResponse(["error": message], statusCode: statusCode)
    }

    private static func webResourcePath(named name: String, withExtension ext: String) -> String? {
        if let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: webResourceDirectory) {
            return path
        }
        if let path = Bundle.main.path(forResource: name, ofType: ext) {
            return path
        }
        return nil
    }
}

extension LocalTransferService: GCDWebServerDelegate {
    func webServerDidStart(_ server: GCDWebServer) {
        isRunning = true
        serverURL = server.serverURL
    }

    func webServerDidStop(_ server: GCDWebServer) {
        stopClientHeartbeatMonitor()
        lastExternalClientActivityAt = nil
        isRunning = false
        isClientConnected = false
        serverURL = nil
    }

    func webServerDidConnect(_ server: GCDWebServer) {}

    func webServerDidDisconnect(_ server: GCDWebServer) {}
}
