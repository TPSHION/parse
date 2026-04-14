# FFmpeg Compliance Notes

## 中文

本文档用于记录本项目当前的 `ffmpeg-kit` / FFmpeg 集成方式，并作为发布前自查说明使用。  
它不是法律意见，也不替代正式法务审核。

### 当前集成信息

- 依赖名称：`ffmpeg-kit-ios-full`
- 当前版本：`6.0`
- 当前仓库内固定配置：
  - [Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json](./Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json)
- 当前许可证标识：
  - `LGPL-3.0`
- 当前二进制来源：
  - `https://www.wity.jp/ffmpegkit/v6.0/ffmpeg-kit-full-6.0-ios-xcframework.zip`
- 上游项目主页：
  - [ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit)
- FFmpeg 官方法律与合规说明：
  - [FFmpeg License and Legal Considerations](https://ffmpeg.org/legal.html)

### 当前仓库已经做的事情

- 已从 GPL 变体切换到 `LGPL-3.0` 依赖
- 已在仓库中固定 podspec，避免误切回 GPL 变体
- 已保留三方依赖许可证文本路径与 notices 文档

### 发布前建议检查项

- 在 App 内提供清晰的“开源许可 / Acknowledgements”入口
- 明确说明应用使用了 FFmpeg / `ffmpeg-kit`
- 随应用分发或官网支持页提供对应许可证文本
- 提供与所分发二进制相对应的源码获取方式与构建来源说明
- 如果存在自定义 EULA / 服务条款，避免加入与 LGPL 冲突的限制性表述
  - 例如不恰当地全面禁止 reverse engineering
- 核对实际启用的编解码能力与目标市场的专利风险

### 说明

- 本项目根目录的 [LICENSE](./LICENSE) 是项目原创源码的 MIT 许可证，不会改变 `ffmpeg-kit` / FFmpeg 的原始许可证。
- 第三方部分仍需按各自许可证分别合规。

## English

This document records the current `ffmpeg-kit` / FFmpeg integration used by the project and serves as a release-time checklist.  
It is not legal advice and should not replace formal legal review.

### Current Integration

- Dependency: `ffmpeg-kit-ios-full`
- Version: `6.0`
- Vendored configuration in this repository:
  - [Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json](./Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json)
- Declared license:
  - `LGPL-3.0`
- Current binary source:
  - `https://www.wity.jp/ffmpegkit/v6.0/ffmpeg-kit-full-6.0-ios-xcframework.zip`
- Upstream project:
  - [ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit)
- FFmpeg legal reference:
  - [FFmpeg License and Legal Considerations](https://ffmpeg.org/legal.html)

### What Has Already Been Done

- The project has been moved away from a GPL-enabled variant to an `LGPL-3.0` dependency
- The podspec is pinned inside the repository to avoid accidental drift back to a GPL variant
- License-text locations and notices files are documented in the repository

### Recommended Pre-Release Checklist

- Provide a clear in-app "Open Source Licenses" or acknowledgements entry
- Clearly state that the app uses FFmpeg / `ffmpeg-kit`
- Ship or link to the relevant license texts
- Provide a way for recipients to obtain the corresponding source and build provenance for the distributed binary
- Review any custom EULA / terms to avoid statements that may conflict with LGPL obligations
  - For example, a blanket ban on reverse engineering
- Review codec and patent exposure for the markets where the app is distributed

### Notes

- The root [LICENSE](./LICENSE) file covers this project's original source code under MIT and does not alter the original license of `ffmpeg-kit` / FFmpeg.
- Third-party components must still be handled according to their own licenses.
