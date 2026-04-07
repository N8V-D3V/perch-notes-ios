//
//  CorePipelineDemoView.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import SwiftUI

struct CorePipelineDemoView: View {
    @State private var latestRun: CorePipelineDemoRun?

    private let demoRunner = CorePipelineDemoRunner()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    controlsSection
                    summarySection
                    logSection
                }
                .padding(20)
            }
            .navigationTitle("Stub Demo")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Core Pipeline Demo")
                .font(.title2.weight(.semibold))

            Text("Runs the existing stub orchestrator end-to-end using deterministic demo input.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Demo input: CAPTURE_NEW_IMAGE with GRANTED camera permission")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var controlsSection: some View {
        Button("Run Stub Pipeline") {
            latestRun = demoRunner.runStubDemo()
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Result")
                .font(.headline)

            if let latestRun {
                resultRow(
                    label: "Demo Request",
                    value: "\(latestRun.request.image_acquisition_request.acquisition_method.rawValue), permission=\(latestRun.request.camera_permission_state.state.rawValue)"
                )
                resultRow(label: "Pipeline Status", value: latestRun.result.final_pipeline_status.rawValue)
                resultRow(
                    label: "Source Image ID",
                    value: latestRun.result.image_acquisition_outcome.source_image?.image_id ?? "nil"
                )
                resultRow(
                    label: "Note Count",
                    value: latestRun.result.note_generation_outcome?.note_sequence?.note_count.description ?? "nil"
                )
                resultRow(
                    label: "Generated Audio ID",
                    value: latestRun.result.audio_generation_outcome?.generated_audio?.audio_id ?? "nil"
                )
                resultRow(
                    label: "Image Outcome",
                    value: outcomeSummary(
                        status: latestRun.result.image_acquisition_outcome.image_acquisition_result.status.rawValue,
                        reason: latestRun.result.image_acquisition_outcome.image_acquisition_result.reason?.rawValue,
                        identifier: latestRun.result.image_acquisition_outcome.source_image?.image_id
                    )
                )
                resultRow(
                    label: "Note Outcome",
                    value: outcomeSummary(
                        status: latestRun.result.note_generation_outcome?.note_generation_result.status.rawValue,
                        reason: latestRun.result.note_generation_outcome?.note_generation_result.reason?.rawValue,
                        identifier: latestRun.result.note_generation_outcome?.note_sequence?.source_image_id
                    )
                )
                resultRow(
                    label: "Audio Outcome",
                    value: outcomeSummary(
                        status: latestRun.result.audio_generation_outcome?.audio_generation_result.status.rawValue,
                        reason: latestRun.result.audio_generation_outcome?.audio_generation_result.reason?.rawValue,
                        identifier: latestRun.result.audio_generation_outcome?.generated_audio?.audio_id
                    )
                )
            } else {
                Text("Run the stub pipeline to see the current demo result.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logs")
                .font(.headline)

            if let latestRun, latestRun.logLines.isEmpty == false {
                Text(latestRun.logLines.joined(separator: "\n"))
                    .font(.footnote.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text("Logs from the orchestrator and stub modules will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func resultRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
        }
    }

    private func outcomeSummary(status: String?, reason: String?, identifier: String?) -> String {
        let resolvedStatus = status ?? "NOT_REACHED"
        let resolvedReason = reason ?? "nil"
        let resolvedIdentifier = identifier ?? "nil"
        return "status=\(resolvedStatus), reason=\(resolvedReason), id=\(resolvedIdentifier)"
    }
}

#Preview {
    CorePipelineDemoView()
}
