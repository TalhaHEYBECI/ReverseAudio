import AVFoundation
import Foundation

final class ReverseAudioService: NSObject, AVAudioRecorderDelegate, ReverseAudioServiceType {
    private let fileManager: FileManager
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let chunkFrames: AVAudioFrameCount

    init(fileManager: FileManager = .default, chunkFrames: AVAudioFrameCount = 16_384) {
        self.fileManager = fileManager
        self.chunkFrames = chunkFrames
    }

    func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(maxDuration: TimeInterval = 15) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let url = try makeDirectory(.recordings)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        guard recorder.prepareToRecord() else {
            throw ReverseAudioError.recordingFailed(
                NSLocalizedString("errorReason.recorderPrepareFailed", comment: "Recorder preparation failed")
            )
        }

        let cappedDuration = min(maxDuration, 15)
        guard recorder.record(forDuration: cappedDuration) else {
            throw ReverseAudioError.recordingFailed(
                NSLocalizedString("errorReason.recordStartFailed", comment: "Could not start recording")
            )
        }

        self.recorder = recorder
    }

    func stopRecording() async throws -> URL {
        if let recorder, recorder.isRecording {
            recorder.stop()
        }

        guard let recordingURL else {
            throw ReverseAudioError.recordingFailed(
                NSLocalizedString("errorReason.recordingURLMissing", comment: "Missing recording URL")
            )
        }
        guard fileManager.fileExists(atPath: recordingURL.path) else {
            throw ReverseAudioError.recordingFailed(
                NSLocalizedString("errorReason.recordingFileMissing", comment: "Recording file missing")
            )
        }

        let file = try AVAudioFile(forReading: recordingURL)
        guard file.length > 0 else {
            throw ReverseAudioError.invalidInput
        }

        return recordingURL
    }

    func reverseAudio(inputURL: URL) async throws -> ReverseAudioResult {
        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw ReverseAudioError.invalidInput
        }

        let processingURL = try makeDirectory(.processing)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")

        let start = DispatchTime.now()
        try await reverseChunked(inputURL: inputURL, outputPCMURL: processingURL)
        let reversedURL = try await exportToM4A(inputURL: processingURL, fileName: "reversed-\(UUID().uuidString)")
        let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

        return ReverseAudioResult(originalURL: inputURL, reversedURL: reversedURL, processingMs: elapsedMs)
    }

    func makePlayer(url: URL) throws -> AVAudioPlayer {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        return player
    }

    func exportToShareableFile(inputURL: URL, fileName: String) async throws -> URL {
        try await exportToM4A(inputURL: inputURL, fileName: fileName)
    }

    private func reverseChunked(inputURL: URL, outputPCMURL: URL) async throws {
        try await Task.detached(priority: .userInitiated) { [fileManager, chunkFrames] in
            let inputFile = try AVAudioFile(
                forReading: inputURL,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            let format = inputFile.processingFormat
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: Int(format.channelCount),
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: true
            ]

            if fileManager.fileExists(atPath: outputPCMURL.path) {
                try fileManager.removeItem(at: outputPCMURL)
            }

            let outputFile = try AVAudioFile(
                forWriting: outputPCMURL,
                settings: outputSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            var remainingFrames = inputFile.length
            while remainingFrames > 0 {
                let frameCount = min(Int64(chunkFrames), remainingFrames)
                inputFile.framePosition = remainingFrames - frameCount

                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(frameCount)
                ) else {
                    throw ReverseAudioError.processingFailed(
                        NSLocalizedString("errorReason.bufferAllocationFailed", comment: "Failed to allocate buffer")
                    )
                }

                try inputFile.read(into: buffer, frameCount: AVAudioFrameCount(frameCount))
                reverseAudioSamples(in: buffer)
                try outputFile.write(from: buffer)
                remainingFrames -= frameCount
            }
        }.value
    }

    private func exportToM4A(inputURL: URL, fileName: String) async throws -> URL {
        let outputURL = try makeDirectory(.exports)
            .appendingPathComponent(safeFileName(fileName))
            .appendingPathExtension("m4a")

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        let asset = AVURLAsset(url: inputURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ReverseAudioError.exportFailed(
                NSLocalizedString("errorReason.exportSessionUnavailable", comment: "Export session unavailable")
            )
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(
                        throwing: exporter.error ?? ReverseAudioError.exportFailed(
                            NSLocalizedString("errorReason.exportUnknownFailure", comment: "Unknown export failure")
                        )
                    )
                case .cancelled:
                    continuation.resume(
                        throwing: ReverseAudioError.exportFailed(
                            NSLocalizedString("errorReason.exportCancelled", comment: "Export cancelled")
                        )
                    )
                default:
                    continuation.resume(
                        throwing: ReverseAudioError.exportFailed(
                            NSLocalizedString("errorReason.exportUnexpectedStatus", comment: "Unexpected export status")
                        )
                    )
                }
            }
        }

        return outputURL
    }

    private func safeFileName(_ fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = fileName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let candidate = String(filtered)
        return candidate.isEmpty ? UUID().uuidString : candidate
    }

    private enum Directory: String {
        case recordings
        case processing
        case exports
    }

    private func makeDirectory(_ directory: Directory) throws -> URL {
        let dirURL: URL
        switch directory {
        case .recordings, .processing:
            dirURL = fileManager.temporaryDirectory
                .appendingPathComponent("ReverseAudio", isDirectory: true)
                .appendingPathComponent(directory.rawValue, isDirectory: true)
        case .exports:
            let cacheBase = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            dirURL = cacheBase
                .appendingPathComponent("ReverseAudio", isDirectory: true)
                .appendingPathComponent("exports", isDirectory: true)
        }

        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
}

private func reverseAudioSamples(in buffer: AVAudioPCMBuffer) {
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 1, let channels = buffer.floatChannelData else { return }

    for channel in 0 ..< Int(buffer.format.channelCount) {
        let data = channels[channel]
        var left = 0
        var right = frameLength - 1
        while left < right {
            let temp = data[left]
            data[left] = data[right]
            data[right] = temp
            left += 1
            right -= 1
        }
    }
}
