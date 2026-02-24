//
//  AudioExportService.swift
//  ReverseAudio
//

import AVFoundation
import Foundation

final class AudioExportService {
    enum ExportFormat {
        case m4a
        case wav
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func exportToM4A(inputURL: URL, fileName: String) async throws -> URL {
        let outputDirectory = try fileManager.reverseAudioDirectoryURL(for: .exports)
        let outputURL = outputDirectory
            .appendingPathComponent(sanitizedFileName(fileName))
            .appendingPathExtension("m4a")

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        let asset = AVURLAsset(url: inputURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ReverseAudioError.exportFailed("Failed to create AVAssetExportSession.")
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
                    continuation.resume(throwing: exporter.error ?? ReverseAudioError.exportFailed("Unknown export error."))
                case .cancelled:
                    continuation.resume(throwing: ReverseAudioError.exportFailed("Export cancelled."))
                default:
                    continuation.resume(throwing: ReverseAudioError.exportFailed("Unexpected export status: \(exporter.status.rawValue)."))
                }
            }
        }

        return outputURL
    }

    func export(inputURL: URL, fileName: String, format: ExportFormat) async throws -> URL {
        switch format {
        case .m4a:
            return try await exportToM4A(inputURL: inputURL, fileName: fileName)
        case .wav:
            return try await exportToWAV(inputURL: inputURL, fileName: fileName)
        }
    }

    func exportToWAV(inputURL: URL, fileName: String) async throws -> URL {
        let outputDirectory = try fileManager.reverseAudioDirectoryURL(for: .exports)
        let outputURL = outputDirectory
            .appendingPathComponent(sanitizedFileName(fileName))
            .appendingPathExtension("wav")

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        try await Task.detached(priority: .utility) {
            let inputFile = try AVAudioFile(
                forReading: inputURL,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            let format = inputFile.processingFormat
            let wavSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: Int(format.channelCount),
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            let outputFile = try AVAudioFile(forWriting: outputURL, settings: wavSettings)
            let frameChunk: AVAudioFrameCount = 8192
            while true {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, frameCapacity: frameChunk) else {
                    throw ReverseAudioError.exportFailed("Failed to allocate WAV buffer.")
                }
                try inputFile.read(into: buffer, frameCount: frameChunk)
                if buffer.frameLength == 0 { break }
                try outputFile.write(from: buffer)
            }
        }.value

        return outputURL
    }

    private func sanitizedFileName(_ fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = fileName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let safeName = String(cleaned)
        return safeName.isEmpty ? UUID().uuidString : safeName
    }
}
