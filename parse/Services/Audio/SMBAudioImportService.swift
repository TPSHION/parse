import Foundation
import AMSMB2

struct SMBAudioImportService {
    func listShares(connection: SMBAudioConnectionDetails) async throws -> [SMBShareItem] {
        let client = try makeClient(for: connection)

        do {
            let shares = try await listShares(client)
            return shares
                .map { SMBShareItem(name: $0.name, comment: $0.comment) }
                .sorted { lhs, rhs in
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        } catch {
            throw error
        }
    }

    func listAudioFiles(connection: SMBAudioConnectionDetails) async throws -> [SMBRemoteAudioFile] {
        let client = try makeClient(for: connection)
        
        do {
            try await connect(client, shareName: connection.trimmedShareName)
            let entries = try await contentsOfDirectory(client, path: connection.normalizedDirectoryPath)
            try? await disconnect(client)
            
            return entries.compactMap { entry in
                let isRegularFile = (entry[.isRegularFileKey] as? NSNumber)?.boolValue ?? false
                guard isRegularFile,
                      let name = entry[.nameKey] as? String,
                      let path = entry[.pathKey] as? String,
                      let format = AudioFormat(fileExtension: URL(fileURLWithPath: name).pathExtension) else {
                    return nil
                }
                
                let fileSize = (entry[.fileSizeKey] as? NSNumber)?.int64Value ?? 0
                return SMBRemoteAudioFile(name: name, path: path, fileSize: fileSize, format: format)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            try? await disconnect(client)
            throw error
        }
    }
    
    func downloadAudioFiles(
        _ files: [SMBRemoteAudioFile],
        connection: SMBAudioConnectionDetails
    ) async throws -> [ImportedAudioFile] {
        let client = try makeClient(for: connection)
        var downloadedFiles: [ImportedAudioFile] = []
        
        do {
            try await connect(client, shareName: connection.trimmedShareName)
            
            for file in files {
                let localURL = makeTemporaryURL(for: file.name)
                try await download(client, remotePath: file.path, localURL: localURL)
                downloadedFiles.append(
                    ImportedAudioFile(url: localURL, originalFilename: file.name)
                )
            }
            
            try? await disconnect(client)
            return downloadedFiles
        } catch {
            downloadedFiles.forEach { try? FileManager.default.removeItem(at: $0.url) }
            try? await disconnect(client)
            throw error
        }
    }
    
    private func makeClient(for connection: SMBAudioConnectionDetails) throws -> AMSMB2 {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = connection.trimmedServerAddress
        
        guard let url = components.url else {
            throw SMBAudioImportError.invalidServerAddress
        }
        
        let credential = URLCredential(
            user: connection.effectiveUsername,
            password: connection.password,
            persistence: .forSession
        )
        
        guard let client = AMSMB2(url: url, domain: connection.trimmedDomain, credential: credential) else {
            throw SMBAudioImportError.invalidServerAddress
        }
        
        return client
    }
    
    private func connect(_ client: AMSMB2, shareName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.connectShare(name: shareName, encrypted: false) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func disconnect(_ client: AMSMB2) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.disconnectShare(gracefully: false) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func contentsOfDirectory(_ client: AMSMB2, path: String) async throws -> [[URLResourceKey: Any]] {
        try await withCheckedThrowingContinuation { continuation in
            client.contentsOfDirectory(atPath: path, recursive: false) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func listShares(_ client: AMSMB2) async throws -> [(name: String, comment: String)] {
        try await withCheckedThrowingContinuation { continuation in
            client.listShares(enumerateHidden: false) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func download(_ client: AMSMB2, remotePath: String, localURL: URL) async throws {
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.downloadItem(atPath: remotePath, to: localURL, progress: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func makeTemporaryURL(for filename: String) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        return tempDirectory.appendingPathComponent("\(UUID().uuidString)_\(filename)")
    }
}

enum SMBAudioImportError: LocalizedError {
    case invalidServerAddress
    case noAudioFilesFound
    case noSharesFound
    
    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            return "请输入有效的服务器地址。"
        case .noAudioFilesFound:
            return "当前目录下没有可导入的音频文件。"
        case .noSharesFound:
            return "服务器已连接，但没有读取到可用共享。"
        }
    }
}
