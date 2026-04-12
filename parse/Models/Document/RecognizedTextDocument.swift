import SwiftUI
import UniformTypeIdentifiers

private let recognizedTextWordType = UTType(filenameExtension: "doc") ?? .data
private let recognizedTextMarkdownType = UTType(filenameExtension: "md") ?? .plainText

enum RecognizedTextExportFormat: String, CaseIterable, Identifiable {
    case plainText
    case word
    case markdown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText:
            return AppLocalizer.localized("TXT 文本")
        case .word:
            return AppLocalizer.localized("Word 文档")
        case .markdown:
            return AppLocalizer.localized("Markdown 文本")
        }
    }

    var shortLabel: String {
        switch self {
        case .plainText:
            return "TXT"
        case .word:
            return "WORD"
        case .markdown:
            return "MD"
        }
    }

    var contentType: UTType {
        switch self {
        case .plainText:
            return .plainText
        case .word:
            return recognizedTextWordType
        case .markdown:
            return recognizedTextMarkdownType
        }
    }

    var fileExtension: String {
        switch self {
        case .plainText:
            return "txt"
        case .word:
            return "doc"
        case .markdown:
            return "md"
        }
    }
}

struct RecognizedTextExportAsset: Equatable {
    let fileURL: URL
    let filename: String
    let contentType: UTType
}

struct RecognizedTextExportBundleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }

    let assets: [RecognizedTextExportAsset]

    init(assets: [RecognizedTextExportAsset]) {
        self.assets = assets
    }

    init(configuration: ReadConfiguration) throws {
        self.assets = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var fileWrappers: [String: FileWrapper] = [:]

        for asset in assets {
            let wrapper = try FileWrapper(url: asset.fileURL, options: .immediate)
            wrapper.preferredFilename = asset.filename

            var finalName = asset.filename
            var counter = 1
            while fileWrappers[finalName] != nil {
                let name = URL(fileURLWithPath: asset.filename).deletingPathExtension().lastPathComponent
                let ext = URL(fileURLWithPath: asset.filename).pathExtension
                finalName = "\(name)_\(counter).\(ext)"
                wrapper.preferredFilename = finalName
                counter += 1
            }

            fileWrappers[finalName] = wrapper
        }

        return FileWrapper(directoryWithFileWrappers: fileWrappers)
    }
}
