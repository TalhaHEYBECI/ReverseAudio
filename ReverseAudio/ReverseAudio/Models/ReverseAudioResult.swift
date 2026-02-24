//
//  ReverseAudioResult.swift
//  ReverseAudio
//

import Foundation

public struct ReverseAudioResult: Sendable {
    public let originalURL: URL
    public let reversedURL: URL
    public let duration: TimeInterval
    public let processingMs: Int

    public init(
        originalURL: URL,
        reversedURL: URL,
        duration: TimeInterval,
        processingMs: Int
    ) {
        self.originalURL = originalURL
        self.reversedURL = reversedURL
        self.duration = duration
        self.processingMs = processingMs
    }
}
