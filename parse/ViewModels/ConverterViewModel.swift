import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import PhotosUI
import Combine
import Photos

@MainActor
class ConverterViewModel: ObservableObject {
    @Published var imageItems: [ImageItem] = []
    
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
    
    // 整体转换进度 (0.0 - 1.0)
    var conversionProgress: Double {
        guard totalCount > 0 else { return 0.0 }
        let completed = successCount + failedCount
        return Double(completed) / Double(totalCount)
    }
    
    func addImage(image: UIImage, name: String, format: String) {
        let newItem = ImageItem(
            originalImage: image,
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
        }
        imageItems.remove(atOffsets: offsets)
    }
    
    func clearAll() {
        // 清理所有临时文件
        for item in imageItems {
            if let url = item.convertedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        imageItems.removeAll()
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
            let fileURL = try await performConversionAndSave(image: item.originalImage, to: item.targetFormat, originalName: item.originalName)
            imageItems[index].convertedFileURL = fileURL
            imageItems[index].status = .success
        } catch {
            imageItems[index].status = .failed(error.localizedDescription)
        }
    }
    
    /// 将图片转换为目标格式，并直接写入到磁盘上的临时目录中，返回该文件的 URL
    private func performConversionAndSave(image: UIImage, to format: ImageFormat, originalName: String) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let tempDirectory = FileManager.default.temporaryDirectory
            let ext = format.fileExtension
            let fileName = "\(originalName)_\(UUID().uuidString.prefix(6)).\(ext)"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
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
        for selection in selections {
            // 在 iOS 16+ 中，PhotosPickerItem 提取原文件名比较特殊，
            // 它没有直接的 filename 属性，也不能直接调用 loadFileRepresentation(for:)。
            // 我们可以通过 loadTransferable 获取数据，并通过其它方式尽可能推断文件名。
            // 实际的 PHAsset 文件名需要访问权限，这里为了兼容性和不需要额外权限，
            // 我们可以尝试解析 Transferable 中的文件名，或者生成更具辨识度的名字。
            
            selection.loadTransferable(type: Data.self) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data?):
                        if let image = UIImage(data: data) {
                            var formatString = "未知"
                            if let contentType = selection.supportedContentTypes.first {
                                formatString = contentType.preferredFilenameExtension?.uppercased() ?? contentType.localizedDescription ?? "未知"
                            }
                            
                            // 由于 PhotosPickerItem 不提供文件名，为了让名称更有意义，
                            // 这里我们利用当前时间戳来生成一个格式化的名称，而不是随机的 UUID，
                            // 这样对于用户来说名称（如 "IMG_20260407_1455.PNG"）会更加直观合理。
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyyMMdd_HHmmss"
                            let timeString = formatter.string(from: Date())
                            
                            // 加上一个短随机数防止同一秒内多张图片重名
                            let randomSuffix = String(Int.random(in: 100...999))
                            let name = "IMG_\(timeString)_\(randomSuffix)"
                            
                            self?.addImage(image: image, name: name, format: formatString)
                        }
                    case .success(nil):
                        print("Failed to load image data.")
                    case .failure(let error):
                        print("Error loading image: \(error.localizedDescription)")
                    }
                }
            }
        }
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
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .failedToGenerateData: return "无法生成目标格式的图片数据"
        case .photoLibraryAccessDenied: return "需要相册的“添加照片”权限才能保存图片"
        }
    }
}
