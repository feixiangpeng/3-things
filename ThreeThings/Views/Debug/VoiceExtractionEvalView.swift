#if DEBUG
import SwiftUI

/// Debug-only screen: runs `FoundationModelsVoiceDraftExtractor` across fixture transcripts (device only).
struct VoiceExtractionEvalView: View {
    @State private var passesPerTranscript = 5
    @State private var isRunning = false
    @State private var statusMessage = ""
    @State private var report: VoiceExtractionEvalReport?
    @State private var cases: [VoiceExtractionEvalCase] = []
    @State private var loadError: String?

    var body: some View {
        Form {
            Section("Configuration") {
                #if targetEnvironment(simulator)
                Text(
                    "Apple Foundation Models extraction eval must be run on a physical device with on-device AI available. The simulator does not exercise FoundationModelsVoiceDraftExtractor."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                #else
                Stepper("Passes per transcript: \(passesPerTranscript)", value: $passesPerTranscript, in: 5...10)
                Button("Run voice extraction eval") {
                    Task { await runEval() }
                }
                .disabled(isRunning || cases.isEmpty)
                if isRunning {
                    ProgressView()
                }
                #endif
                if let loadError {
                    Text(loadError)
                        .foregroundStyle(.red)
                }
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                }
            }

            if let report {
                Section("Summary") {
                    Text(
                        String(
                            format: "Mean pass rate (per variant): %.1f%%",
                            report.meanPassRateAcrossVariants * 100
                        )
                    )
                    Text(
                        String(
                            format: "First-pass rate (per variant): %.1f%%",
                            report.firstPassRateAcrossVariants * 100
                        )
                    )
                    Text("Variants: \(report.totalVariants) · runs each: \(report.runsPerTranscript)")
                }
                if !report.categorySummaries.isEmpty {
                    Section("Per category") {
                        ForEach(Array(report.categorySummaries.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.category)
                                    .font(.subheadline.bold())
                                Text(String(format: "mean pass: %.0f%% · first-pass: %.0f%%", row.meanPassRate * 100, row.firstPassRate * 100))
                                    .font(.caption)
                                if row.totalHallucinationRuns > 0 {
                                    Text("Hallucination-flagged runs: \(row.totalHallucinationRuns)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Failing variants (lowest pass rate first)") {
                    let worst = report.variants.filter { $0.passRate < 1 }.sorted { $0.passRate < $1.passRate }
                    if worst.isEmpty {
                        Text("All variants passed every run.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(worst.enumerated()), id: \.offset) { _, v in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(v.caseId) · transcript #\(v.transcriptIndex + 1)")
                                    .font(.subheadline.bold())
                                Text(String(format: "pass rate: %.0f%%", v.passRate * 100))
                                    .font(.caption)
                                ForEach(Array(v.runs.enumerated()), id: \.offset) { _, run in
                                    if !run.passed {
                                        Text("– \(run.reasons.joined(separator: ", ")) · \(run.selectedTasks) \(run.extraCandidates)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Extraction eval")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                cases = try VoiceExtractionEvalLoader.loadCases()
                loadError = nil
            } catch {
                cases = []
                loadError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func runEval() async {
        #if targetEnvironment(simulator)
        statusMessage =
            "Skipped: run this eval on a physical iPhone with Apple Intelligence / on-device model available."
        report = nil
        return
        #endif

        isRunning = true
        defer { isRunning = false }
        statusMessage = "Running…"
        let outcome = await VoiceExtractionEvalRunner.run(
            cases: cases,
            runsPerTranscript: passesPerTranscript
        ) { statusMessage = $0 }
        report = outcome
        statusMessage = String(
            format: "Finished · mean pass: %.1f%% · first-pass: %.1f%%",
            outcome.meanPassRateAcrossVariants * 100,
            outcome.firstPassRateAcrossVariants * 100
        )
    }
}

#Preview {
    NavigationStack {
        VoiceExtractionEvalView()
    }
}
#endif
