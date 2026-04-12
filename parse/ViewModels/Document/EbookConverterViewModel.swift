import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class EbookConverterViewModel: ObservableObject {
    static let supportedContentTypes = EbookSourceFormat.allCases.map(\.contentType)

    @Published var items: [EbookItem] = []
    @Published var isImporting = false
    @Published var isConverting = false
    @Published var batchTargetFormat: EbookTargetFormat = .txt {
        didSet {
            for index in items.indices {
                if isReady(items[index].status) {
                    items[index].targetFormat = batchTargetFormat
                }
            }
        }
    }

    var totalCount: Int { items.count }
    var pendingCount: Int { items.filter { if case .pending = $0.status { return true } else { return false } }.count }
    var successCount: Int { items.filter { if case .success = $0.status { return true } else { return false } }.count }
    var failedCount: Int {
        items.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    var canConvert: Bool {
        !items.isEmpty && !isConverting && items.contains { isReady($0.status) }
    }

    var hasSuccessItems: Bool {
        !successfulItems.isEmpty
    }

    var successfulItems: [EbookItem] {
        items.filter {
            if case .success = $0.status, $0.convertedFileURL != nil {
                return true
            }
            return false
        }
    }

    var shouldShowProgress: Bool {
        !items.isEmpty
    }

    var processedCount: Int {
        successCount + failedCount
    }

    var progressValue: Double {
        guard totalCount > 0 else { return 0 }
        return Double(processedCount) / Double(totalCount)
    }

    var progressText: String {
        "\(processedCount)/\(totalCount)"
    }

    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true

            Task { [weak self] in
                guard let self else { return }
                defer { self.isImporting = false }

                for url in urls {
                    await self.importEbook(from: url)
                }
            }
        case .failure(let error):
            print("Failed to import ebook files: \(error.localizedDescription)")
        }
    }

    func updateTargetFormat(for id: UUID, to format: EbookTargetFormat) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].targetFormat = format

        if let outputURL = items[index].convertedFileURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        items[index].convertedFileURL = nil
        items[index].status = .pending
    }

    func removeItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let outputURL = items[index].convertedFileURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        try? FileManager.default.removeItem(at: items[index].originalFileURL)
        items.remove(at: index)
    }

    func clearAll() {
        for item in items {
            if let outputURL = item.convertedFileURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try? FileManager.default.removeItem(at: item.originalFileURL)
        }
        items.removeAll()
    }

    func startConversion() async {
        guard canConvert else { return }
        isConverting = true
        defer { isConverting = false }

        for index in items.indices where isReady(items[index].status) {
            items[index].status = .converting(progress: 0.12)

            do {
                let currentItem = items[index]
                let bookContent = try await loadBookContent(for: currentItem)

                items[index].status = .converting(progress: 0.62)
                items[index].extractedTitle = bookContent.title

                let outputURL = try makeOutputURL(for: items[index], content: bookContent)
                items[index].convertedFileURL = outputURL
                items[index].status = .success

                TransferResultArchiveService.scheduleArchive(url: outputURL, category: .ebookConversion)
            } catch {
                items[index].status = .failed(error.localizedDescription)
            }
        }
    }

    func saveExportAssets(to directoryURL: URL, selectedItemIDs: Set<UUID>) throws -> Int {
        let selectedItems = successfulItems.filter { selectedItemIDs.contains($0.id) }
        guard !selectedItems.isEmpty else { return 0 }

        guard directoryURL.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { directoryURL.stopAccessingSecurityScopedResource() }

        var usedFilenames = Set<String>()
        var savedCount = 0

        for item in selectedItems {
            guard let sourceURL = item.convertedFileURL else { continue }
            let baseName = sanitizedFilename(item.extractedTitle ?? item.originalName)
            let filename = uniqueFilename(
                baseName: baseName,
                fileExtension: item.targetFormat.fileExtension,
                usedFilenames: &usedFilenames,
                in: directoryURL
            )
            try FileManager.default.copyItem(at: sourceURL, to: directoryURL.appendingPathComponent(filename))
            savedCount += 1
        }

        return savedCount
    }

    func archiveExportAssets(selectedItemIDs: Set<UUID>) throws -> Int {
        let selectedItems = successfulItems.filter { selectedItemIDs.contains($0.id) }
        guard !selectedItems.isEmpty else { return 0 }

        var archivedCount = 0
        for item in selectedItems {
            guard let sourceURL = item.convertedFileURL else { continue }
            try TransferResultArchiveService.archiveImmediately(url: sourceURL, category: .ebookConversion)
            archivedCount += 1
        }
        return archivedCount
    }

    private func importEbook(from url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)

            let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
            guard let sourceFormat = EbookSourceFormat.resolve(from: destinationURL) else { return }
            let item = EbookItem(
                originalFileURL: destinationURL,
                originalName: destinationURL.deletingPathExtension().lastPathComponent,
                fileSize: Int64(values.fileSize ?? 0),
                sourceFormat: sourceFormat,
                targetFormat: batchTargetFormat
            )
            items.append(item)
        } catch {
            print("Failed to import ebook file: \(error.localizedDescription)")
        }
    }

    private func loadBookContent(for item: EbookItem) async throws -> EPUBBookContent {
        let sourceFormat = item.sourceFormat
        let sourceURL = item.originalFileURL

        return try await Task.detached(priority: .userInitiated) {
            switch sourceFormat {
            case .epub:
                return try EPUBConversionService.extractContent(from: sourceURL)
            case .txt:
                return try EPUBConversionService.extractTextFileContent(from: sourceURL)
            }
        }.value
    }

    private func makeOutputURL(for item: EbookItem, content: EPUBBookContent) throws -> URL {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parse-ebook-output", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        var usedFilenames = Set<String>()

        let baseName = sanitizedFilename(content.title.isEmpty ? item.originalName : content.title)
        let fileName = uniqueFilename(
            baseName: baseName,
            fileExtension: item.targetFormat.fileExtension,
            usedFilenames: &usedFilenames,
            in: outputDirectory
        )

        let outputURL = outputDirectory.appendingPathComponent(fileName)
        try exportItem(item, content: content, to: outputURL)
        return outputURL
    }

    private func uniqueFilename(
        baseName: String,
        fileExtension: String,
        usedFilenames: inout Set<String>,
        in directoryURL: URL?
    ) -> String {
        var counter = 0
        while true {
            let candidate = counter == 0
                ? "\(baseName).\(fileExtension)"
                : "\(baseName)_\(counter).\(fileExtension)"

            let existsOnDisk = directoryURL.map {
                FileManager.default.fileExists(atPath: $0.appendingPathComponent(candidate).path)
            } ?? false

            if !existsOnDisk, usedFilenames.insert(candidate).inserted {
                return candidate
            }
            counter += 1
        }
    }

    private func sanitizedFilename(_ source: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = source.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "ebook"
    }

    private func isReady(_ status: EbookItem.ConversionStatus) -> Bool {
        switch status {
        case .pending, .failed:
            return true
        case .converting, .success:
            return false
        }
    }

    private func exportItem(_ item: EbookItem, content: EPUBBookContent, to outputURL: URL) throws {
        if item.sourceFormat.shortLabel == item.targetFormat.shortLabel {
            try FileManager.default.copyItem(at: item.originalFileURL, to: outputURL)
            return
        }

        switch item.targetFormat {
        case .txt:
            try Data(content.plainText.utf8).write(to: outputURL, options: .atomic)
        case .epub:
            try EPUBConversionService.writeEPUB(content: content, to: outputURL)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
