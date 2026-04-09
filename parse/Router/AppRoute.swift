import Foundation

enum AppRoute: Hashable {
    case imageConverter
    case videoConverter
    case audioConverter
    case mediaCompressor
    case pdfConverter
    case documentTool(DocumentToolType)
}
