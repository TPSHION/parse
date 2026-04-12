import SwiftUI

struct RecognizedTextItem: Identifiable, Equatable {
    let id = UUID()
    let originalFileURL: URL
    let previewImage: UIImage?
    let originalName: String
    let originalFormat: String

    var targetFormat: RecognizedTextExportFormat = .plainText
    var recognizedText: String = ""
    var status: RecognitionStatus = .pending

    enum RecognitionStatus: Equatable {
        case pending
        case recognizing
        case success
        case failed(String)
    }

    static func == (lhs: RecognizedTextItem, rhs: RecognizedTextItem) -> Bool {
        lhs.id == rhs.id
    }
}
