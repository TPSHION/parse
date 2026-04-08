import Foundation

enum AudioConversionEngine {
    case directCopy
    case nativeM4AExport
    case ffmpegRemux
    case ffmpegTranscode
}

struct AudioConversionPlan {
    let engine: AudioConversionEngine
    let stageLabel: String
}

struct AudioConversionPlanner {
    func makePlan(for item: AudioItem, mode: AudioConversionMode) -> AudioConversionPlan {
        let sourceFormat = normalize(item.originalFormat)
        let targetFormat = item.targetFormat.fileExtension
        
        if sourceFormat == targetFormat {
            return AudioConversionPlan(engine: .directCopy, stageLabel: "同格式快速复制")
        }
        
        if sourceFormat == "aac", item.targetFormat == .m4a {
            return AudioConversionPlan(engine: .ffmpegRemux, stageLabel: "AAC 快速封装")
        }
        
        if sourceFormat == "m4a", item.targetFormat == .aac {
            return AudioConversionPlan(engine: .ffmpegRemux, stageLabel: "AAC 轨提取")
        }
        
        if item.targetFormat == .m4a, canUseNativeM4AExport(for: sourceFormat) {
            let stageLabel = mode == .speed ? "系统快速导出" : "系统高质量导出"
            return AudioConversionPlan(engine: .nativeM4AExport, stageLabel: stageLabel)
        }
        
        let stageLabel = mode == .speed ? "快速转码" : "高质量转码"
        return AudioConversionPlan(engine: .ffmpegTranscode, stageLabel: stageLabel)
    }
    
    private func canUseNativeM4AExport(for sourceFormat: String) -> Bool {
        let nativeFriendlyFormats = ["wav", "aif", "aiff", "caf", "mp3", "m4a", "mp4", "mov"]
        return nativeFriendlyFormats.contains(sourceFormat)
    }
    
    private func normalize(_ format: String) -> String {
        format.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
