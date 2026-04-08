import SwiftUI
import UniformTypeIdentifiers

struct ConvertedImagesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    
    var items: [ImageItem]
    
    init(items: [ImageItem]) {
        self.items = items
    }
    
    init(configuration: ReadConfiguration) throws {
        self.items = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var fileWrappers: [String: FileWrapper] = [:]
        
        for item in items {
            guard let fileURL = item.convertedFileURL else { continue }
            
            // 转换产物已经位于应用自己的临时目录中，直接使用磁盘文件可避免导出时的内存峰值。
            let wrapper = try FileWrapper(url: fileURL, options: .immediate)
            
            let ext = item.targetFormat.fileExtension
            let filename = "\(item.originalName).\(ext)"
            wrapper.preferredFilename = filename
            
            // To handle duplicate names
            var finalName = filename
            var counter = 1
            while fileWrappers[finalName] != nil {
                finalName = "\(item.originalName)_\(counter).\(ext)"
                wrapper.preferredFilename = finalName
                counter += 1
            }
            
            fileWrappers[finalName] = wrapper
        }
        
        return FileWrapper(directoryWithFileWrappers: fileWrappers)
    }
}
