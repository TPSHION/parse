import Foundation
import ZIPFoundation

struct EPUBBookContent {
    let title: String
    let plainText: String
}

struct EPUBCoverAsset {
    let data: Data
    let fileExtension: String
}

enum EPUBConversionError: LocalizedError {
    case invalidArchive
    case missingContainer
    case missingPackageDocument
    case missingSpine
    case emptyContent
    case failedToReadArchiveEntry
    case unsupportedSourceFormat
    case unsupportedTargetFormat

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return AppLocalizer.localized("EPUB 文件结构无效")
        case .missingContainer:
            return AppLocalizer.localized("未找到 EPUB 内容清单")
        case .missingPackageDocument:
            return AppLocalizer.localized("未找到 EPUB 包信息")
        case .missingSpine:
            return AppLocalizer.localized("未找到 EPUB 阅读顺序")
        case .emptyContent:
            return AppLocalizer.localized("电子书内容为空或暂不支持解析")
        case .failedToReadArchiveEntry:
            return AppLocalizer.localized("EPUB 文件读取失败")
        case .unsupportedSourceFormat:
            return AppLocalizer.localized("当前版本暂不支持解析该电子书格式")
        case .unsupportedTargetFormat:
            return AppLocalizer.localized("当前版本暂不支持导出为该电子书格式")
        }
    }
}

enum EPUBConversionService {
    nonisolated static func extractContent(from fileURL: URL) throws -> EPUBBookContent {
        let (archive, rootPath, package) = try loadPackage(from: fileURL)
        let spinePaths = package.spine.compactMap { itemID -> String? in
            guard let manifestItem = package.manifest[itemID] else { return nil }
            return resolveArchivePath(base: rootPath, relative: manifestItem.href)
        }

        guard !spinePaths.isEmpty else {
            throw EPUBConversionError.missingSpine
        }

        let chapterTexts = try spinePaths.compactMap { path -> String? in
            guard let chapterData = try readData(at: path, from: archive) else {
                return nil
            }
            let plainText = extractPlainText(fromHTMLData: chapterData)
            let cleanedText = normalizeText(plainText)
            return cleanedText.isEmpty ? nil : cleanedText
        }

        let mergedText = chapterTexts.joined(separator: "\n\n")
        let finalText = normalizeText(mergedText)

        guard !finalText.isEmpty else {
            throw EPUBConversionError.emptyContent
        }

        return EPUBBookContent(
            title: package.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? fileURL.deletingPathExtension().lastPathComponent,
            plainText: finalText
        )
    }

    nonisolated static func extractCover(from fileURL: URL) throws -> EPUBCoverAsset? {
        let (archive, rootPath, package) = try loadPackage(from: fileURL)

        let coverItem = resolveCoverItem(in: package)
        guard let coverItem else { return nil }

        let coverPath = resolveArchivePath(base: rootPath, relative: coverItem.href)
        guard let coverData = try readData(at: coverPath, from: archive), !coverData.isEmpty else {
            return nil
        }

        let inferredExtension = normalizedImageExtension(
            pathExtension: URL(fileURLWithPath: coverItem.href).pathExtension,
            mediaType: coverItem.mediaType
        )

        return EPUBCoverAsset(data: coverData, fileExtension: inferredExtension)
    }

    nonisolated private static func loadPackage(from fileURL: URL) throws -> (Archive, String, EPUBPackageDocument) {
        let archive: Archive
        do {
            archive = try Archive(url: fileURL, accessMode: .read)
        } catch {
            throw EPUBConversionError.invalidArchive
        }

        guard
            let containerData = try readData(at: "META-INF/container.xml", from: archive),
            let rootPath = parseRootPath(from: containerData)
        else {
            throw EPUBConversionError.missingContainer
        }

        guard let packageData = try readData(at: rootPath, from: archive) else {
            throw EPUBConversionError.missingPackageDocument
        }

        return (archive, rootPath, parsePackage(from: packageData))
    }

    nonisolated private static func readData(at path: String, from archive: Archive) throws -> Data? {
        let normalizedPath = normalizeArchivePath(path)
        guard let entry = archive[normalizedPath] else { return nil }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    nonisolated private static func normalizeArchivePath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    nonisolated private static func resolveArchivePath(base rootPath: String, relative href: String) -> String {
        let cleanHref = href.components(separatedBy: "#").first ?? href
        let baseDirectory = (rootPath as NSString).deletingLastPathComponent
        let combined = baseDirectory.isEmpty
            ? cleanHref
            : (baseDirectory as NSString).appendingPathComponent(cleanHref)
        return normalizeArchivePath(combined)
    }

    nonisolated private static func extractPlainText(fromHTMLData data: Data) -> String {
        if let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            return attributed.string
        }

        let rawHTML = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let withoutTags = rawHTML.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        return withoutTags
    }

    nonisolated private static func normalizeText(_ text: String) -> String {
        let trimmedLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var normalizedLines: [String] = []
        var previousWasEmpty = false

        for line in trimmedLines {
            let isEmpty = line.isEmpty
            if isEmpty {
                if !previousWasEmpty {
                    normalizedLines.append("")
                }
            } else {
                normalizedLines.append(line)
            }
            previousWasEmpty = isEmpty
        }

        return normalizedLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func extractTextFileContent(from fileURL: URL) throws -> EPUBBookContent {
        let data = try Data(contentsOf: fileURL)
        let plainText = decodeText(from: data)
        let normalized = normalizeText(plainText)
        guard !normalized.isEmpty else {
            throw EPUBConversionError.emptyContent
        }

        return EPUBBookContent(
            title: fileURL.deletingPathExtension().lastPathComponent,
            plainText: normalized
        )
    }

    nonisolated static func writeEPUB(content: EPUBBookContent, to fileURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        let archive = try Archive(url: fileURL, accessMode: .create)
        let title = escapeXML(content.title.isEmpty ? "Untitled" : content.title)
        let body = content.plainText
            .components(separatedBy: .newlines)
            .map { line -> String in
                let escaped = escapeXML(line)
                return escaped.isEmpty ? "<p>&#160;</p>" : "<p>\(escaped)</p>"
            }
            .joined(separator: "\n")

        let files: [(String, Data, Bool)] = [
            ("mimetype", Data("application/epub+zip".utf8), true),
            ("META-INF/container.xml", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """.utf8), false),
            ("OEBPS/content.opf", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <package version="3.0" unique-identifier="bookid" xmlns="http://www.idpf.org/2007/opf">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="bookid">\(UUID().uuidString)</dc:identifier>
                <dc:title>\(title)</dc:title>
                <dc:language>zh-CN</dc:language>
              </metadata>
              <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
              </manifest>
              <spine>
                <itemref idref="chapter"/>
              </spine>
            </package>
            """.utf8), false),
            ("OEBPS/nav.xhtml", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
              <head>
                <title>\(title)</title>
              </head>
              <body>
                <nav epub:type="toc" id="toc">
                  <ol>
                    <li><a href="chapter.xhtml">\(title)</a></li>
                  </ol>
                </nav>
              </body>
            </html>
            """.utf8), false),
            ("OEBPS/chapter.xhtml", Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head>
                <title>\(title)</title>
                <meta charset="utf-8"/>
              </head>
              <body>
                <h1>\(title)</h1>
                \(body)
              </body>
            </html>
            """.utf8), false)
        ]

        for (path, data, uncompressed) in files {
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: uncompressed ? .none : .deflate,
                bufferSize: min(data.count, 16 * 1024),
                provider: { position, size in
                    data.subdata(in: Int(position)..<Int(position) + size)
                }
            )
        }
    }

    nonisolated private static func decodeText(from data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let unicode = String(data: data, encoding: .unicode) {
            return unicode
        }
        if let gb18030 = String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))) {
            return gb18030
        }
        return String(decoding: data, as: UTF8.self)
    }

    nonisolated private static func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    nonisolated private static func parseRootPath(from data: Data) -> String? {
        let xml = decodeText(from: data)
        return firstMatch(in: xml, pattern: #"full-path\s*=\s*"([^"]+)""#, group: 1)
    }

    nonisolated private static func parsePackage(from data: Data) -> EPUBPackageDocument {
        let xml = decodeText(from: data)
        let title = firstMatch(in: xml, pattern: #"<(?:\w+:)?title[^>]*>([\s\S]*?)</(?:\w+:)?title>"#, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let declaredCoverID = firstMatch(
            in: xml,
            pattern: #"<(?:\w+:)?meta\b[^>]*\bname\s*=\s*"cover"[^>]*\bcontent\s*=\s*"([^"]+)""#,
            group: 1
        )?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        var manifest: [String: EPUBManifestItem] = [:]
        let itemRegex = try? NSRegularExpression(
            pattern: #"<(?:\w+:)?item\b([^>]*)>"#,
            options: [.caseInsensitive]
        )
        let xmlRange = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        itemRegex?.enumerateMatches(in: xml, options: [], range: xmlRange) { match, _, _ in
            guard
                let match,
                let attributesRange = Range(match.range(at: 1), in: xml)
            else { return }
            let attributes = String(xml[attributesRange])
            guard
                let id = firstMatch(in: attributes, pattern: #"\bid\s*=\s*"([^"]+)""#, group: 1),
                let href = firstMatch(in: attributes, pattern: #"\bhref\s*=\s*"([^"]+)""#, group: 1)
            else {
                return
            }
            let mediaType = firstMatch(in: attributes, pattern: #"\bmedia-type\s*=\s*"([^"]+)""#, group: 1)
            let properties = firstMatch(in: attributes, pattern: #"\bproperties\s*=\s*"([^"]+)""#, group: 1)?
                .split(separator: " ")
                .map(String.init) ?? []
            manifest[id] = EPUBManifestItem(href: href, mediaType: mediaType, properties: properties)
        }

        var spine: [String] = []
        let spineRegex = try? NSRegularExpression(
            pattern: #"<(?:\w+:)?itemref\b([^>]*)>"#,
            options: [.caseInsensitive]
        )
        spineRegex?.enumerateMatches(in: xml, options: [], range: xmlRange) { match, _, _ in
            guard
                let match,
                let attributesRange = Range(match.range(at: 1), in: xml)
            else { return }
            let attributes = String(xml[attributesRange])
            guard let idRef = firstMatch(in: attributes, pattern: #"\bidref\s*=\s*"([^"]+)""#, group: 1) else {
                return
            }
            spine.append(idRef)
        }

        return EPUBPackageDocument(title: title, manifest: manifest, spine: spine, declaredCoverID: declaredCoverID)
    }

    nonisolated private static func resolveCoverItem(in package: EPUBPackageDocument) -> EPUBManifestItem? {
        if let declaredCoverID = package.declaredCoverID,
           let item = package.manifest[declaredCoverID],
           item.isImage {
            return item
        }

        if let item = package.manifest.values.first(where: { $0.properties.contains("cover-image") && $0.isImage }) {
            return item
        }

        if let item = package.manifest.first(where: { key, value in
            value.isImage && key.localizedCaseInsensitiveContains("cover")
        })?.value {
            return item
        }

        if let item = package.manifest.values.first(where: {
            $0.isImage && $0.href.localizedCaseInsensitiveContains("cover")
        }) {
            return item
        }

        return package.manifest.values.first(where: \.isImage)
    }

    nonisolated private static func normalizedImageExtension(pathExtension: String, mediaType: String?) -> String {
        let normalizedPathExtension = pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "webp", "gif"].contains(normalizedPathExtension) {
            return normalizedPathExtension == "jpg" ? "jpeg" : normalizedPathExtension
        }

        switch mediaType?.lowercased() {
        case "image/png":
            return "png"
        case "image/jpeg", "image/jpg":
            return "jpeg"
        case "image/webp":
            return "webp"
        case "image/gif":
            return "gif"
        default:
            return "jpeg"
        }
    }

    nonisolated private static func firstMatch(in source: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard
            let match = regex.firstMatch(in: source, options: [], range: range),
            let resultRange = Range(match.range(at: group), in: source)
        else {
            return nil
        }
        return String(source[resultRange])
    }
}

private struct EPUBManifestItem {
    let href: String
    let mediaType: String?
    let properties: [String]

    nonisolated var isImage: Bool {
        mediaType?.lowercased().hasPrefix("image/") == true
    }
}

private struct EPUBPackageDocument {
    var title: String?
    var manifest: [String: EPUBManifestItem]
    var spine: [String]
    var declaredCoverID: String?
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
