import Combine
import CoreGraphics
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
final class ImageTextRecognitionViewModel: ObservableObject {
    @Published var items: [RecognizedTextItem] = []
    @Published var isImporting = false
    @Published var isRecognizing = false
    @Published var batchTargetFormat: RecognizedTextExportFormat = .plainText {
        didSet {
            for index in items.indices {
                items[index].targetFormat = batchTargetFormat
            }
        }
    }

    private var importActivityCount = 0

    var totalCount: Int {
        items.count
    }

    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }

    var successCount: Int {
        items.filter { $0.status == .success && !$0.recognizedText.isEmpty }.count
    }

    var failedCount: Int {
        items.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    var recognizingCount: Int {
        items.filter { $0.status == .recognizing }.count
    }

    var canRecognize: Bool {
        !items.isEmpty && !isRecognizing
    }

    var hasExportableItems: Bool {
        !successfulItems.isEmpty
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

    var shouldShowProgress: Bool {
        totalCount > 0 && (isRecognizing || processedCount > 0)
    }

    var exportFolderName: String {
        if successfulItems.count == 1, let item = successfulItems.first {
            return sanitizedExportFilename(item.originalName)
        }
        return "ParseLab-OCR"
    }

    var successfulItems: [RecognizedTextItem] {
        items.filter { $0.status == .success && !$0.recognizedText.isEmpty }
    }

    func processPhotoSelections(_ selections: [PhotosPickerItem]) {
        guard !selections.isEmpty else { return }
        beginImport()

        Task { [weak self] in
            guard let self else { return }
            defer { self.endImport() }

            for selection in selections {
                do {
                    if let imageFile = try await selection.loadTransferable(type: ImageFileTransferable.self) {
                        let url = imageFile.url
                        let format = selection.supportedContentTypes.first?.preferredFilenameExtension?.uppercased()
                            ?? URL(fileURLWithPath: imageFile.originalFilename).pathExtension.uppercased()
                        let name = URL(fileURLWithPath: imageFile.originalFilename)
                            .deletingPathExtension()
                            .lastPathComponent

                        await self.addItem(
                            fileURL: url,
                            name: name,
                            format: format.isEmpty ? AppLocalizer.localized("未知") : format
                        )
                    }
                } catch {
                    print("Failed to load OCR image from photo library: \(error.localizedDescription)")
                }
            }
        }
    }

    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            beginImport()

            Task { [weak self] in
                guard let self else { return }
                defer { self.endImport() }
                await self.importImages(from: urls)
            }
        case .failure(let error):
            print("Failed to import OCR images: \(error.localizedDescription)")
        }
    }

    func startRecognition() async {
        guard !items.isEmpty, !isRecognizing else { return }
        isRecognizing = true

        defer { isRecognizing = false }

        for index in items.indices {
            items[index].status = .recognizing
            items[index].recognizedText = ""

            do {
                let text = try await ImageTextRecognitionService.recognizeText(from: items[index].originalFileURL)
                items[index].recognizedText = text
                items[index].status = .success
                try archiveRecognizedItem(items[index])
            } catch {
                items[index].status = .failed(error.localizedDescription)
            }
        }
    }

    func clearAll() {
        items.removeAll()
    }

    func removeItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
    }

    func updateTargetFormat(for id: UUID, to format: RecognizedTextExportFormat) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].targetFormat = format
    }

    func prepareRemoteImageImport(from urlString: String) async throws -> RemoteImageImportPreview {
        let remoteURL = try normalizeRemoteImageURL(from: urlString)
        let (downloadedURL, response) = try await URLSession.shared.download(from: remoteURL)
        let storedURL = try persistDownloadedImage(from: downloadedURL, response: response, sourceURL: remoteURL)
        let previewImage = await generatePreviewImage(from: storedURL)

        guard let source = CGImageSourceCreateWithURL(storedURL as CFURL, nil) else {
            try? FileManager.default.removeItem(at: storedURL)
            throw RemoteImageImportError.notAnImage
        }

        let detectedUTType = (CGImageSourceGetType(source) as String?).flatMap(UTType.init)
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let pixelHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let fileSize = Int64((try storedURL.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)

        let displayFilename = resolvedFilename(for: response, sourceURL: remoteURL, detectedUTType: detectedUTType)
        let displayName = URL(fileURLWithPath: displayFilename).deletingPathExtension().lastPathComponent

        return RemoteImageImportPreview(
            sourceURL: remoteURL,
            localFileURL: storedURL,
            previewImage: previewImage,
            displayFilename: displayFilename,
            displayName: displayName,
            detectedFormat: displayFormat(for: detectedUTType, fallbackURL: storedURL, mimeType: response.mimeType),
            mimeType: response.mimeType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSizeInBytes: fileSize
        )
    }

    func confirmRemoteImageImport(_ preview: RemoteImageImportPreview) {
        items.append(
            RecognizedTextItem(
                originalFileURL: preview.localFileURL,
                previewImage: preview.previewImage,
                originalName: preview.displayName,
                originalFormat: preview.detectedFormat,
                targetFormat: batchTargetFormat
            )
        )
    }

    func discardRemoteImageImport(_ preview: RemoteImageImportPreview) {
        try? FileManager.default.removeItem(at: preview.localFileURL)
    }

    func prepareShareItems(for selectedItemIDs: Set<UUID>) -> [Any]? {
        do {
            let assets = try buildExportAssets(for: selectedItemIDs)
            return assets.isEmpty ? nil : assets.map(OCRShareItemSource.init(asset:))
        } catch {
            print("Failed to build OCR share items: \(error.localizedDescription)")
            return nil
        }
    }

    func saveExportAssets(to directoryURL: URL, selectedItemIDs: Set<UUID>) throws -> Int {
        let assets = try buildExportAssets(for: selectedItemIDs)
        guard !assets.isEmpty else { return 0 }

        guard directoryURL.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { directoryURL.stopAccessingSecurityScopedResource() }

        var usedFilenames = Set<String>()
        var savedCount = 0

        for asset in assets {
            try? TransferResultArchiveService.archiveImmediately(url: asset.fileURL, category: .textRecognition)

            let destinationFilename = uniqueFilename(
                baseName: URL(fileURLWithPath: asset.filename).deletingPathExtension().lastPathComponent,
                fileExtension: URL(fileURLWithPath: asset.filename).pathExtension,
                usedFilenames: &usedFilenames,
                in: directoryURL
            )
            let destinationURL = directoryURL.appendingPathComponent(destinationFilename)
            try FileManager.default.copyItem(at: asset.fileURL, to: destinationURL)
            savedCount += 1
        }

        return savedCount
    }

    func archiveExportAssets(selectedItemIDs: Set<UUID>) throws -> Int {
        let assets = try buildExportAssets(for: selectedItemIDs)
        guard !assets.isEmpty else { return 0 }

        var archivedCount = 0
        for asset in assets {
            try TransferResultArchiveService.archiveImmediately(url: asset.fileURL, category: .textRecognition)
            archivedCount += 1
        }
        return archivedCount
    }

    private func addItem(fileURL: URL, name: String, format: String) async {
        let previewImage = await generatePreviewImage(from: fileURL)
        items.append(
            RecognizedTextItem(
                originalFileURL: fileURL,
                previewImage: previewImage,
                originalName: name,
                originalFormat: format,
                targetFormat: batchTargetFormat
            )
        )
    }

    private func importImages(from urls: [URL]) async {
        for url in urls {
            let imported: (tempURL: URL, name: String, format: String)? = {
                guard url.startAccessingSecurityScopedResource() else { return nil }
                defer { url.stopAccessingSecurityScopedResource() }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)

                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    let name = url.deletingPathExtension().lastPathComponent
                    let ext = url.pathExtension.uppercased()
                    return (tempURL, name, ext.isEmpty ? AppLocalizer.localized("未知") : ext)
                } catch {
                    print("Failed to import OCR image file: \(error.localizedDescription)")
                    return nil
                }
            }()

            if let imported {
                await addItem(fileURL: imported.tempURL, name: imported.name, format: imported.format)
            }
        }
    }

    private func buildExportAssets(for selectedItemIDs: Set<UUID>) throws -> [RecognizedTextExportAsset] {
        let selectedItems = successfulItems.filter { selectedItemIDs.contains($0.id) }
        guard !selectedItems.isEmpty else { return [] }

        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parse-ocr-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        var usedFilenames = Set<String>()
        var assets: [RecognizedTextExportAsset] = []

        for item in selectedItems {
            let baseName = sanitizedExportFilename(item.originalName)
            let filename = uniqueFilename(
                baseName: baseName,
                fileExtension: item.targetFormat.fileExtension,
                usedFilenames: &usedFilenames,
                in: nil
            )
            let fileURL = exportDirectory.appendingPathComponent(filename)
            let data = try exportData(for: item)
            try data.write(to: fileURL, options: .atomic)
            assets.append(
                RecognizedTextExportAsset(
                    fileURL: fileURL,
                    filename: filename,
                    contentType: item.targetFormat.contentType
                )
            )
        }

        return assets
    }

    private func archiveRecognizedItem(_ item: RecognizedTextItem) throws {
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parse-ocr-archive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let filename = "\(sanitizedExportFilename(item.originalName)).\(item.targetFormat.fileExtension)"
        let fileURL = exportDirectory.appendingPathComponent(filename)
        let data = try exportData(for: item)
        try data.write(to: fileURL, options: .atomic)
        try TransferResultArchiveService.archiveImmediately(url: fileURL, category: .textRecognition)
    }

    private func exportData(for item: RecognizedTextItem) throws -> Data {
        switch item.targetFormat {
        case .plainText:
            return Data(item.recognizedText.utf8)
        case .markdown:
            return Data(markdownText(for: item).utf8)
        case .word:
            return Data(wordHTML(for: item).utf8)
        }
    }

    private func markdownText(for item: RecognizedTextItem) -> String {
        "# \(item.originalName)\n\n\(item.recognizedText)"
    }

    private func wordHTML(for item: RecognizedTextItem) -> String {
        let paragraphs = item.recognizedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let escapedLine = escapeHTML(String(line))
                return escapedLine.isEmpty ? "<p>&nbsp;</p>" : "<p>\(escapedLine)</p>"
            }
            .joined(separator: "")

        return """
        <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
        <head>
        <meta charset="utf-8">
        <title>\(escapeHTML(item.originalName))</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Helvetica Neue', sans-serif; font-size: 12pt; color: #111827; margin: 24px; }
        h1 { font-size: 18pt; margin: 0 0 18px 0; }
        p { margin: 0 0 10px 0; line-height: 1.6; }
        </style>
        </head>
        <body>
        <h1>\(escapeHTML(item.originalName))</h1>
        \(paragraphs)
        </body>
        </html>
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
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

    private func generatePreviewImage(from fileURL: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 320
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }.value
    }

    private func normalizeRemoteImageURL(from input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw RemoteImageImportError.invalidURL
        }
        return url
    }

    private func persistDownloadedImage(from downloadedURL: URL, response: URLResponse, sourceURL: URL) throws -> URL {
        let suggestedFilename = response.suggestedFilename ?? sourceURL.lastPathComponent
        let fallbackName = suggestedFilename.isEmpty ? "remote-image" : suggestedFilename
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + fallbackName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: downloadedURL, to: destinationURL)
        return destinationURL
    }

    private func resolvedFilename(for response: URLResponse, sourceURL: URL, detectedUTType: UTType?) -> String {
        let suggestedFilename = response.suggestedFilename ?? sourceURL.lastPathComponent
        let fallbackName = suggestedFilename.isEmpty ? "remote-image" : suggestedFilename
        let baseName = URL(fileURLWithPath: fallbackName).deletingPathExtension().lastPathComponent
        let ext = detectedUTType?.preferredFilenameExtension
            ?? URL(fileURLWithPath: fallbackName).pathExtension

        guard !ext.isEmpty else { return baseName }
        return "\(baseName).\(ext)"
    }

    private func displayFormat(for utType: UTType?, fallbackURL: URL, mimeType: String?) -> String {
        if let utType, let ext = utType.preferredFilenameExtension {
            switch ext.lowercased() {
            case "jpg", "jpeg":
                return "JPEG"
            case "tif", "tiff":
                return "TIFF"
            default:
                return ext.uppercased()
            }
        }

        if let mimeType, let utType = UTType(mimeType: mimeType), let ext = utType.preferredFilenameExtension {
            return ext.uppercased()
        }

        let ext = fallbackURL.pathExtension
        return ext.isEmpty ? AppLocalizer.localized("未知") : ext.uppercased()
    }

    private func beginImport() {
        importActivityCount += 1
        isImporting = importActivityCount > 0
    }

    private func endImport() {
        importActivityCount = max(0, importActivityCount - 1)
        isImporting = importActivityCount > 0
    }

    private func sanitizedExportFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let sanitized = filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "ParseLab-OCR" : sanitized
    }
}

private final class OCRShareItemSource: NSObject, UIActivityItemSource {
    private let asset: RecognizedTextExportAsset

    init(asset: RecognizedTextExportAsset) {
        self.asset = asset
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        asset.fileURL
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        asset.fileURL
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        asset.contentType.identifier
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        asset.filename
    }
}
