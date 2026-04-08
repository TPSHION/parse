import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class PDFConverterViewModel: ObservableObject {
    @Published var pdfItems: [PDFItem] = []
    @Published var isImporting = false
    @Published var isConverting = false
    
    // 统一设置所有项的转换目标格式
    @Published var batchTargetFormat: PDFTargetFormat = .docx {
        didSet {
            for index in pdfItems.indices {
                if pdfItems[index].status == .pending || pdfItems[index].status == .failed(error: "") {
                    pdfItems[index].targetFormat = batchTargetFormat
                }
            }
        }
    }
    
    // 进度和统计
    var totalCount: Int { pdfItems.count }
    var pendingCount: Int { pdfItems.filter { $0.status == .pending }.count }
    var successCount: Int { pdfItems.filter { $0.status == .success }.count }
    var failedCount: Int {
        pdfItems.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }
    
    var canConvert: Bool {
        !pdfItems.isEmpty && !isConverting && pendingCount > 0
    }
    
    // 导入 PDF 文件
    func handleFileImportResult(_ result: Result<[URL], Error>) {
        isImporting = true
        defer { isImporting = false }
        
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                
                // 将文件拷贝到沙盒中的临时目录进行处理
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                
                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    
                    let item = PDFItem(url: tempURL)
                    self.pdfItems.append(item)
                } catch {
                    print("Failed to copy imported PDF file: \(error.localizedDescription)")
                }
                
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    // 更新单个条目的目标格式
    func updateTargetFormat(for id: UUID, to format: PDFTargetFormat) {
        if let index = pdfItems.firstIndex(where: { $0.id == id }) {
            pdfItems[index].targetFormat = format
        }
    }
    
    // 删除单个条目
    func removeItem(id: UUID) {
        pdfItems.removeAll { $0.id == id }
    }
    
    // 清空列表
    func clearAll() {
        pdfItems.removeAll()
    }
    
    // 模拟转换核心流程（占位实现）
    func startConversion() async {
        guard canConvert else { return }
        
        isConverting = true
        defer { isConverting = false }
        
        for index in pdfItems.indices where pdfItems[index].status == .pending {
            pdfItems[index].status = .converting(progress: 0.0)
            
            // 模拟转换延迟和进度
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                pdfItems[index].status = .converting(progress: Double(i) / 10.0)
            }
            
            // 占位成功状态
            pdfItems[index].status = .success
            pdfItems[index].convertedURL = pdfItems[index].url // 临时：将转换后的路径指向自身以便测试
        }
    }
}