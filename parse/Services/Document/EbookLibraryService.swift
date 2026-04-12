import Foundation

struct EbookLibraryItem: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let storedFilename: String
    let coverFilename: String?
    let sourceFormat: EbookSourceFormat
    let importedAt: Date
    let fileSize: Int64
}

enum EbookLibraryService {
    nonisolated private static let folderName = "EbookLibrary"
    nonisolated private static let manifestName = "library.json"

    nonisolated static func loadItems() -> [EbookLibraryItem] {
        guard
            let data = try? Data(contentsOf: manifestURL()),
            let items = try? JSONDecoder().decode([EbookLibraryItem].self, from: data)
        else {
            return []
        }

        return items.sorted { $0.importedAt > $1.importedAt }
    }

    nonisolated static func importItems(from urls: [URL]) throws -> [EbookLibraryItem] {
        guard !urls.isEmpty else { return loadItems() }

        let directory = try libraryDirectory()
        var items = loadItems()

        for url in urls {
            guard let sourceFormat = EbookSourceFormat.resolve(from: url) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let baseName = sanitizedFilename(url.deletingPathExtension().lastPathComponent)
            let filename = uniqueFilename(
                baseName: baseName,
                fileExtension: sourceFormat.fileExtension,
                in: directory
            )
            let destinationURL = directory.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)

            let itemID = UUID()
            let title = resolvedTitle(for: destinationURL, sourceFormat: sourceFormat)
            let coverFilename = try extractAndStoreCoverIfNeeded(
                for: destinationURL,
                itemID: itemID,
                sourceFormat: sourceFormat,
                in: directory
            )
            let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
            items.append(
                EbookLibraryItem(
                    id: itemID,
                    title: title,
                    storedFilename: filename,
                    coverFilename: coverFilename,
                    sourceFormat: sourceFormat,
                    importedAt: Date(),
                    fileSize: Int64(values.fileSize ?? 0)
                )
            )
        }

        try save(items)
        return loadItems()
    }

    nonisolated static func remove(_ item: EbookLibraryItem) throws -> [EbookLibraryItem] {
        var items = loadItems()
        let fileURL = fileURL(for: item)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        if let coverURL = coverURL(for: item), FileManager.default.fileExists(atPath: coverURL.path) {
            try FileManager.default.removeItem(at: coverURL)
        }
        items.removeAll { $0.id == item.id }
        try save(items)
        return loadItems()
    }

    nonisolated static func fileURL(for item: EbookLibraryItem) -> URL {
        try! libraryDirectory().appendingPathComponent(item.storedFilename)
    }

    nonisolated static func coverURL(for item: EbookLibraryItem) -> URL? {
        guard let coverFilename = item.coverFilename else { return nil }
        return try! libraryDirectory().appendingPathComponent(coverFilename)
    }

    nonisolated static func refreshCoverAssetsIfNeeded() throws -> [EbookLibraryItem] {
        let directory = try libraryDirectory()
        var items = loadItems()
        var hasChanges = false

        for index in items.indices {
            guard items[index].sourceFormat == .epub else { continue }

            if let existingCoverURL = coverURL(for: items[index]),
               FileManager.default.fileExists(atPath: existingCoverURL.path) {
                continue
            }

            let sourceURL = directory.appendingPathComponent(items[index].storedFilename)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }

            let coverFilename = try extractAndStoreCoverIfNeeded(
                for: sourceURL,
                itemID: items[index].id,
                sourceFormat: items[index].sourceFormat,
                in: directory
            )

            if coverFilename != items[index].coverFilename {
                items[index] = EbookLibraryItem(
                    id: items[index].id,
                    title: items[index].title,
                    storedFilename: items[index].storedFilename,
                    coverFilename: coverFilename,
                    sourceFormat: items[index].sourceFormat,
                    importedAt: items[index].importedAt,
                    fileSize: items[index].fileSize
                )
                hasChanges = true
            }
        }

        if hasChanges {
            try save(items)
        }

        return loadItems()
    }

    nonisolated private static func save(_ items: [EbookLibraryItem]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: manifestURL(), options: .atomic)
    }

    nonisolated private static func extractAndStoreCoverIfNeeded(
        for fileURL: URL,
        itemID: UUID,
        sourceFormat: EbookSourceFormat,
        in directory: URL
    ) throws -> String? {
        guard sourceFormat == .epub else { return nil }
        guard let coverAsset = try EPUBConversionService.extractCover(from: fileURL) else {
            return nil
        }

        let coverFilename = "\(itemID.uuidString.lowercased())_cover.\(coverAsset.fileExtension)"
        let destinationURL = directory.appendingPathComponent(coverFilename)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try coverAsset.data.write(to: destinationURL, options: .atomic)
        return coverFilename
    }

    nonisolated private static func resolvedTitle(for url: URL, sourceFormat: EbookSourceFormat) -> String {
        switch sourceFormat {
        case .epub:
            if let content = try? EPUBConversionService.extractContent(from: url),
               !content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content.title
            }
        case .txt:
            break
        }

        return url.deletingPathExtension().lastPathComponent
    }

    nonisolated private static func libraryDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func manifestURL() -> URL {
        let root = try! libraryDirectory()
        return root.appendingPathComponent(manifestName)
    }

    nonisolated private static func uniqueFilename(baseName: String, fileExtension: String, in directory: URL) -> String {
        var counter = 0
        while true {
            let candidate = counter == 0
                ? "\(baseName).\(fileExtension)"
                : "\(baseName)_\(counter).\(fileExtension)"
            if !FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
                return candidate
            }
            counter += 1
        }
    }

    nonisolated private static func sanitizedFilename(_ source: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = source.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "ebook" : trimmed
    }
}
