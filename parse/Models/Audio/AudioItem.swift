import Foundation

struct AudioItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let filename: String
    let baseName: String
    let fileSize: Int64
    let originalFormat: String
    
    var targetFormat: AudioFormat = .mp3
    var status: ConversionStatus = .pending
    var convertedURL: URL?
    var conversionProgress: Double = 0.0
    
    init(url: URL, originalFilename: String? = nil, targetFormat: AudioFormat = .mp3) {
        let resolvedFilename = originalFilename ?? url.lastPathComponent
        
        self.url = url
        self.filename = resolvedFilename
        self.baseName = URL(fileURLWithPath: resolvedFilename).deletingPathExtension().lastPathComponent
        self.originalFormat = URL(fileURLWithPath: resolvedFilename).pathExtension.uppercased()
        self.targetFormat = targetFormat
        
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            self.fileSize = Int64(resources.fileSize ?? 0)
        } catch {
            self.fileSize = 0
        }
    }
    
    enum ConversionStatus: Equatable {
        case pending
        case converting
        case success
        case failed(String)
    }
    
    static func == (lhs: AudioItem, rhs: AudioItem) -> Bool {
        lhs.id == rhs.id
    }
}
