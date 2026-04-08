import Foundation

enum DocumentToolType: String, CaseIterable, Identifiable {
    case pdfToWord = "PDF 转 Word"
    case imageToText = "图片转文字"
    case imageToDoc = "图片转文档"
    case ebookConvert = "电子书转换"
    case textWebConvert = "文本/网页转换"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .pdfToWord: return "doc.text.fill"
        case .imageToText: return "text.viewfinder"
        case .imageToDoc: return "doc.richtext.fill"
        case .ebookConvert: return "book.closed.fill"
        case .textWebConvert: return "network"
        }
    }
    
    var description: String {
        switch self {
        case .pdfToWord: return "将 PDF 文件转换为可编辑的 Word 文档"
        case .imageToText: return "提取图片中的文字内容 (OCR)"
        case .imageToDoc: return "将图片转换为 PDF 或 Word 文档"
        case .ebookConvert: return "EPUB, MOBI, AZW3 等格式互转"
        case .textWebConvert: return "纯文本、富文本与网页格式互转"
        }
    }
}
