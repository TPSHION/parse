import SwiftUI
import UniformTypeIdentifiers

struct ConvertedMediaDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }

    var items: [MediaCompressionItem]

    init(items: [MediaCompressionItem]) {
        self.items = items
    }

    init(configuration: ReadConfiguration) throws {
        self.items = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var fileWrappers: [String: FileWrapper] = [:]

        for item in items {
            guard let fileURL = item.outputURL else { continue }

            let wrapper = try FileWrapper(url: fileURL, options: .immediate)
            let filename = item.filename
            wrapper.preferredFilename = filename

            var finalName = filename
            var counter = 1
            while fileWrappers[finalName] != nil {
                let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
                let ext = URL(fileURLWithPath: filename).pathExtension
                finalName = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
                wrapper.preferredFilename = finalName
                counter += 1
            }

            fileWrappers[finalName] = wrapper
        }

        return FileWrapper(directoryWithFileWrappers: fileWrappers)
    }
}
