import SwiftUI
import UIKit

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let originalImage: UIImage
    let originalName: String
    let originalFormat: String
    
    var targetFormat: ImageFormat = .jpeg
    var status: ConversionStatus = .pending
    
    /// 转换成功后，保存在磁盘上的临时文件 URL
    var convertedFileURL: URL? = nil
    
    enum ConversionStatus: Equatable {
        case pending
        case converting
        case success
        case failed(String)
    }
    
    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        lhs.id == rhs.id
    }
}
