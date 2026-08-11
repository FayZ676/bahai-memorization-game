import AVFoundation
import Foundation

#if DEBUG
final class RecitationCapture: @unchecked Sendable {
    static let shared = RecitationCapture()

    private let lock = NSLock()
    private var handle: FileHandle?
    private var url: URL?
    private var sampleCount = 0
    private var sampleRate = 16000

    func begin(sampleRate: Int) {
        lock.lock()
        defer { lock.unlock() }
        closeLocked()
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let directory else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let target = directory.appending(path: "recite-\(stamp).wav")
        FileManager.default.createFile(atPath: target.path(percentEncoded: false), contents: nil)
        guard let opened = try? FileHandle(forWritingTo: target) else { return }
        self.sampleRate = sampleRate
        handle = opened
        url = target
        sampleCount = 0
        try? opened.write(contentsOf: Self.header(samples: 0, rate: sampleRate))
        RecitationTrace.emit("capture", "writing \(target.lastPathComponent) at \(sampleRate)Hz")
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.int16ChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        let data = Data(bytes: channel, count: frames * MemoryLayout<Int16>.size)
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { return }
        try? handle.write(contentsOf: data)
        sampleCount += frames
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard let handle, let url else { return }
        let seconds = Double(sampleCount) / Double(sampleRate)
        try? handle.seek(toOffset: 0)
        try? handle.write(contentsOf: Self.header(samples: sampleCount, rate: sampleRate))
        try? handle.close()
        RecitationTrace.emit(
            "capture",
            "wrote \(url.lastPathComponent) \(sampleCount) samples (\(String(format: "%.1f", seconds))s)"
        )
        self.handle = nil
        self.url = nil
    }

    private func closeLocked() {
        guard handle != nil else { return }
        try? handle?.close()
        handle = nil
        url = nil
    }

    private static func header(samples: Int, rate: Int) -> Data {
        let dataBytes = samples * 2
        var data = Data()
        func ascii(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
        func u32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(36 + dataBytes); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1)
        u32(rate); u32(rate * 2); u16(2); u16(16)
        ascii("data"); u32(dataBytes)
        return data
    }
}
#endif
