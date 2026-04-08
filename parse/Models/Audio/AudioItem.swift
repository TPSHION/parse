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
    
    init(url: URL, targetFormat: AudioFormat = .mp3) {
        self.url = url
        self.filename = url.lastPathComponent
        self.baseName = url.deletingPathExtension().lastPathComponent
        self.originalFormat = url.pathExtension.uppercased()
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
