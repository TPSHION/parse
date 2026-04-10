import Foundation

class CacheManager {
    static let shared = CacheManager()
    
    private init() {}
    
    func calculateCacheSize(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var totalSize: Int64 = 0
            let tempDir = FileManager.default.temporaryDirectory
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            
            totalSize += self.folderSize(at: tempDir)
            if let cacheDir {
                totalSize += self.folderSize(at: cacheDir)
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB, .useKB]
            formatter.countStyle = .file
            let sizeString = formatter.string(fromByteCount: totalSize)
            
            DispatchQueue.main.async {
                completion(sizeString)
            }
        }
    }
    
    func clearCache(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            
            self.clearFolder(at: tempDir)
            if let cacheDir {
                self.clearFolder(at: cacheDir)
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func folderSize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            } catch {
                continue
            }
        }
        return size
    }
    
    private func clearFolder(at url: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in contents {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
