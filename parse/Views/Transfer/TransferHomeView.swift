import SwiftUI
import UniformTypeIdentifiers
import UIKit
import CoreImage.CIFilterBuiltins

struct TransferHomeView: View {
    @StateObject private var service = LocalTransferService()
    @State private var isFileImporterPresented = false
    @State private var showCopiedConfirmation = false
    @State private var isQRCodePresented = false

    var body: some View {
        ZStack {
            AppShellBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if service.isRunning {
                        runningHeaderSection

                        if service.isClientConnected {
                            filesSection
                        } else {
                            waitingConnectionCard
                        }
                    } else {
                        idleHeaderSection
                        idleEmptyState
                    }
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: service.isClientConnected) { _, isConnected in
            if isConnected {
                isQRCodePresented = false
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                service.importFiles(from: urls)
            case .failure(let error):
                service.presentError(AppLocalizer.formatted("选择文件失败：%@", error.localizedDescription))
            }
        }
        .alert(AppLocalizer.localized("地址已复制"), isPresented: $showCopiedConfirmation) {
            Button(AppLocalizer.localized("好的"), role: .cancel) {}
        } message: {
            Text(service.accessAddressText)
        }
        .alert(
            AppLocalizer.localized("传输提示"),
            isPresented: Binding(
                get: { service.lastErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        service.clearError()
                    }
                }
            )
        ) {
            Button(AppLocalizer.localized("知道了"), role: .cancel) {
                service.clearError()
            }
        } message: {
            Text(service.lastErrorMessage ?? "")
        }
        .sheet(isPresented: $isQRCodePresented) {
            TransferQRCodeSheet(
                address: service.accessAddressText,
                accessCode: service.accessCodeText
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.background)
        }
    }

    private var idleHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parse Transfer")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.accentGreen)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(AppLocalizer.localized("局域网传输"))
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)

            Text(AppLocalizer.localized("同网设备可直接访问共享文件。"))
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var idleEmptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(AppColors.accentGreen)

                Text(AppLocalizer.localized("服务尚未启动"))
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("启动后会生成访问地址，同网设备可在浏览器中上传和下载文件。"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalizer.localized("请确保手机与访问设备连接到同一个 Wi‑Fi，否则将无法建立传输连接。"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.accentOrange)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppLocalizer.localized("首次启动时，系统可能会请求本地网络权限。"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppLocalizer.localized("若地址无法访问，请到系统设置检查权限。"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(AppColors.secondaryBackground.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                Button(action: service.startServer) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(AppLocalizer.localized("启动服务"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(AppColors.accentGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    openAppSettings()
                } label: {
                    actionChip(
                        icon: "gearshape.fill",
                        title: AppLocalizer.localized("前往设置"),
                        accent: AppColors.accentOrange
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var runningHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                statusPill(
                    title: service.isClientConnected ? AppLocalizer.localized("已连接") : AppLocalizer.localized("等待连接"),
                    color: service.isClientConnected ? AppColors.accentGreen : AppColors.accentBlue
                )

                Spacer(minLength: 8)

                Button {
                    UIPasteboard.general.string = service.accessAddressText
                    showCopiedConfirmation = true
                } label: {
                    compactIconButton(icon: "doc.on.doc")
                }
                .buttonStyle(.plain)

                Button {
                    isQRCodePresented = true
                } label: {
                    compactIconButton(icon: "qrcode")
                }
                .buttonStyle(.plain)

                Button {
                    openAppSettings()
                } label: {
                    compactIconButton(icon: "gearshape.fill")
                }
                .buttonStyle(.plain)

                Button(action: service.stopServer) {
                    compactIconButton(icon: "power")
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppLocalizer.localized("访问地址"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(service.accessAddressText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppLocalizer.localized("配对码"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(service.accessCodeText)
                    .font(.system(.title3, design: .monospaced).weight(.heavy))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("网页首次访问需输入此 6 位配对码。"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var waitingConnectionCard: some View {
        VStack(spacing: 16) {
            WaitingConnectionIndicator()

            VStack(spacing: 8) {
                Text(AppLocalizer.localized("服务已启动，等待设备连接"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("请在电脑浏览器打开上方地址，并输入本机显示的配对码。"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppLocalizer.localized("请确保手机与访问设备连接到同一个 Wi‑Fi，否则将无法建立传输连接。"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.accentOrange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                isFileImporterPresented = true
            } label: {
                actionChip(
                    icon: "plus.circle.fill",
                    title: AppLocalizer.localized("导入文件"),
                    accent: AppColors.accentGreen
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalizer.localized("共享文件"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(AppLocalizer.localized("浏览器上传的文件会显示在这里，也可从本机导入。"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    isFileImporterPresented = true
                } label: {
                    actionChip(
                        icon: "plus.circle.fill",
                        title: AppLocalizer.localized("导入文件"),
                        accent: AppColors.accentGreen
                    )
                }
                .buttonStyle(.plain)
            }

            if service.files.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)

                    Text(AppLocalizer.localized("共享目录里还没有文件"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(AppLocalizer.localized("先从 App 导入文件，或在浏览器端上传。"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 20)
                .background(AppColors.cardBackground.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(service.files) { file in
                        TransferFileRow(file: file) {
                            service.deleteFile(file)
                        }
                    }
                }
            }
        }
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func actionChip(icon: String, title: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))

            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(accent.opacity(0.9))
        .clipShape(Capsule())
    }

    private func compactIconButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(AppColors.secondaryBackground.opacity(0.48))
            .clipShape(Circle())
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

private struct TransferFileRow: View {
    let file: TransferSharedFile
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.accentBlue.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(file.filename)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text("\(file.fileSizeText) · \(file.modifiedAtText)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.accentRed)
                    .padding(12)
                    .background(AppColors.accentRed.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    TransferHomeView()
}

private struct WaitingConnectionIndicator: View {
    @State private var animateOuterRing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.accentBlue.opacity(0.16))
                .frame(width: 72, height: 72)
                .scaleEffect(animateOuterRing ? 1.2 : 0.78)
                .opacity(animateOuterRing ? 0.18 : 0.72)

            Circle()
                .fill(AppColors.accentBlue)
                .frame(width: 22, height: 22)
                .shadow(color: AppColors.accentBlue.opacity(0.45), radius: 12, x: 0, y: 0)
        }
        .frame(height: 84)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animateOuterRing = true
            }
        }
    }
}

private struct TransferQRCodeSheet: View {
    let address: String
    let accessCode: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack(spacing: 20) {
            Text(AppLocalizer.localized("二维码连接"))
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)

            Text(AppLocalizer.localized("用另一台设备扫码打开传输页面，连接成功后会自动关闭。"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            qrCodeCard

            VStack(alignment: .leading, spacing: 12) {
                infoRow(title: AppLocalizer.localized("访问地址"), value: address)
                infoRow(title: AppLocalizer.localized("配对码"), value: accessCode)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(AppColors.background)
    }

    private var qrCodeCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)

            if let qrImage = qrCodeImage(from: address) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.black.opacity(0.72))

                    Text(address)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .textSelection(.enabled)
        }
    }

    private func qrCodeImage(from value: String) -> UIImage? {
        let data = Data(value.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let transform = CGAffineTransform(scaleX: 12, y: 12)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
