import Foundation

struct EbookItem: Identifiable, Equatable {
    let id = UUID()
    let originalFileURL: URL
    let originalName: String
    let fileSize: Int64
    let sourceFormat: EbookSourceFormat

    var extractedTitle: String?
    var targetFormat: EbookTargetFormat = .txt
    var status: ConversionStatus = .pending
    var convertedFileURL: URL?

    enum ConversionStatus: Equatable {
        case pending
        case converting(progress: Double)
        case success
        case failed(String)
    }
}
