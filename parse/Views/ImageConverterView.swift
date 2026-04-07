//
//  ContentView.swift
//  parse
//
//  Created by chen on 2026/4/7.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImageConverterView: View {
    @StateObject private var viewModel = ConverterViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isFileImporterPresented = false
    @State private var isFileExporterPresented = false
    @State private var exportDocument: ConvertedImagesDocument?
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    
    private var shareableURLs: [URL] {
        viewModel.imageItems.compactMap { item in
            if item.status == .success {
                return item.convertedFileURL
            }
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            Group {
                    if viewModel.imageItems.isEmpty {
                        EmptyStateView(
                            isFileImporterPresented: $isFileImporterPresented,
                            selectedPhotos: $selectedPhotos
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                // 统一转换头部面板和统计栏
                                VStack(spacing: 16) {
                                    // 状态统计和进度
                                    VStack(spacing: 0) {
                                        HStack(spacing: 0) {
                                            StatItemView(title: "总数", count: viewModel.totalCount, color: AppColors.textPrimary)
                                            Divider().background(AppColors.secondaryBackground)
                                            StatItemView(title: "待处理", count: viewModel.pendingCount + viewModel.convertingCount, color: AppColors.accentBlue)
                                            Divider().background(AppColors.secondaryBackground)
                                            StatItemView(title: "成功", count: viewModel.successCount, color: AppColors.accentGreen)
                                            Divider().background(AppColors.secondaryBackground)
                                            StatItemView(title: "失败", count: viewModel.failedCount, color: AppColors.accentRed)
                                        }
                                        .padding(.vertical, 12)
                                        
                                        // 仅在有任务进行过或进行中时显示进度条
                                        if viewModel.totalCount > 0 && (viewModel.isConverting || viewModel.successCount > 0 || viewModel.failedCount > 0) {
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    Rectangle()
                                                        .fill(AppColors.secondaryBackground.opacity(0.5))
                                                        .frame(height: 4)
                                                    
                                                    Rectangle()
                                                        .fill(viewModel.isConverting ? AppColors.accentBlue : AppColors.accentGreen)
                                                        .frame(width: geometry.size.width * CGFloat(viewModel.conversionProgress), height: 4)
                                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.conversionProgress)
                                                        .animation(.easeInOut(duration: 0.3), value: viewModel.isConverting)
                                                }
                                            }
                                            .frame(height: 4)
                                        }
                                    }
                                    .background(AppColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    
                                    // 统一转换选项
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("统一转换为")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                            .fontWeight(.medium)
                                            
                                        Picker("统一转换为", selection: $viewModel.batchTargetFormat) {
                                            ForEach(ImageFormat.allCases) { format in
                                                Text(format.rawValue).tag(format)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .disabled(viewModel.isConverting)
                                    }
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .padding(.horizontal)
                                
                                // 图片列表
                                VStack(spacing: 12) {
                                    ForEach(viewModel.imageItems) { item in
                                        ImageItemRow(
                                            item: item,
                                            batchTargetFormat: $viewModel.batchTargetFormat,
                                            onFormatChange: { newFormat in
                                                viewModel.updateTargetFormat(for: item.id, to: newFormat)
                                            },
                                            onDelete: {
                                                if let index = viewModel.imageItems.firstIndex(where: { $0.id == item.id }) {
                                                    viewModel.removeItems(at: IndexSet(integer: index))
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 100) // 为底部悬浮按钮留出空间
                            }
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationTitle("图片格式转换")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if !viewModel.imageItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { viewModel.clearAll() }) {
                            Text("清空")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .disabled(viewModel.isConverting)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !viewModel.imageItems.isEmpty {
                    bottomActionPanel
                }
            }
            .onChange(of: selectedPhotos) { _, newPhotos in
                viewModel.processPhotoSelections(newPhotos)
                selectedPhotos.removeAll() // Clear selection after processing
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                handleFileImporterResult(result)
            }
            .fileExporter(
                isPresented: $isFileExporterPresented,
                document: exportDocument,
                contentType: .folder,
                defaultFilename: "ConvertedImages"
            ) { result in
                switch result {
                case .success(let url):
                    saveMessage = "已成功保存至文件：\n\(url.lastPathComponent)"
                    showSaveAlert = true
                case .failure(let error):
                    saveMessage = "保存失败：\n\(error.localizedDescription)"
                    showSaveAlert = true
                }
            }
            .sheet(isPresented: $isSaveActionSheetPresented) {
                SaveActionSheetView(
                    shareableURLs: shareableURLs,
                    onSaveToAlbum: {
                        isSaveActionSheetPresented = false
                        Task {
                            let result = await viewModel.saveToPhotoLibrary()
                            switch result {
                            case .success(let count):
                                saveMessage = "成功保存 \(count) 张图片到相册"
                                showSaveAlert = true
                            case .failure(let error):
                                saveMessage = "保存到相册失败：\n\(error.localizedDescription)"
                                showSaveAlert = true
                            }
                        }
                    },
                    onSaveToFile: {
                        isSaveActionSheetPresented = false
                        exportConvertedImages()
                    }
                )
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
            }
        .alert("保存结果", isPresented: $showSaveAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            if let message = saveMessage {
                Text(message)
            }
        }
    }
    
    @ViewBuilder
    private var bottomActionPanel: some View {
        let hasSuccessItems = viewModel.imageItems.contains { $0.status == .success }
        let canConvert = !viewModel.isConverting && !viewModel.imageItems.isEmpty
        let canSave = hasSuccessItems && !viewModel.isConverting
        
        HStack(spacing: 12) {
            Button(action: {
                isFileImporterPresented = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isConverting ? AppColors.textSecondary.opacity(0.5) : AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(viewModel.isConverting ? 0.3 : 0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isConverting)
            
            PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isConverting ? AppColors.textSecondary.opacity(0.5) : AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(viewModel.isConverting ? 0.3 : 0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isConverting)
            
            Button(action: {
                Task {
                    await viewModel.convertAll()
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isConverting {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(viewModel.isConverting ? "转换中" : "转换")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(canConvert ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(canConvert ? AppColors.accentBlue : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: canConvert ? AppColors.accentBlue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canConvert)
            
            Button(action: {
                isSaveActionSheetPresented = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    Text("保存")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(canSave ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(canSave ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: canSave ? AppColors.accentGreen.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.85))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 0)
    }
    
    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let name = url.deletingPathExtension().lastPathComponent
                    let format = url.pathExtension.uppercased()
                    viewModel.addImage(image: image, name: name, format: format.isEmpty ? "未知" : format)
                }
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func exportConvertedImages() {
        // Zip document logic to be implemented, or save to Photo Library
        let successItems = viewModel.imageItems.filter { $0.status == .success }
        exportDocument = ConvertedImagesDocument(items: successItems)
        isFileExporterPresented = true
    }
}

struct StatItemView: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SaveActionSheetView: View {
    let shareableURLs: [URL]
    let onSaveToAlbum: () -> Void
    let onSaveToFile: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择操作方式")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 10)
            
            VStack(spacing: 12) {
                // 分享按钮（利用 SwiftUI 的原生 ShareLink）
                if !shareableURLs.isEmpty {
                    ShareLink(items: shareableURLs) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                            Text("分享图片")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onSaveToAlbum) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20))
                        Text("保存到相册")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: onSaveToFile) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 20))
                        Text("保存为文件")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

#Preview {
    ImageConverterView()
}
