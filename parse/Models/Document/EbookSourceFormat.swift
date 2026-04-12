import Foundation
import UniformTypeIdentifiers

enum EbookSourceFormat: String, CaseIterable, Identifiable {
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
        UTType(filenameExtension: fileExtension) ?? .data
    }

    static func resolve(from url: URL) -> EbookSourceFormat? {
        let ext = url.pathExtension.lowercased()
        return Self.allCases.first { $0.fileExtension == ext }
    }
}
