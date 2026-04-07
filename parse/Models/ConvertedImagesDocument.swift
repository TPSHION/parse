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
            
            // 为了安全起见，从临时文件读取数据包装进 FileWrapper
            // 因为 iOS 系统的 FileWrapper(url:) 处理外部依赖文件时可能会在导出时出现权限或状态问题
            let data = try Data(contentsOf: fileURL)
            let wrapper = FileWrapper(regularFileWithContents: data)
            
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
