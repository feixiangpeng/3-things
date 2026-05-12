# Project Description

## Goal

**3-things** is a native iOS app for radical daily focus. Each day, the user commits to **1 to 3 things that matter**, locks them for the current focus day, and executes without adding, carrying over, or constantly reshuffling tasks.

The product intentionally avoids becoming a general task manager. It is built around one daily commitment loop:

1. Capture today's 1-3 things.
2. Review and validate them.
3. Explicitly lock the plan.
4. Complete the locked tasks during the day.
5. Start fresh on the next focus day.

The MVP product direction is voice-first and local-first: speak messy thoughts, transcribe them on device, extract the 1-3 actionable tasks with Apple's on-device Foundation Models, edit them, then lock. Typing remains available as a fallback input mode, but the intended differentiator is private, zero-cost voice-to-task extraction.

## Implementation Details

### Platform And Stack

- Native iOS app.
- Swift 6.
- SwiftUI.
- MVVM-style app state centered around `AppViewModel`.
- Minimal persistence with `UserDefaults` and `Codable`.
- Modern Apple Intelligence-capable iPhone target only for now.
- Supported MVP devices: iPhone 15 Pro, iPhone 15 Pro Max, and all iPhone 16 / iPhone 17 models.
- Required OS: whichever iOS version provides Apple SpeechAnalyzer/SpeechTranscriber and Apple Foundation Models APIs.
- No backwards compatibility path yet for older devices or older iOS versions.
- Current source lives under `ThreeThings/`.

### Current MVP Scope

The current shippable milestone is a **voice-first local-AI TestFlight MVP** (capture → transcribe → extract → review → lock). The following are **explicitly not in the first TestFlight**: push notifications for start-of-day prompts, periodic nudges, and end-of-day notification actions; in-app **settings** for reminder intervals, quiet hours, intensity, or EOD times. Those ship after the on-device voice loop is stable.

- Record a short voice capture.
- Transcribe speech locally with Apple SpeechAnalyzer/SpeechTranscriber.
- Extract 1-3 candidate tasks locally with Apple Foundation Models.
- Review extracted tasks, extras, and overflow before locking.
- Type 1-3 tasks manually.
- Validate empty, duplicate, and overlong tasks.
- Show a pending review/finalization step before locking.
- Require explicit lock confirmation.
- Show a read-only locked execution view.
- Allow reversible completion toggles.
- Roll the focus day over at the local focus-day boundary.
- Track rolling 7-day momentum.
- Handle pending yesterday finalization before starting today's plan.

### Core Product Rules

- A daily plan must contain at least 1 task and at most 3 tasks.
- Tasks are only created during the daily capture flow.
- Once locked, task text cannot be edited until the next focus day.
- Completion can be toggled on locked tasks.
- Prior day task text is not carried forward.
- Previous plans are not archived as task history.
- Only minimal momentum metadata persists across sessions.

### Current Code Structure

- `ThreeThings/Models/`
  - `DailyPlan`
  - `TaskItem`
  - `InputMode`
  - `VoiceExtractionDraft`

- `ThreeThings/ViewModels/`
  - `AppViewModel`, the main app state and flow controller.

- `ThreeThings/Views/`
  - `RootView`
  - `TextCaptureView`
  - `PendingFinalizationView`
  - `LockedPlanView`
  - `ExtractionReviewView`
  - `VoiceCaptureView`

- `ThreeThings/Services/Extraction/`
  - Provider abstraction for task extraction.
  - Mock extraction providers for local development.
  - Placeholder cloud providers exist in code, but MVP extraction direction is Apple Foundation Models on device.

- `ThreeThings/Services/Speech/`
  - `SpeechCaptureManager`, intended to wrap on-device speech recognition.

- `ThreeThings/Utilities/`
  - `FocusDay`, which owns focus-day identity and rollover logic.

### Voice And Extraction Direction

Voice capture and local LLM extraction are part of the MVP direction, not a later add-on.

Planned flow:

1. User records speech.
2. Speech is transcribed on device with Apple SpeechAnalyzer/SpeechTranscriber.
3. Transcript is processed locally by Apple Foundation Models.
4. The local model returns structured tasks, extras, and overflow metadata.
5. User reviews the extracted tasks before locking.

Important privacy/current-design notes:

- Audio should stay on device.
- Transcript text should stay on device for MVP extraction.
- Cloud extraction is not part of the default MVP path.
- Manual text entry remains available as the fallback path.
- English-only for the initial release.
- MVP compatibility is intentionally narrow: iPhone 15 Pro/Pro Max and all iPhone 16/17 devices only, with the required iOS version for Apple's local speech and Foundation Models APIs.

## What Still Needs To Be Done

### Immediate MVP Work

- Replace the voice placeholder with real SpeechAnalyzer/SpeechTranscriber capture.
- Implement Apple Foundation Models extraction for 1-3 tasks, extras, and overflow.
- Finish the voice/text capture, validation, review, and lock flow.
- Ensure locked plans persist correctly across app launches.
- Complete focus-day rollover behavior.
- Finalize the exact focus-day boundary decision and update docs/code consistently.
- Implement pending-yesterday finalization before a new day can start.
- Implement rolling 7-day momentum storage and display.
- Add unit tests for focus-day calculation, persistence, validation, and momentum logic.
- Add UI tests for the basic flow: type tasks -> review -> lock -> complete.

### Product Polish Before TestFlight

- Tighten visual design, spacing, typography, and empty states.
- Add clear lock-confirmation copy that makes the commitment feel intentional.
- Add small completion feedback when all locked tasks are done.
- Improve error states around invalid tasks and rollover edge cases.
- Review accessibility basics: Dynamic Type, VoiceOver labels, tap targets, and contrast.

### Deferred Until After Local Voice MVP

- Start-of-day notifications.
- Periodic focus nudges.
- End-of-day notification actions.
- Settings for reminders, quiet hours, reminder intensity, and prompt times.
- Older iPhone / older iOS compatibility.
- Cloud extraction provider implementation.
- Provider/API strategy decision for optional cloud fallback, such as hosted proxy or BYOK.

### V2 / Later Ideas

- Distraction detection using Screen Time / Family Controls entitlements.
- Distracting apps picker.
- Widgets.
- Live Activities.
- Apple Watch app.
- Siri Shortcuts.
- Multi-language support.
- Full onboarding flow.
- Alternative local model fallback for non-Apple-Foundation-Models devices.
