import Foundation
import ffmpegkit

enum FFmpegAudioConversionError: LocalizedError {
    case unsupportedRemux
    case sessionUnavailable
    case conversionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedRemux:
            return AppLocalizer.localized("当前格式组合不支持快速封装")
        case .sessionUnavailable:
            return AppLocalizer.localized("FFmpeg 转换会话创建失败")
        case .conversionFailed(let message):
            return message
        }
    }
}

struct FFmpegAudioConversionService {
    func remux(
        inputURL: URL,
        outputURL: URL,
        sourceFormat: String,
        targetFormat: AudioFormat
    ) async throws {
        let command = try buildRemuxCommand(
            inputURL: inputURL,
            outputURL: outputURL,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat
        )
        try await execute(command, outputURL: outputURL)
    }
    
    func transcode(
        inputURL: URL,
        outputURL: URL,
        targetFormat: AudioFormat,
        mode: AudioConversionMode,
        duration: Double?,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        let command = buildTranscodeCommand(
            inputURL: inputURL,
            outputURL: outputURL,
            targetFormat: targetFormat,
            mode: mode
        )
        try await execute(command, outputURL: outputURL, duration: duration, progressHandler: progressHandler)
    }
    
    private func buildRemuxCommand(
        inputURL: URL,
        outputURL: URL,
        sourceFormat: String,
        targetFormat: AudioFormat
    ) throws -> String {
        let inputPath = inputURL.path
        let outputPath = outputURL.path
        let normalizedSource = sourceFormat.lowercased()
        
        switch (normalizedSource, targetFormat) {
        case ("aac", .m4a):
            return "-i \"\(inputPath)\" -map 0:a:0 -vn -c copy -bsf:a aac_adtstoasc -movflags +faststart -y \"\(outputPath)\""
        case ("m4a", .aac):
            return "-i \"\(inputPath)\" -map 0:a:0 -vn -c copy -f adts -y \"\(outputPath)\""
        default:
            throw FFmpegAudioConversionError.unsupportedRemux
        }
    }
    
    private func buildTranscodeCommand(
        inputURL: URL,
        outputURL: URL,
        targetFormat: AudioFormat,
        mode: AudioConversionMode
    ) -> String {
        let inputPath = inputURL.path
        let outputPath = outputURL.path
        let sharedPrefix = "-i \"\(inputPath)\" -map 0:a:0 -vn -map_metadata 0 "
        
        let codecArguments: String
        switch targetFormat {
        case .mp3:
            codecArguments = mode == .quality
                ? "-c:a libmp3lame -q:a 2 "
                : "-c:a libmp3lame -b:a 128k -ar 44100 "
        case .wav:
            codecArguments = mode == .quality
                ? "-c:a pcm_s24le "
                : "-c:a pcm_s16le -ar 44100 "
        case .aac:
            codecArguments = mode == .quality
                ? "-c:a aac -b:a 256k -f adts "
                : "-c:a aac -b:a 128k -ar 44100 -f adts "
        case .m4a:
            codecArguments = mode == .quality
                ? "-c:a aac -b:a 256k -movflags +faststart "
                : "-c:a aac -b:a 128k -ar 44100 -movflags +faststart "
        case .flac:
            codecArguments = mode == .quality
                ? "-c:a flac -compression_level 5 "
                : "-c:a flac -compression_level 0 -sample_fmt s16 "
        }
        
        return "\(sharedPrefix)\(codecArguments)-y \"\(outputPath)\""
    }
    
    private func execute(
        _ command: String,
        outputURL: URL,
        duration: Double? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session else {
                    continuation.resume(throwing: FFmpegAudioConversionError.sessionUnavailable)
                    return
                }
                
                let returnCode = session.getReturnCode()
                if ReturnCode.isSuccess(returnCode) {
                    continuation.resume(returning: ())
                    return
                }
                
                try? FileManager.default.removeItem(at: outputURL)
                let logs = session.getAllLogsAsString() ?? ""
                let stackTrace = session.getFailStackTrace() ?? ""
                let message = self.extractFriendlyErrorMessage(from: logs, stackTrace: stackTrace)
                continuation.resume(throwing: FFmpegAudioConversionError.conversionFailed(message))
            }, withLogCallback: nil, withStatisticsCallback: { statistics in
                guard
                    let statistics,
                    let duration,
                    duration > 0
                else {
                    return
                }
                
                let timeInMilliseconds = Double(statistics.getTime())
                guard timeInMilliseconds > 0 else { return }
                let progress = min(max(timeInMilliseconds / (duration * 1000.0), 0.0), 0.99)
                progressHandler?(progress)
            })
        }
    }
    
    private func extractFriendlyErrorMessage(from logs: String, stackTrace: String) -> String {
        let lowercasedLogs = logs.lowercased()
        
        if lowercasedLogs.contains("no such file or directory") {
            return AppLocalizer.localized("源音频文件不存在或已被移除")
        }
        if lowercasedLogs.contains("permission denied") {
            return AppLocalizer.localized("没有读取或写入该音频文件的权限")
        }
        if lowercasedLogs.contains("invalid data found") || lowercasedLogs.contains("moov atom not found") {
            return AppLocalizer.localized("音频文件已损坏或内容不完整")
        }
        if lowercasedLogs.contains("unknown encoder") {
            return AppLocalizer.localized("当前设备上的音频编码器不可用")
        }
        if lowercasedLogs.contains("unsupported codec") || lowercasedLogs.contains("unknown decoder") {
            return AppLocalizer.localized("不支持的源音频编码格式")
        }
        if lowercasedLogs.contains("error initializing output stream") || lowercasedLogs.contains("could not write header") {
            return AppLocalizer.localized("目标音频格式封装失败，请尝试更换输出格式")
        }
        if lowercasedLogs.contains("no space left on device") {
            return AppLocalizer.localized("设备存储空间不足")
        }
        
        let candidates = (logs + "\n" + stackTrace)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for line in candidates.reversed() {
            let lowercasedLine = line.lowercased()
            if lowercasedLine.contains("error")
                || lowercasedLine.contains("failed")
                || lowercasedLine.contains("unsupported")
                || lowercasedLine.contains("unknown")
                || lowercasedLine.contains("invalid")
                || lowercasedLine.contains("denied") {
                return AppLocalizer.formatted("转换失败：%@", line)
            }
        }
        
        return AppLocalizer.localized("转换失败，可能是不支持的特殊音频格式")
    }
}
