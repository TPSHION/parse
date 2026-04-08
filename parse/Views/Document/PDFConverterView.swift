import SwiftUI
import UniformTypeIdentifiers

struct PDFConverterView: View {
    @StateObject private var viewModel = PDFConverterViewModel()
    @State private var isFileImporterPresented = false
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            LinearGradient(
                colors: [AppColors.accentPurple.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            Group {
                if viewModel.pdfItems.isEmpty {
                    EmptyStateView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            summaryPanel
                            listSection
                        }
                        .padding(.top, 20)
                    }
                    .allowsHitTesting(!viewModel.isConverting)
                }
            }
            
            if viewModel.isImporting {
                importingOverlay
            }
        }
        .navigationTitle("PDF 转换")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar) // 设置导航栏的元素为浅色(包括标题)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.pdfItems.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.clearAll() }) {
                        Text("清空")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .allowsHitTesting(!viewModel.isConverting)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !viewModel.pdfItems.isEmpty {
                bottomActionPanel
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImportResult(result)
        }
    }
    
    private var EmptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(AppColors.accentPurple)
                .padding()
                .background(Circle().fill(AppColors.accentPurple.opacity(0.1)))
            
            Text("支持 PDF 转 DOCX、TXT、PNG 等")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                isFileImporterPresented = true
            }) {
                Text("导入 PDF 文件")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(AppColors.accentPurple)
                    .clipShape(Capsule())
            }
            .padding(.top, 16)
            
            Spacer()
        }
    }
    
    private var summaryPanel: some View {
        VStack(spacing: 16) {
            // 状态统计
            HStack(spacing: 0) {
                StatItemView(title: "总数", count: viewModel.totalCount, color: AppColors.textPrimary)
                Divider().background(AppColors.secondaryBackground)
                StatItemView(title: "待处理", count: viewModel.pendingCount, color: AppColors.accentBlue)
                Divider().background(AppColors.secondaryBackground)
                StatItemView(title: "成功", count: viewModel.successCount, color: AppColors.accentGreen)
                Divider().background(AppColors.secondaryBackground)
                StatItemView(title: "失败", count: viewModel.failedCount, color: AppColors.accentRed)
            }
            .padding(.vertical, 12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // 统一转换选项
            VStack(spacing: 12) {
                HStack {
                    Text("统一转换为")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("统一转换为", selection: $viewModel.batchTargetFormat) {
                        ForEach(PDFTargetFormat.allCases) { format in
                            // 对于 Segmented Picker，字数较长时可以使用较小的字体或缩小比例
                            Text(format.rawValue)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    // 使用动态缩放确保在小屏幕上也能完整显示
                    .frame(maxWidth: 240)
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
            ForEach(viewModel.pdfItems) { item in
                PDFItemRow(
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
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var bottomActionPanel: some View {
        HStack(spacing: 12) {
            Button(action: {
                isFileImporterPresented = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isConverting)
            
            Button(action: {
                Task {
                    await viewModel.startConversion()
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
                    Text(viewModel.isConverting ? "转换中" : "开始转换")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(viewModel.canConvert ? AppColors.accentPurple : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: viewModel.canConvert ? AppColors.accentPurple.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canConvert)
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
    
    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("正在导入 PDF...").font(.system(size: 15, weight: .medium)).foregroundColor(.white)
            }
            .padding(32)
            .background(AppColors.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .zIndex(100)
    }
}

#Preview {
    NavigationStack {
        PDFConverterView()
    }
}