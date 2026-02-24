import SwiftUI
import UIKit

struct ReverseAudioDemoView: View {
    @StateObject private var viewModel = ReverseAudioDemoViewModel()
    @State private var shareURL: URL?
    @State private var isSharePresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusView
                    controlsView
                    infoView
                }
                .padding()
            }
            .navigationTitle(Text("onboarding.demo.navTitle"))
        }
        .sheet(isPresented: $isSharePresented) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.status {
        case .permissionDenied:
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.demo.permissionRequired")
                    .font(.headline)
                Button("onboarding.demo.openSettingsButton") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        case .processing:
            HStack(spacing: 12) {
                ProgressView()
                Text("onboarding.demo.processing")
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        case let .error(message):
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.demo.errorTitle")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                Button("onboarding.demo.retryButton") {
                    viewModel.retryFromError()
                }
                .buttonStyle(.bordered)
            }
        case .ready:
            Text("onboarding.demo.ready")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .recording:
            Text("onboarding.demo.recordingInProgress")
                .font(.subheadline)
                .foregroundStyle(.orange)
        case .idle:
            Text("onboarding.demo.idle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleRecording() }
            } label: {
                Text(viewModel.status == .recording ? "onboarding.demo.stopButton" : "onboarding.demo.recordButton")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.status == .recording ? .red : .blue)
            .disabled(viewModel.isProcessing)

            Button("onboarding.demo.reverseButton") {
                Task { await viewModel.reverse() }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
            .disabled(!viewModel.canReverse)

            HStack {
                Button(viewModel.isPlayingOriginal ? "onboarding.demo.pauseOriginalButton" : "onboarding.demo.playOriginalButton") {
                    viewModel.toggleOriginalPlayback()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.originalURL == nil || viewModel.isProcessing)

                Button(viewModel.isPlayingReversed ? "onboarding.demo.pauseReversedButton" : "onboarding.demo.playReversedButton") {
                    viewModel.toggleReversedPlayback()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.reversedURL == nil || viewModel.isProcessing)
            }

            Button("onboarding.demo.shareReversedButton") {
                if let reversed = viewModel.reversedURL {
                    shareURL = reversed
                    isSharePresented = true
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canShareReversed)
        }
    }

    @ViewBuilder
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let original = viewModel.originalURL {
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("onboarding.demo.originalFileFormat", comment: "Original file name"),
                        original.lastPathComponent
                    )
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let reversed = viewModel.reversedURL {
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("onboarding.demo.reversedFileFormat", comment: "Reversed file name"),
                        reversed.lastPathComponent
                    )
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let ms = viewModel.processingMs {
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("onboarding.demo.processingTimeFormat", comment: "Processing duration in milliseconds"),
                        ms
                    )
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ReverseAudioDemoView()
}
