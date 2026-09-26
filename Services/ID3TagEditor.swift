import Foundation

enum ID3TagEditorError: LocalizedError {
    case unsupportedFormat
    case unsupportedVersion
    case unsupportedTagLayout
    case unsupportedArtwork
    case unreadableFile
    case unwritableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return L10n.t(.tagEditorUnsupportedFormat)
        case .unsupportedVersion:
            return L10n.t(.tagEditorUnsupportedVersion)
        case .unsupportedTagLayout:
            return L10n.t(.tagEditorUnsupportedTagLayout)
        case .unsupportedArtwork:
            return L10n.t(.tagEditorUnsupportedArtwork)
        case .unreadableFile:
            return L10n.t(.tagEditorUnreadableFile)
        case .unwritableFile:
            return L10n.t(.tagEditorUnwritableFile)
        }
    }
}

struct ID3TagEditor {
    private struct ExistingTag {
        let version: Int
        let flags: UInt8
        let payloadStart: Int
        let payloadEnd: Int
        let totalSize: Int

        nonisolated var usesUnsynchronisation: Bool {
            flags & 0x80 != 0
        }
    }

    private struct Frame {
        let id: String
        let bytes: Data
    }

    nonisolated static func write(tags: SongTagDraft, to url: URL) throws {
        guard url.pathExtension.localizedCaseInsensitiveCompare("mp3") == .orderedSame else {
            throw ID3TagEditorError.unsupportedFormat
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ID3TagEditorError.unreadableFile
        }
        guard FileManager.default.isWritableFile(atPath: url.path) else {
            throw ID3TagEditorError.unwritableFile
        }

        let fileData = try Data(contentsOf: url)
        let existingTag = try parseExistingTag(in: fileData)
        let version = existingTag?.version ?? 3
        guard version == 3 || version == 4 else {
            throw ID3TagEditorError.unsupportedVersion
        }
        if existingTag?.usesUnsynchronisation == true {
            throw ID3TagEditorError.unsupportedTagLayout
        }

        let preservedFrames: [Frame]
        let audioStart: Int
        if let existingTag {
            let payload = fileData[existingTag.payloadStart..<existingTag.payloadEnd]
            preservedFrames = try parseFrames(in: payload, version: version)
                .filter { !isEditableFrameID($0.id, rewriteArtwork: tags.artworkChange.shouldRewriteArtwork) }
            audioStart = existingTag.totalSize
        } else {
            preservedFrames = []
            audioStart = 0
        }

        var payload = Data()
        for frame in preservedFrames {
            payload.append(frame.bytes)
        }
        for frame in editableFrames(from: tags, version: version) {
            payload.append(frame.bytes)
        }
        if let artworkFrame = try artworkFrame(from: tags.artworkChange, version: version) {
            payload.append(artworkFrame.bytes)
        }

        var output = Data()
        output.append(contentsOf: [0x49, 0x44, 0x33])
        output.append(UInt8(version))
        output.append(0x00)
        output.append(0x00)
        output.append(contentsOf: synchsafeBytes(payload.count))
        output.append(payload)
        output.append(fileData[audioStart..<fileData.count])

        try output.write(to: url, options: .atomic)
    }

    nonisolated private static func parseExistingTag(in data: Data) throws -> ExistingTag? {
        guard data.count >= 10 else { return nil }
        guard data[0] == 0x49, data[1] == 0x44, data[2] == 0x33 else { return nil }

        let version = Int(data[3])
        let flags = data[5]
        let tagSize = readSynchsafeInteger(data, offset: 6)
        var payloadStart = 10
        let hasFooter = version == 4 && flags & 0x10 != 0
        let totalSize = 10 + tagSize + (hasFooter ? 10 : 0)
        guard totalSize <= data.count else {
            throw ID3TagEditorError.unsupportedTagLayout
        }

        if flags & 0x40 != 0 {
            if version == 3 {
                guard payloadStart + 4 <= 10 + tagSize else {
                    throw ID3TagEditorError.unsupportedTagLayout
                }
                let extendedSize = readUInt32(data, offset: payloadStart)
                payloadStart += 4 + extendedSize
            } else if version == 4 {
                guard payloadStart + 4 <= 10 + tagSize else {
                    throw ID3TagEditorError.unsupportedTagLayout
                }
                let extendedSize = readSynchsafeInteger(data, offset: payloadStart)
                payloadStart += extendedSize
            } else {
                throw ID3TagEditorError.unsupportedVersion
            }
        }

        guard payloadStart <= 10 + tagSize else {
            throw ID3TagEditorError.unsupportedTagLayout
        }

        return ExistingTag(
            version: version,
            flags: flags,
            payloadStart: payloadStart,
            payloadEnd: 10 + tagSize,
            totalSize: totalSize
        )
    }

    nonisolated private static func parseFrames(in payload: Data.SubSequence, version: Int) throws -> [Frame] {
        var frames: [Frame] = []
        var offset = payload.startIndex

        while offset + 10 <= payload.endIndex {
            let header = payload[offset..<offset + 10]
            if header.allSatisfy({ $0 == 0 }) {
                break
            }

            let idData = Data(payload[offset..<offset + 4])
            guard let frameID = String(data: idData, encoding: .ascii),
                  isValidFrameID(frameID) else {
                break
            }

            let size = version == 4 ?
                readSynchsafeInteger(payload, offset: offset + 4) :
                readUInt32(payload, offset: offset + 4)
            guard size >= 0, offset + 10 + size <= payload.endIndex else {
                throw ID3TagEditorError.unsupportedTagLayout
            }

            let frameBytes = Data(payload[offset..<offset + 10 + size])
            frames.append(Frame(id: frameID, bytes: frameBytes))
            offset += 10 + size
        }

        return frames
    }

    nonisolated private static func editableFrames(from tags: SongTagDraft, version: Int) -> [Frame] {
        let yearFrameID = version == 4 ? "TDRC" : "TYER"
        return [
            textFrame(id: "TIT2", value: tags.title, version: version),
            textFrame(id: "TPE1", value: tags.artist, version: version),
            textFrame(id: "TALB", value: tags.album, version: version),
            textFrame(id: "TCON", value: tags.genre, version: version),
            textFrame(id: yearFrameID, value: tags.year, version: version),
            textFrame(id: "TRCK", value: tags.trackNumber, version: version),
            textFrame(id: "TPOS", value: tags.discNumber, version: version)
        ].compactMap { $0 }
    }

    nonisolated private static func textFrame(id: String, value: String, version: Int) -> Frame? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var body = Data()
        body.append(0x01)
        body.append(contentsOf: [0xFF, 0xFE])
        body.append(trimmed.data(using: .utf16LittleEndian) ?? Data())

        return frame(id: id, body: body, version: version)
    }

    nonisolated private static func artworkFrame(from change: SongArtworkChange, version: Int) throws -> Frame? {
        switch change {
        case .keep, .remove:
            return nil
        case let .replace(payload):
            guard !payload.data.isEmpty,
                  let mimeData = payload.mimeType.data(using: .ascii),
                  !mimeData.isEmpty else {
                throw ID3TagEditorError.unsupportedArtwork
            }

            var body = Data()
            body.append(0x00)
            body.append(mimeData)
            body.append(0x00)
            body.append(0x03)
            body.append(0x00)
            body.append(payload.data)
            return frame(id: "APIC", body: body, version: version)
        }
    }

    nonisolated private static func frame(id: String, body: Data, version: Int) -> Frame {
        var frame = Data()
        frame.append(id.data(using: .ascii) ?? Data())
        if version == 4 {
            frame.append(contentsOf: synchsafeBytes(body.count))
        } else {
            frame.append(contentsOf: uint32Bytes(body.count))
        }
        frame.append(contentsOf: [0x00, 0x00])
        frame.append(body)
        return Frame(id: id, bytes: frame)
    }

    nonisolated private static func isEditableFrameID(_ id: String, rewriteArtwork: Bool) -> Bool {
        switch id {
        case "TIT2", "TPE1", "TALB", "TCON", "TYER", "TDRC", "TRCK", "TPOS":
            return true
        case "APIC":
            return rewriteArtwork
        default:
            return false
        }
    }

    nonisolated private static func isValidFrameID(_ value: String) -> Bool {
        guard value.count == 4 else { return false }
        return value.allSatisfy { character in
            character.isUppercase || character.isNumber
        }
    }

    nonisolated private static func readSynchsafeInteger<T: DataProtocol>(_ data: T, offset: T.Index) -> Int where T.Index == Int {
        let bytes = [data[offset], data[offset + 1], data[offset + 2], data[offset + 3]]
        return (Int(bytes[0]) << 21) |
            (Int(bytes[1]) << 14) |
            (Int(bytes[2]) << 7) |
            Int(bytes[3])
    }

    nonisolated private static func readUInt32<T: DataProtocol>(_ data: T, offset: T.Index) -> Int where T.Index == Int {
        let bytes = [data[offset], data[offset + 1], data[offset + 2], data[offset + 3]]
        return (Int(bytes[0]) << 24) |
            (Int(bytes[1]) << 16) |
            (Int(bytes[2]) << 8) |
            Int(bytes[3])
    }

    nonisolated private static func synchsafeBytes(_ value: Int) -> [UInt8] {
        [
            UInt8((value >> 21) & 0x7F),
            UInt8((value >> 14) & 0x7F),
            UInt8((value >> 7) & 0x7F),
            UInt8(value & 0x7F)
        ]
    }

    nonisolated private static func uint32Bytes(_ value: Int) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
}
