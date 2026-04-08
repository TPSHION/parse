import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PhotosUI
import Combine
import Photos

struct ImageFileTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ImageFileTransferable(url: copy)
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
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd_HHmmss"
                        let timeString = formatter.string(from: Date())
                        let randomSuffix = String(Int.random(in: 100...999))
                        let name = "IMG_\(timeString)_\(randomSuffix)"
                        
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
    
    func saveToPhotoLibrary() async -> Result<Int, Error> {
        // 请求“仅添加”权限（如果还没有）
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            return .failure(ConversionError.photoLibraryAccessDenied)
        }
        
        let successItems = imageItems.filter { $0.status == .success && $0.convertedFileURL != nil }
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
}

enum ConversionError: Error, LocalizedError {
    case failedToGenerateData
    case failedToLoadSourceImage
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .failedToGenerateData: return "无法生成目标格式的图片数据"
        case .failedToLoadSourceImage: return "无法读取原始图片文件"
        case .photoLibraryAccessDenied: return "需要相册的“添加照片”权限才能保存图片"
        }
    }
}
