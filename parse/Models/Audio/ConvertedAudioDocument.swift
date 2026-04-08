import SwiftUI
import UniformTypeIdentifiers

struct ConvertedAudioDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    
    var items: [AudioItem]
    
    init(items: [AudioItem]) {
        self.items = items
    }
    
    init(configuration: ReadConfiguration) throws {
        self.items = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var fileWrappers: [String: FileWrapper] = [:]
        
        for item in items {
            guard let fileURL = item.convertedURL else { continue }
            
            let wrapper = try FileWrapper(url: fileURL, options: .immediate)
            
            let ext = item.targetFormat.fileExtension
            let filename = "\(item.baseName).\(ext)"
            wrapper.preferredFilename = filename
            
            var finalName = filename
            var counter = 1
            while fileWrappers[finalName] != nil {
                finalName = "\(item.baseName)_\(counter).\(ext)"
                wrapper.preferredFilename = finalName
                counter += 1
            }
            
            fileWrappers[finalName] = wrapper
        }
        
        return FileWrapper(directoryWithFileWrappers: fileWrappers)
    }
}
