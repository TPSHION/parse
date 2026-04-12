import Foundation

enum AppRoute: Hashable {
    case imageConverter
    case videoConverter
    case audioConverter
    case mediaCompressor
    case documentTool(DocumentToolType)
}
