import Foundation
import UniformTypeIdentifiers

enum EbookTargetFormat: String, CaseIterable, Identifiable {
    case epub = "EPUB"
    case txt = "TXT"

    var id: String { rawValue }

    var shortLabel: String { rawValue }

    var fileExtension: String {
        switch self {
        case .epub:
            return "epub"
        case .txt:
            return "txt"
        }
    }

    var contentType: UTType {
        switch self {
        case .epub:
            return UTType(filenameExtension: "epub") ?? .data
        case .txt:
            return .plainText
        }
    }
}
