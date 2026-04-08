import SwiftUI
import UniformTypeIdentifiers

struct ConvertedAudioDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    
    var items: [AudioItem]
    
    init(items: [AudioItem]) {
        self.items = items
    }
    
    init(configuration: ReadConfiguration) throws {
        self.items = try Self.loadItems(from: configuration.file)
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
    
    private static func loadItems(from wrapper: FileWrapper) throws -> [AudioItem] {
        guard wrapper.isDirectory, let childWrappers = wrapper.fileWrappers else {
            return []
        }
        
        let importDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportedAudioDocument_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        
        var items: [AudioItem] = []
        
        for (filename, childWrapper) in childWrappers.sorted(by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending }) {
            guard !childWrapper.isDirectory else { continue }
            
            let destinationURL = uniqueDestinationURL(for: filename, in: importDirectory)
            try childWrapper.write(to: destinationURL, options: .atomic, originalContentsURL: nil)
            
            let targetFormat = AudioFormat(fileExtension: destinationURL.pathExtension) ?? .mp3
            items.append(AudioItem(url: destinationURL, originalFilename: filename, targetFormat: targetFormat))
        }
        
        return items
    }
    
    private static func uniqueDestinationURL(for filename: String, in directory: URL) -> URL {
        let initialURL = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: initialURL.path) else {
            return initialURL
        }
        
        let baseName = initialURL.deletingPathExtension().lastPathComponent
        let ext = initialURL.pathExtension
        var counter = 1
        
        while true {
            let candidateName = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
}
