import Foundation

enum PDFTargetFormat: String, CaseIterable, Identifiable {
    case docx = "DOCX"
    case txt = "TXT"
    case markdown = "MD"
    case png = "PNG"
    case jpeg = "JPEG"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .docx: return "doc.word.fill"
        case .txt, .markdown: return "doc.plaintext.fill"
        case .png, .jpeg: return "photo.fill"
        }
    }
}
