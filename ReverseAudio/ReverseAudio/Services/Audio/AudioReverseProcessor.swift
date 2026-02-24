//
//  AudioReverseProcessor.swift
//  ReverseAudio
//

import AVFoundation
import Foundation

final class AudioReverseProcessor {
    private let chunkFrames: AVAudioFrameCount
    private let fileManager: FileManager

    init(chunkFrames: AVAudioFrameCount = 16_384, fileManager: FileManager = .default) {
        self.chunkFrames = chunkFrames
        self.fileManager = fileManager
    }

    func reverse(inputURL: URL, outputURL: URL) async throws {
        try await Task.detached(priority: .userInitiated) { [chunkFrames] in
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

            if self.fileManager.fileExists(atPath: outputURL.path) {
                try self.fileManager.removeItem(at: outputURL)
            }

            let outputFile = try AVAudioFile(
                forWriting: outputURL,
                settings: outputSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            var remainingFrames = inputFile.length
            while remainingFrames > 0 {
                let frameCount = min(Int64(chunkFrames), remainingFrames)
                let startFrame = remainingFrames - frameCount
                inputFile.framePosition = startFrame

                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(frameCount)
                ) else {
                    throw ReverseAudioError.processingFailed("Failed to allocate PCM buffer.")
                }

                try inputFile.read(into: buffer, frameCount: AVAudioFrameCount(frameCount))
                reverseBufferSamples(buffer)
                try outputFile.write(from: buffer)

                remainingFrames -= frameCount
            }
        }.value
    }
}

private func reverseBufferSamples(_ buffer: AVAudioPCMBuffer) {
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 1 else { return }
    guard let channels = buffer.floatChannelData else { return }

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
