import Foundation
@preconcurrency import GCDWebServer
import ReadiumShared
import UniformTypeIdentifiers

enum ReadiumGCDHTTPServerError: Error {
    case failedToStartServer(cause: Error)
    case invalidBaseURL
    case serverNotStarted
    case invalidEndpoint
}

final class ReadiumGCDHTTPServer: HTTPServer {
    private struct EndpointHandler {
        let endpoint: HTTPServerEndpoint
        let handler: HTTPRequestHandler
        var transformers: [ResourceTransformer] = []
    }

    private enum State {
        case stopped
        case started(baseURL: HTTPURL)
    }

    private let webServer = GCDWebServer()
    private let assetRetriever: AssetRetriever
    private let queue = DispatchQueue(label: "cn.tpshion.parse.readium-http-server", attributes: .concurrent)
    private var state: State = .stopped
    private var handlers: [HTTPServerEndpoint: EndpointHandler] = [:]

    init(assetRetriever: AssetRetriever) {
        self.assetRetriever = assetRetriever

        webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request, completion in
            self?.handle(request: request, completion: completion)
        }
        webServer.addDefaultHandler(forMethod: "HEAD", request: GCDWebServerRequest.self) { [weak self] request, completion in
            self?.handle(request: request, completion: completion, headOnly: true)
        }
    }

    deinit {
        if webServer.isRunning {
            webServer.stop()
        }
    }

    @discardableResult
    func serve(at endpoint: HTTPServerEndpoint, handler: HTTPRequestHandler) throws -> HTTPURL {
        try queue.sync(flags: .barrier) {
            if case .stopped = state {
                try startLocked()
            }

            handlers[normalizedEndpoint(endpoint)] = EndpointHandler(
                endpoint: normalizedEndpoint(endpoint),
                handler: handler
            )
            return try url(for: endpoint)
        }
    }

    func transformResources(at endpoint: HTTPServerEndpoint, with transformer: @escaping ResourceTransformer) throws {
        try queue.sync(flags: .barrier) {
            let key = normalizedEndpoint(endpoint)
            guard var current = handlers[key] else {
                throw ReadiumGCDHTTPServerError.invalidEndpoint
            }
            current.transformers.append(transformer)
            handlers[key] = current
        }
    }

    func remove(at endpoint: HTTPServerEndpoint) throws {
        _ = queue.sync(flags: .barrier) {
            handlers.removeValue(forKey: normalizedEndpoint(endpoint))
        }
    }

    private func handle(
        request: GCDWebServerRequest,
        completion: @escaping GCDWebServerCompletionBlock,
        headOnly: Bool = false
    ) {
        queue.async { [weak self] in
            guard let self else {
                completion(Self.errorResponse(statusCode: 500))
                return
            }

            guard
                let matched = self.match(request: request),
                let requestURL = HTTPURL(url: request.url)
            else {
                completion(Self.errorResponse(statusCode: 404))
                return
            }

            let relativeHref = matched.relativeHref.flatMap { RelativeURL(string: $0) }
            let serverRequest = HTTPServerRequest(url: requestURL, href: relativeHref)
            var response = matched.endpointHandler.handler.onRequest(serverRequest)

            if !matched.endpointHandler.transformers.isEmpty {
                let href = relativeHref?.anyURL ?? requestURL.anyURL
                for transformer in matched.endpointHandler.transformers {
                    response.resource = transformer(href, response.resource)
                }
            }

            Task {
                let webResponse = await self.makeResponse(
                    from: response,
                    request: request,
                    serverRequest: serverRequest,
                    failureHandler: matched.endpointHandler.handler.onFailure,
                    headOnly: headOnly
                )
                completion(webResponse)
            }
        }
    }

    private func makeResponse(
        from response: HTTPServerResponse,
        request: GCDWebServerRequest,
        serverRequest: HTTPServerRequest,
        failureHandler: HTTPRequestHandler.OnFailure?,
        headOnly: Bool
    ) async -> GCDWebServerResponse {
        do {
            let resource = response.resource
            let totalLength = try await resolvedLength(of: resource)
            let contentType = await resolvedContentType(for: response)
            let readRange = resolvedReadRange(for: request, totalLength: totalLength)

            let data: Data
            if headOnly {
                data = Data()
            } else if let readRange {
                data = try await resource.read(range: readRange).get()
            } else {
                data = try await resource.read().get()
            }

            let webResponse = GCDWebServerDataResponse(data: data, contentType: contentType)
            webResponse.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
            webResponse.setValue("no-cache", forAdditionalHeader: "Pragma")
            webResponse.setValue("0", forAdditionalHeader: "Expires")
            webResponse.setValue("bytes", forAdditionalHeader: "Accept-Ranges")

            if let readRange {
                webResponse.statusCode = 206
                let upperBound = max(readRange.upperBound, 1) - 1
                webResponse.setValue(
                    "bytes \(readRange.lowerBound)-\(upperBound)/\(totalLength)",
                    forAdditionalHeader: "Content-Range"
                )
            }

            return webResponse
        } catch let error as ReadError {
            failureHandler?(serverRequest, error)
            return Self.errorResponse(statusCode: 500)
        } catch {
            failureHandler?(serverRequest, .decoding(error))
            return Self.errorResponse(statusCode: 500)
        }
    }

    private func resolvedLength(of resource: Resource) async throws -> UInt64 {
        if let estimatedLength = try await resource.estimatedLength().get() {
            return estimatedLength
        }
        return UInt64(try await resource.read().get().count)
    }

    private func resolvedContentType(for response: HTTPServerResponse) async -> String {
        if let mediaType = response.mediaType?.string {
            return mediaType
        }

        if let properties = try? await response.resource.properties().get() {
            if let mediaType = properties.mediaType?.string {
                return mediaType
            }

            if
                let filename = properties.filename,
                let mimeType = UTType(filenameExtension: URL(fileURLWithPath: filename).pathExtension)?.preferredMIMEType
            {
                return mimeType
            }
        }

        if let mediaType = try? await assetRetriever.sniffFormat(of: response.resource).get().mediaType?.string {
            return mediaType
        }

        return "application/octet-stream"
    }

    private func resolvedReadRange(for request: GCDWebServerRequest, totalLength: UInt64) -> Range<UInt64>? {
        guard request.hasByteRange() else {
            return nil
        }

        let byteRange = request.byteRange
        if byteRange.location == NSNotFound {
            return nil
        }

        if byteRange.location == Int.max {
            let length = min(UInt64(byteRange.length), totalLength)
            return (totalLength - length)..<totalLength
        }

        guard byteRange.location >= 0 else {
            return nil
        }

        let lowerBound = min(UInt64(byteRange.location), totalLength)
        if byteRange.length == Int.max {
            return lowerBound..<totalLength
        }

        let upperBound = min(lowerBound + UInt64(byteRange.length), totalLength)
        return lowerBound..<upperBound
    }

    private func match(request: GCDWebServerRequest) -> (endpointHandler: EndpointHandler, relativeHref: String?)? {
        let requestedPath = normalizedPath(request.url.path)
        let exactPath = requestedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        for endpointHandler in handlers.values {
            let endpoint = endpointHandler.endpoint
            if exactPath == endpoint {
                return (endpointHandler, nil)
            }

            let prefix = endpoint + "/"
            if exactPath.hasPrefix(prefix) {
                let suffix = String(exactPath.dropFirst(prefix.count))
                return (endpointHandler, suffix.removingPercentEncoding ?? suffix)
            }
        }

        return nil
    }

    private func startLocked() throws {
        var attempts = 20
        while attempts > 0 {
            attempts -= 1

            do {
                try startLocked(on: Self.randomPort())
                return
            } catch {
                if attempts == 0 {
                    throw error
                }
            }
        }
    }

    private func startLocked(on port: UInt) throws {
        if webServer.isRunning {
            webServer.stop()
        }

        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: port,
                GCDWebServerOption_BindToLocalhost: true,
                GCDWebServerOption_AutomaticallySuspendInBackground: false,
            ])
        } catch {
            throw ReadiumGCDHTTPServerError.failedToStartServer(cause: error)
        }

        guard let baseURL = webServer.serverURL.flatMap({ HTTPURL(url: $0) }) else {
            throw ReadiumGCDHTTPServerError.invalidBaseURL
        }

        state = .started(baseURL: baseURL)
    }

    private func url(for endpoint: HTTPServerEndpoint) throws -> HTTPURL {
        guard case let .started(baseURL) = state else {
            throw ReadiumGCDHTTPServerError.serverNotStarted
        }
        return baseURL.appendingPath(normalizedEndpoint(endpoint), isDirectory: true)
    }

    private func normalizedEndpoint(_ endpoint: HTTPServerEndpoint) -> HTTPServerEndpoint {
        normalizedPath(endpoint).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func normalizedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "\\\\+", with: "/", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func randomPort() -> UInt {
        UInt(Int.random(in: 49152...65535))
    }

    private static func errorResponse(statusCode: Int) -> GCDWebServerResponse {
        let response = GCDWebServerDataResponse(text: HTTPURLResponse.localizedString(forStatusCode: statusCode))
            ?? GCDWebServerDataResponse()
        response.statusCode = statusCode
        return response
    }
}
