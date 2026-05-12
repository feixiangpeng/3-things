# Voice Pipeline TODO

## Framing

The next milestone is the local voice MVP. The core job is not TTS yet. It is:

1. Record audio.
2. Transcribe speech to text.
3. Extract candidate tasks.
4. Let the user edit, merge, discard, and reorder until only 1-3 tasks remain.
5. Confirm lock.

Text-to-speech can come later if we want the app to read tasks back or create an audio confirmation loop.

## Provider Options

### Speech-to-text

- **Apple SpeechAnalyzer/SpeechTranscriber**: primary MVP path.
  - Runs on device.
  - Keeps audio local.
  - Avoids network round-trip latency and API cost.
  - Requires the iOS version that provides these APIs.
- **Cloud transcription**: deferred fallback.
  - Groq Whisper/OpenAI transcription can be compared later if local quality is not good enough.
  - Not part of the default MVP path.

### Text-to-speech

- Defer for now.
- If needed later:
  - Groq has an OpenAI-compatible speech endpoint with Orpheus voices.
  - OpenAI has `gpt-4o-mini-tts` plus streaming PCM/WAV for low latency.

## Extraction pipeline (MVP)

**Chosen path:** single guided-generation call with **Apple Foundation Models** (`@Generable` output → `VoiceDraftPostProcessor` → `VoiceExtractionDraft`). No raw JSON parsing in the app.

- **Simulator / CI:** `HeuristicVoiceDraftExtractor` (deterministic split) via `AppVoiceDraftExtractorFactory`.
- **Device:** `FoundationModelsVoiceDraftExtractor` when Apple Intelligence / the on-device model is available; otherwise errors surface **Type instead** (see `VoiceDraftExtractionError`).

A future **two-stage** cleanup-then-extract pass is optional polish if latency/quality testing shows the need; it is not a parallel MVP track.

### ~~Option A / B / C~~ (historical notes)

<details>
<summary>Earlier brainstorm (single-pass vs two-stage vs hybrid)</summary>

- Option A: single-pass structured extraction — implemented as the baseline guided-generation path.
- Option B: two-stage cleanup then extraction — deferred until measured need.
- Option C: hybrid with repair — deferred.

</details>

## Output Shape

Keep a structured internal result. Prefer Apple Foundation Models guided/structured generation over raw JSON when available.

Suggested app-level model:

```swift
struct VoiceExtractionDraft {
    var selectedTasks: [String] // max 3
    var extraCandidates: [String]
    var detectedMoreThanThree: Bool
    var cleanedTranscript: String
}
```

Rules:

- `selectedTasks.count` must be `0...3`.
- `extraCandidates` holds everything the user might reasonably choose instead.
- Preserve user wording unless the phrasing is too long or not actionable.
- Enforce the existing task text policy: warning after 70 chars, hard cap at 100 chars.
- If a candidate exceeds 100 chars, trim only enough to fit and leave final wording editable.

## Overflow / Editing Experience

When more than 3 candidates are detected, show a reprioritization page.

The page should let the user:

- Edit any selected task.
- Edit any extra candidate before selecting it.
- Move tasks up/down.
- Replace a selected task with an extra.
- Discard extras.
- Merge ideas manually by editing text.
- Lock only when 1-3 valid, unique tasks remain.

Copy direction:

- "I heard more than 3 things. Pick what actually matters today."
- Avoid scolding. The point is focus, not punishment.

## Prompt Work

Foundation Models extraction goals:

- Handle rambling.
- Handle corrections like "actually", "never mind", "scratch that", "make that".
- Preserve voice and concrete verbs.
- Avoid generic summaries.
- Prefer tasks the user explicitly names over inferred meta-tasks.
- Split separate commitments.
- Merge duplicates.
- Return extras when there are more than 3 real tasks.

Prompt eval cases to write:

- Clean 1-task input.
- Clean 3-task input.
- 5-task overflow input.
- Rambling input with filler.
- "Never mind" removing a previous task.
- "Actually replace X with Y."
- Two duplicate phrasings of the same task.
- Vague input that should stay editable rather than over-inferred.
- Long task that needs trimming to 100 chars.

## Next Implementation Step

Most scaffold items below are done. Remaining work is mostly **device dogfooding** (offline recording + extraction quality) and prompt tuning.

1. ~~Add a `VoiceExtractionDraft` model.~~
2. ~~Add an `ExtractionReviewView` that supports selected tasks plus extras.~~
3. ~~Extend the current text editing/locking flow so voice drafts land in the same validation and confirmation path.~~
4. ~~Add a mock provider with fixture transcripts for prompt/eval iteration.~~
5. ~~Replace the placeholder voice screen with Apple SpeechAnalyzer/SpeechTranscriber recording.~~
6. ~~Wire Apple Foundation Models extraction into the same draft/review path.~~

Next: ship a TestFlight build and iterate on prompts + ASR edge cases on hardware (Airplane Mode).
