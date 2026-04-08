import Foundation

struct PDFItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let filename: String
    let fileSize: Int64
    
    var targetFormat: PDFTargetFormat = .docx
    var status: ConversionStatus = .pending
    var convertedURL: URL?
    
    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            self.fileSize = Int64(resources.fileSize ?? 0)
        } catch {
            self.fileSize = 0
        }
    }
    
    enum ConversionStatus: Equatable {
        case pending
        case converting(progress: Double)
        case success
        case failed(error: String)
    }
}
