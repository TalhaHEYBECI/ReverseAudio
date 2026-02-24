//
//  FileManager+ReverseAudio.swift
//  ReverseAudio
//

import Foundation

extension FileManager {
    enum ReverseAudioDirectory: String {
        case recordings
        case processing
        case exports
    }

    func reverseAudioDirectoryURL(for directory: ReverseAudioDirectory) throws -> URL {
        let directoryURL: URL
        switch directory {
        case .recordings, .processing:
            let base = temporaryDirectory.appendingPathComponent("ReverseAudio", isDirectory: true)
            directoryURL = base.appendingPathComponent(directory.rawValue, isDirectory: true)
        case .exports:
            let cacheBase = try self.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directoryURL = cacheBase
                .appendingPathComponent("ReverseAudio", isDirectory: true)
                .appendingPathComponent("exports", isDirectory: true)
        }

        try createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    func removeFiles(
        in directory: URL,
        olderThan interval: TimeInterval
    ) throws {
        let cutoff = Date().addingTimeInterval(-interval)
        let urls = try contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        for fileURL in urls {
            let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modifiedAt = values.contentModificationDate else {
                continue
            }
            if modifiedAt < cutoff {
                try removeItem(at: fileURL)
            }
        }
    }
}
