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
    @Environment(RouterManager.self) private var router
    @Environment(TabRouter.self) private var tabRouter
    @Environment(PurchaseManager.self) private var purchaseManager
    @StateObject private var viewModel = ConverterViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isFileImporterPresented = false
    @State private var isLinkImportPresented = false
    @State private var isFileExporterPresented = false
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    @State private var remoteImportPreview: RemoteImageImportPreview?
    @State private var isShowingPaywall = false
    
    var body: some View {
        let isBusy = viewModel.isConverting || viewModel.isImporting
        
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            LinearGradient(
                colors: [AppColors.accentBlue.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            Group {
                if viewModel.imageItems.isEmpty {
                    EmptyStateView(
                        isFileImporterPresented: $isFileImporterPresented,
                        selectedPhotos: $selectedPhotos,
                        onImportFromLink: {
                            isLinkImportPresented = true
                        }
                    )
                    .allowsHitTesting(!viewModel.isImporting)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            summaryPanel
                            listSection
                        }
                        .padding(.top, 20)
                    }
                    .allowsHitTesting(!isBusy)
                }
            }
            
            // 导入时的加载动画
            if viewModel.isImporting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text(AppLocalizer.localized("正在导入图片..."))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(AppColors.cardBackground.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                }
                .zIndex(100)
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
                            Text(AppLocalizer.localized("清空"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .allowsHitTesting(!isBusy)
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
                viewModel.handleFileImportResult(result)
            }
            .sheet(isPresented: $isLinkImportPresented) {
                ImageLinkImportSheet(
                    resolver: { urlText in
                        try await viewModel.prepareRemoteImageImport(from: urlText)
                    },
                    onResolved: { preview in
                        remoteImportPreview = preview
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
            }
            .fileExporter(
                isPresented: $isFileExporterPresented,
                document: viewModel.exportDocument,
                contentType: .folder,
                defaultFilename: "ConvertedImages"
            ) { result in
                switch result {
                case .success(let url):
                    saveMessage = AppLocalizer.formatted("已成功保存至文件：\n%@", url.lastPathComponent)
                    showSaveAlert = true
                case .failure(let error):
                    saveMessage = AppLocalizer.formatted("保存失败：\n%@", error.localizedDescription)
                    showSaveAlert = true
                }
            }
            .sheet(isPresented: $isSaveActionSheetPresented) {
                SaveActionSheetView(
                    shareableURLs: viewModel.shareableURLs,
                    onSaveToAlbum: {
                        isSaveActionSheetPresented = false
                        Task {
                            let result = await viewModel.saveToPhotoLibrary()
                            switch result {
                            case .success(let count):
                                saveMessage = AppLocalizer.formatted("成功保存 %lld 张图片到相册", count)
                                showSaveAlert = true
                            case .failure(let error):
                                saveMessage = AppLocalizer.formatted("保存到相册失败：\n%@", error.localizedDescription)
                                showSaveAlert = true
                            }
                        }
                    },
                    onSaveToFile: {
                        isSaveActionSheetPresented = false
                        viewModel.prepareExportDocument()
                        isFileExporterPresented = viewModel.exportDocument != nil
                    },
                    onOpenTransferGuide: {
                        isSaveActionSheetPresented = false
                        router.popToRoot()
                        tabRouter.select(.transfer)
                    }
                )
                .presentationDetents([.height(356)])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
            }
            .sheet(item: $remoteImportPreview) { preview in
                RemoteImageImportPreviewSheet(
                    preview: preview,
                    onImport: {
                        viewModel.confirmRemoteImageImport(preview)
                        remoteImportPreview = nil
                    },
                    onCancel: {
                        viewModel.discardRemoteImageImport(preview)
                        remoteImportPreview = nil
                    }
                )
                .presentationDetents([.height(340)]) // 稍微调高以适应多行显示
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppColors.background)
            }
        .alert("保存结果", isPresented: $showSaveAlert) {
            Button(AppLocalizer.localized("确定"), role: .cancel) {}
        } message: {
            if let message = saveMessage {
                Text(message)
            }
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            TrialPaywallView(allowsDismissal: true)
        }
    }
    
    private var summaryPanel: some View {
        VStack(spacing: 16) {
            // 状态统计和进度
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    StatItemView(title: AppLocalizer.localized("总数"), count: viewModel.totalCount, color: AppColors.textPrimary)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("待处理"), count: viewModel.pendingCount + viewModel.convertingCount, color: AppColors.accentBlue)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("成功"), count: viewModel.successCount, color: AppColors.accentGreen)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("失败"), count: viewModel.failedCount, color: AppColors.accentRed)
                }
                .padding(.vertical, 12)
                
                // 仅在有任务进行过或进行中时显示进度条
                if viewModel.totalCount > 0 && (viewModel.isConverting || viewModel.successCount > 0 || viewModel.failedCount > 0) {
                    VStack(spacing: 8) {
                        HStack {
                            Text(viewModel.isConverting ? AppLocalizer.localized("处理中") : AppLocalizer.localized("处理完成"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.isConverting ? AppColors.accentBlue : AppColors.accentGreen)
                            Spacer()
                            Text(viewModel.conversionProgress.progressText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
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
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // 统一转换选项
            VStack(spacing: 12) {
                HStack {
                    Text(AppLocalizer.localized("统一转换为"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fontWeight(.medium)
                    Spacer()
                    Picker(AppLocalizer.localized("统一转换为"), selection: $viewModel.batchTargetFormat) {
                        ForEach(ImageFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .allowsHitTesting(!viewModel.isConverting)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal)
    }
    
    private var listSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.imageItems) { item in
                ImageItemRow(
                    item: item,
                    onFormatChange: { newFormat in
                        viewModel.updateTargetFormat(for: item.id, to: newFormat)
                    },
                    onDelete: {
                        viewModel.removeItem(id: item.id)
                    }
                )
            }
        }
        .allowsHitTesting(!viewModel.isConverting)
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var bottomActionPanel: some View {
        let isConverting = viewModel.isConverting
        let isBusy = viewModel.isConverting || viewModel.isImporting
        let hasItems = !viewModel.imageItems.isEmpty
        let hasSuccessItems = viewModel.hasSuccessItems
        
        HStack(spacing: 8) {
            // 左侧操作按钮组 (使用更紧凑的间距和圆角)
            HStack(spacing: 6) {
                Button(action: {
                    isFileImporterPresented = true
                }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                
                PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                
                Button(action: {
                    isLinkImportPresented = true
                }) {
                    Image(systemName: "link")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
            
            Spacer(minLength: 4)
            
            // 右侧核心操作按钮组
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        if viewModel.isConverting {
                            await viewModel.handlePrimaryAction()
                        } else if await purchaseManager.canUseCoreFeatures() {
                            await viewModel.handlePrimaryAction()
                        } else {
                            isShowingPaywall = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        if isConverting {
                            ProgressView()
                                .tint(AppColors.textSecondary)
                                .scaleEffect(0.8)
                        }
                        Text(isConverting ? "转换中" : "转换")
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(hasItems ? .white : AppColors.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(hasItems ? AppColors.accentBlue : AppColors.secondaryBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .shadow(color: hasItems ? AppColors.accentBlue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canConvert)
                
                Button(action: {
                    isSaveActionSheetPresented = true
                }) {
                    HStack(spacing: 4) {
                        Text("保存")
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundColor(hasSuccessItems ? .white : AppColors.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(hasSuccessItems ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .shadow(color: hasSuccessItems ? AppColors.accentGreen.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSave)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.85))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 0)
        .allowsHitTesting(!viewModel.isImporting)
    }
    
}

#Preview {
    ImageConverterView()
}
