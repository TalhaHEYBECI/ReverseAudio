//
//  ReverseAudioServiceType.swift
//  ReverseAudio
//

import AVFoundation
import Foundation

public protocol ReverseAudioServiceType {
    func requestMicPermission() async -> Bool
    func startRecording(maxDuration: TimeInterval) throws
    func stopRecording() async throws -> URL
    func reverseAudio(inputURL: URL) async throws -> ReverseAudioResult
    func makePlayer(url: URL) throws -> AVAudioPlayer
    func exportToShareableFile(inputURL: URL, fileName: String) async throws -> URL
    func cleanupTempFiles(olderThan: TimeInterval) throws
}
