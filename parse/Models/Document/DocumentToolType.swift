import Foundation

enum DocumentToolType: String, CaseIterable, Identifiable {
    case imageToText = "图片转文字"
    case imageToDoc = "图片转文档"
    case ebookConvert = "电子书转换"
    case textWebConvert = "文本/网页转换"
    
    var id: String { self.rawValue }

    var localizedTitle: String {
        switch self {
        case .imageToText: return AppLocalizer.localized("图片转文字")
        case .imageToDoc: return AppLocalizer.localized("图片转文档")
        case .ebookConvert: return AppLocalizer.localized("电子书转换")
        case .textWebConvert: return AppLocalizer.localized("文本/网页转换")
        }
    }
    
    var iconName: String {
        switch self {
        case .imageToText: return "text.viewfinder"
        case .imageToDoc: return "doc.richtext.fill"
        case .ebookConvert: return "book.closed.fill"
        case .textWebConvert: return "network"
        }
    }
    
    var description: String {
        switch self {
        case .imageToText: return AppLocalizer.localized("提取图片中的文字内容 (OCR)")
        case .imageToDoc: return AppLocalizer.localized("将图片整理为可导出的文档内容")
        case .ebookConvert: return AppLocalizer.localized("EPUB 与 TXT 电子书格式互转")
        case .textWebConvert: return AppLocalizer.localized("纯文本、富文本与网页格式互转")
        }
    }
}
