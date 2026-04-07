import SwiftUI
import UniformTypeIdentifiers

struct ConvertedVideosDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    
    var items: [VideoItem]
    
    init(items: [VideoItem]) {
        self.items = items
    }
    
    init(configuration: ReadConfiguration) throws {
        self.items = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var fileWrappers: [String: FileWrapper] = [:]
        
        for item in items {
            guard let fileURL = item.convertedFileURL else { continue }
            
            let data = try Data(contentsOf: fileURL)
            let wrapper = FileWrapper(regularFileWithContents: data)
            
            let ext = item.targetFormat.fileExtension
            let filename = "\(item.originalName).\(ext)"
            wrapper.preferredFilename = filename
            
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
