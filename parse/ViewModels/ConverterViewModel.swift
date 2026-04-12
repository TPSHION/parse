import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PhotosUI
import Combine
import Photos

struct ImageFileTransferable: Transferable {
    let url: URL
    let originalFilename: String
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let originalFilename = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + originalFilename)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ImageFileTransferable(url: copy, originalFilename: originalFilename)
        }
    }
}

@MainActor
class ConverterViewModel: ObservableObject {
    @Published var imageItems: [ImageItem] = []
    @Published var exportDocument: ConvertedImagesDocument?
    
    @Published var batchTargetFormat: ImageFormat = .jpeg {
        didSet {
            // Apply to all items that are pending or failed
            for i in imageItems.indices {
                if imageItems[i].status == .pending || isFailed(status: imageItems[i].status) {
                    imageItems[i].targetFormat = batchTargetFormat
                }
            }
        }
    }
    
    @Published var isConverting: Bool = false
    @Published var isImporting: Bool = false
    
    private var importActivityCount: Int = 0
    
    // MARK: - 统计属性
    var totalCount: Int { imageItems.count }
    
    var successCount: Int {
        imageItems.filter { $0.status == .success }.count
    }
    
    var failedCount: Int {
        imageItems.filter { isFailed(status: $0.status) }.count
    }
    
    var pendingCount: Int {
        imageItems.filter { $0.status == .pending }.count
    }
    
    var convertingCount: Int {
        imageItems.filter { $0.status == .converting }.count
    }
    
    var shareableURLs: [URL] {
        imageItems.compactMap { item in
            item.status == .success ? item.convertedFileURL : nil
        }
    }

    var successfulItems: [ImageItem] {
        imageItems.filter { $0.status == .success && $0.convertedFileURL != nil }
    }
    
    var hasSuccessItems: Bool {
        imageItems.contains { $0.status == .success }
    }
    
    var canConvert: Bool {
        !isConverting && !isImporting && !imageItems.isEmpty
    }
    
    var canSave: Bool {
        hasSuccessItems && !isConverting && !isImporting
    }
    
    // 整体转换进度 (0.0 - 1.0)
    var conversionProgress: Double {
        guard totalCount > 0 else { return 0.0 }
        let completed = successCount + failedCount
        return Double(completed) / Double(totalCount)
    }
    
    func addImage(fileURL: URL, name: String, format: String) async {
        let previewImage = await generatePreviewImage(from: fileURL)
        let newItem = ImageItem(
            originalFileURL: fileURL,
            previewImage: previewImage,
            originalName: name,
            originalFormat: format,
            targetFormat: batchTargetFormat
        )
        imageItems.append(newItem)
    }
    
    func updateTargetFormat(for itemID: UUID, to format: ImageFormat) {
        guard let index = imageItems.firstIndex(where: { $0.id == itemID }) else { return }
        imageItems[index].targetFormat = format
        // Reset status if changed
        imageItems[index].status = .pending
        
        // 删除旧的临时文件以释放空间
        if let oldURL = imageItems[index].convertedFileURL {
            try? FileManager.default.removeItem(at: oldURL)
        }
        imageItems[index].convertedFileURL = nil
    }
    
    func removeItems(at offsets: IndexSet) {
        // 清理即将删除项的临时文件
        for index in offsets {
            if let url = imageItems[index].convertedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            try? FileManager.default.removeItem(at: imageItems[index].originalFileURL)
        }
        imageItems.remove(atOffsets: offsets)
    }
    
    func removeItem(id: UUID) {
        guard let index = imageItems.firstIndex(where: { $0.id == id }) else { return }
        removeItems(at: IndexSet(integer: index))
    }
    
    func clearAll() {
        // 清理所有临时文件
        for item in imageItems {
            if let url = item.convertedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            try? FileManager.default.removeItem(at: item.originalFileURL)
        }
        imageItems.removeAll()
    }
    
    func prepareExportDocument() {
        let successItems = imageItems.filter { $0.status == .success }
        exportDocument = successItems.isEmpty ? nil : ConvertedImagesDocument(items: successItems)
    }

    func shareableURLs(for selectedItemIDs: Set<UUID>) -> [URL] {
        successfulItems.compactMap { item in
            guard selectedItemIDs.contains(item.id) else { return nil }
            return item.convertedFileURL
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
            let filename = uniqueFilename(
                baseName: item.originalName,
                fileExtension: item.targetFormat.fileExtension,
                usedFilenames: &usedFilenames,
                in: directoryURL
            )
            try FileManager.default.copyItem(at: sourceURL, to: directoryURL.appendingPathComponent(filename))
            savedCount += 1
        }

        return savedCount
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
        let newItem = ImageItem(
            originalFileURL: preview.localFileURL,
            previewImage: preview.previewImage,
            originalName: preview.displayName,
            originalFormat: preview.detectedFormat,
            targetFormat: batchTargetFormat
        )
        imageItems.append(newItem)
    }
    
    func discardRemoteImageImport(_ preview: RemoteImageImportPreview) {
        try? FileManager.default.removeItem(at: preview.localFileURL)
    }
    
    func handlePrimaryAction() async {
        await convertAll()
    }
    
    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            beginImport()
            Task { [self] in
                defer { endImport() }
                await importImages(from: urls)
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    func convertAll() async {
        isConverting = true
        defer { isConverting = false }
        
        for i in imageItems.indices {
            let item = imageItems[i]
            if item.status == .pending || isFailed(status: item.status) {
                await convertItem(at: i)
            }
        }
    }
    
    private func convertItem(at index: Int) async {
        let item = imageItems[index]
        imageItems[index].status = .converting
        
        do {
            let fileURL = try await performConversionAndSave(sourceURL: item.originalFileURL, to: item.targetFormat, originalName: item.originalName)
            imageItems[index].convertedFileURL = fileURL
            imageItems[index].status = .success
            TransferResultArchiveService.scheduleArchive(url: fileURL, category: .imageConversion)
        } catch {
            imageItems[index].status = .failed(error.localizedDescription)
        }
    }
    
    /// 将图片转换为目标格式，并直接写入到磁盘上的临时目录中，返回该文件的 URL
    private func performConversionAndSave(sourceURL: URL, to format: ImageFormat, originalName: String) async throws -> URL {
        let ext = format.fileExtension
        
        return try await Task.detached(priority: .userInitiated) {
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "\(originalName)_\(UUID().uuidString.prefix(6)).\(ext)"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            guard let image = UIImage(contentsOfFile: sourceURL.path) else {
                throw ConversionError.failedToLoadSourceImage
            }
            
            switch format {
            case .jpeg:
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    throw ConversionError.failedToGenerateData
                }
                try data.write(to: fileURL)
                
            case .png:
                guard let data = image.pngData() else {
                    throw ConversionError.failedToGenerateData
                }
                try data.write(to: fileURL)
                
            case .heic:
                guard let cgImage = image.cgImage,
                      let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.heic.identifier as CFString, 1, nil) else {
                    throw ConversionError.failedToGenerateData
                }
                
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.9
                ]
                
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                guard CGImageDestinationFinalize(destination) else {
                    throw ConversionError.failedToGenerateData
                }
                
            case .tiff:
                guard let cgImage = image.cgImage,
                      let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.tiff.identifier as CFString, 1, nil) else {
                    throw ConversionError.failedToGenerateData
                }
                
                // TIFF 通常作为无损/未压缩格式使用，保留最原始的像素数据
                // 这里的 LZW 是 TIFF 标准的一种无损压缩算法，可以略微减小极大的文件体积而不丢失任何质量
                let options: [CFString: Any] = [
                    kCGImagePropertyTIFFCompression: 5 // 5 means LZW compression
                ]
                
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                guard CGImageDestinationFinalize(destination) else {
                    throw ConversionError.failedToGenerateData
                }
            }
            
            return fileURL
        }.value
    }
    
    private func isFailed(status: ImageItem.ConversionStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }
    
    // Process selected photos from PhotosPicker
    func processPhotoSelections(_ selections: [PhotosPickerItem]) {
        guard !selections.isEmpty else { return }
        beginImport()
        
        Task { [self] in
            defer { endImport() }
            
            for selection in selections {
                do {
                    if let imageFile = try await selection.loadTransferable(type: ImageFileTransferable.self) {
                        let url = imageFile.url
                        var formatString = "未知"
                        if let contentType = selection.supportedContentTypes.first {
                            formatString = contentType.preferredFilenameExtension?.uppercased() ?? contentType.localizedDescription ?? "未知"
                        }

                        let name = URL(fileURLWithPath: imageFile.originalFilename)
                            .deletingPathExtension()
                            .lastPathComponent

                        await self.addImage(fileURL: url, name: name, format: formatString)
                    } else {
                        print("Failed to load image file.")
                    }
                } catch {
                    print("Error loading image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func importImages(from urls: [URL]) async {
        for url in urls {
            let importedImage: (tempURL: URL, name: String, format: String)? = {
                guard url.startAccessingSecurityScopedResource() else { return nil }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
                
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    let name = url.deletingPathExtension().lastPathComponent
                    let format = url.pathExtension.uppercased()
                    return (tempURL, name, format.isEmpty ? "未知" : format)
                } catch {
                    print("Import failed: \(error.localizedDescription)")
                    return nil
                }
            }()
            
            if let importedImage {
                await addImage(fileURL: importedImage.tempURL, name: importedImage.name, format: importedImage.format)
            }
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
                kCGImageSourceThumbnailMaxPixelSize: 256
            ]
            
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            
            return UIImage(cgImage: cgImage)
        }.value
    }
    
    private func beginImport() {
        importActivityCount += 1
        isImporting = importActivityCount > 0
    }
    
    private func endImport() {
        importActivityCount = max(0, importActivityCount - 1)
        isImporting = importActivityCount > 0
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
        return ext.isEmpty ? "未知" : ext.uppercased()
    }
    
    func saveToPhotoLibrary(selectedItemIDs: Set<UUID>) async -> Result<Int, Error> {
        // 请求“仅添加”权限（如果还没有）
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            return .failure(ConversionError.photoLibraryAccessDenied)
        }
        
        let successItems = successfulItems.filter { selectedItemIDs.contains($0.id) }
        var savedCount = 0
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for item in successItems {
                    guard let fileURL = item.convertedFileURL else { continue }
                    
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    // 直接使用磁盘上的临时文件进行保存，无需再占用内存复制 Data
                    creationRequest.addResource(with: .photo, fileURL: fileURL, options: nil)
                    savedCount += 1
                }
            }
            return .success(savedCount)
        } catch {
            return .failure(error)
        }
    }

    private func uniqueFilename(
        baseName: String,
        fileExtension: String,
        usedFilenames: inout Set<String>,
        in directoryURL: URL
    ) -> String {
        let sanitizedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Image" : baseName
        var candidate = "\(sanitizedBaseName).\(fileExtension)"
        var counter = 1

        while usedFilenames.contains(candidate) || FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(candidate).path) {
            candidate = "\(sanitizedBaseName)_\(counter).\(fileExtension)"
            counter += 1
        }

        usedFilenames.insert(candidate)
        return candidate
    }
}

enum ConversionError: Error, LocalizedError {
    case failedToGenerateData
    case failedToLoadSourceImage
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .failedToGenerateData: return AppLocalizer.localized("无法生成目标格式的图片数据")
        case .failedToLoadSourceImage: return AppLocalizer.localized("无法读取原始图片文件")
        case .photoLibraryAccessDenied: return AppLocalizer.localized("需要相册的“添加照片”权限才能保存图片")
        }
    }
}

enum RemoteImageImportError: LocalizedError {
    case invalidURL
    case notAnImage
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppLocalizer.localized("请输入完整且可访问的图片链接")
        case .notAnImage:
            return AppLocalizer.localized("下载结果不是可识别的图片文件")
        }
    }
}
