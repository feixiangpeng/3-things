# Implementation Plan (iOS)

This document outlines the step-by-step implementation strategy for **3-things** as a native iOS application.

## Current Milestone: Voice-First Local-AI TestFlight MVP

Ship a private beta with the core daily commitment loop and private on-device voice-to-task extraction:

* Voice capture for short spoken task dumps
* Local transcription with Apple SpeechAnalyzer/SpeechTranscriber
* Local extraction with Apple Foundation Models
* Review extracted tasks, extras, and overflow before locking
* Text entry for 1-3 things
* Validation for empty, duplicate, and overlong tasks
* Explicit lock confirmation
* Read-only locked execution mode with reversible completion toggles
* 2:00 AM local focus-day rollover
* Pending yesterday finalization when a locked day was not completed
* Rolling 7-day momentum

Deferred until the next milestone: cloud extraction fallback, older-device compatibility, start-of-day reminders, periodic nudges, and end-of-day notification actions.

MVP device compatibility is intentionally narrow: iPhone 15 Pro, iPhone 15 Pro Max, and all iPhone 16 / iPhone 17 models. Required OS is whichever iOS version provides Apple SpeechAnalyzer/SpeechTranscriber and Apple Foundation Models APIs. No backwards compatibility path is required yet.

## High-Level Stack
*   **Language**: Swift 6
*   **UI Framework**: SwiftUI
*   **Architecture**: MVVM (Model-View-ViewModel) + Coordinator pattern for flow
*   **Persistence**: UserDefaults + Codable (minimal, no history)
*   **Speech (ASR)**: Apple SpeechAnalyzer/SpeechTranscriber (on-device)
*   **Extraction**: Apple Foundation Models (on-device, structured/guided generation where available)
*   **Notifications / reminders / EOD prompts**: **Post-MVP**. Not part of the first local voice TestFlight. `UNUserNotificationCenter` and reminder settings ship after the capture–extract–review–lock loop is stable.
*   **Distraction Detection**: deferred to V2 (Family Controls)

---

## Phase 1: Project Setup & Foundation
- [ ] **Initialize Xcode Project**:
    - Create new iOS App with SwiftUI.
    - Deployment target: the minimum iOS version that supports Apple SpeechAnalyzer/SpeechTranscriber and Apple Foundation Models.
    - Supported devices for MVP: iPhone 15 Pro, iPhone 15 Pro Max, and all iPhone 16 / iPhone 17 models.
    - Do not implement backwards compatibility for older devices yet.
    - Setup strict linting (SwiftLint).
- [ ] **Design System (SwiftUI)**:
    - Define `Color+Extensions.swift`: `primaryAction`, `locked`, `background`.
    - Define `Font+Extensions.swift`: Custom typography.
    - Create centralized `Theme` struct.
    - Establish focus-first layout rules (generous spacing, large tap targets, minimal UI noise).
- [ ] **Core Components**:
    - `PrimaryButton`: Custom interactive button styles.
    - `TaskRowView`: The card for individual tasks.
    - `MicVisualizerView`: Waveform animation component.

## Phase 2: Core Data & State
- [ ] **Data Model (Minimal — No History)**:
    - Only store current focus-day plan (prior finalized plans are wiped; no history):
      ```swift
      // UserDefaults or simple file storage (no SwiftData needed for this)
      struct DailyPlan: Codable {
          var focusDayID: String
          var createdAt: Date
          var isLocked: Bool
          var source: String // "voice" or "text"
          var tasks: [TaskItem]
          var extras: [String]
          var detectedMoreThanThree: Bool
      }
      
      struct TaskItem: Codable {
          var text: String  // soft warning at 70 chars, hard limit at 100 chars
          var isCompleted: Bool
          var sortOrder: Int
      }
      ```
    - Persistent app-level state (UserDefaults):
      ```swift
      var momentumOutcomes: [String: Bool] = [:] // focusDayID -> completed
      var lastFinalizedFocusDayID: String? = nil
      ```
- [ ] **DataManager**:
    - Singleton or dependency-injected service.
    - **Day boundary**: 2:00 AM local time (current device timezone).
    - Focus-day identity rule: any activity before 2:00 AM belongs to the previous focus day.
    - On app launch:
      - Resolve `currentFocusDayID` from local timezone + 2:00 AM cutoff.
      - Prune `momentumOutcomes` to the trailing 7 focus days.
      - If yesterday is unfinalized, show a blocking "Done / Not done" prompt before today's capture flow.
      - Create or load current focus-day `DailyPlan`.
      - Wipe finalized plan data from prior focus days (no history retention).
    - Enforce no carryover: never prefill tasks from a prior day.

## Phase 3: Feature Implementation

### 3.1: Task Input (Voice or Text)
- [ ] **Audio Permissions**: Handle `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`.
- [ ] **Speech Manager**:
    - Wrapper around Apple SpeechAnalyzer/SpeechTranscriber.
    - Functions: `startRecording()`, `stopRecording()`, `cancelRecording()`.
    - Produce transcript for extraction (no transcript UI).
- [ ] **Manual Text Input**:
    - "Type instead" toggle on CaptureView.
    - Direct `TextField` entry for up to 3 tasks.
    - Skip voice flow entirely if user prefers typing.
- [ ] **Haptics**: Add haptic feedback for start/stop/fail.

### 3.2: Extraction Logic
- [ ] **Extraction Service**:
    - Input: Raw transcript string.
    - Output: typed structured model (tasks, extras, overflow flag) for the edit step.
    - **Runs on device** with Apple Foundation Models.
- [ ] **Foundation Models Strategy**:
    - Use guided/structured generation where available instead of asking for raw JSON.
    - Define a Swift extraction output type for selected tasks, extras, overflow, and cleaned transcript.
    - Keep prompt/rules short and deterministic: select 1-3 actionable tasks, dedupe, preserve spoken priority, put overflow in extras.
    - No cloud provider, API key, or BYOK path in MVP.
- [ ] **Offline Handling**:
    - Allow voice capture, on-device ASR, and on-device extraction when offline on supported devices.
    - If local extraction fails or local AI is unavailable: show immediate "Type instead" fallback.
    - Do not queue background retry or cloud fallback for extraction in MVP.

### 3.3: Edit & Confirm Flow
- [ ] **EditView**:
    - `List` or `ForEach` with editable `TextField` rows.
    - Drag-and-drop capability using `.onMove`.
    - "Extras" drawer at the bottom when overflow is detected.
    - No transcript review/edit step; only final task editing.
- [ ] **Validation**:
    - Compute property `isValid` (1...3 non-empty tasks && all <= 100 chars).
    - Disable Lock button if invalid.
    - Character limit UX:
      - 0-70 chars: normal text color
      - 71-100 chars: warning color (orange/red)
      - 100+ chars: input blocked
    - On lock confirmation, warning color clears to normal.

### 3.4: The Lock Mechanism
- [ ] **Lock Confirmation Sheet**:
    - Custom modal with "scary/serious" warning text.
    - Action: Update `dailyPlan.isLocked = true`, save context.
    - Trigger "Locking" animation.

### 3.5: Locked Execution Mode
- [ ] **LockedView**:
    - Read-only display of locked tasks (1-3, text not editable).
    - Tap checkbox to toggle completion (strikethrough animation).
    - Unchecking allowed (no confirmation needed).
    - Small completion animation when all locked tasks are done (not full-screen).

### 3.6–3.7: Reminders, settings, and EOD notifications (post-MVP)

**Not in the first local voice TestFlight.** The checklist below is retained as the product backlog after the local voice core ships. Do not schedule `UNUserNotificationCenter` work for the local voice MVP.

<details>
<summary>Backlog: Focus Reminder System (3.6)</summary>

- Start-of-day prompt notification; periodic check-ins; settings for reminders, quiet hours, intensity; distraction detection remains V2.

</details>

<details>
<summary>Backlog: End-of-Day Check-In (3.7)</summary>

- EOD notification scheduling, notification actions, missed-check-in flows. The app may still use **in-app** pending-yesterday finalization (sheet on launch) without push notifications.

</details>

### 3.8: Momentum Tracking (Rolling 7)
- [ ] **Momentum Logic**:
    - Finalize each focus day exactly once with an outcome: complete or incomplete.
    - If self-report is "Yes, all done!": auto-check all tasks, then finalize complete.
    - Persist each finalized outcome in `momentumOutcomes[focusDayID]`.
    - Keep only trailing 7 focus-day outcomes in storage.
    - Compute `momentum7 = number of complete outcomes in trailing 7 focus days`.
    - Missing focus-day outcomes in that window count as incomplete.
    - Persist `lastFinalizedFocusDayID` for day-finalization flow control.
- [ ] **Momentum Display**:
    - Show momentum as `X/7` prominently on LockedView.

## Phase 4: Polish & Experience
- [ ] **Micro-interactions**:
    - Hero animations when transitioning from Edit -> Locked.
    - Small success animation + haptic on completing all locked tasks (not full-screen confetti).
- [ ] **Constraints**:
    - English only for MVP.
    - MVP device support only: iPhone 15 Pro/Pro Max and all iPhone 16/17 models.
    - No older-device or older-iOS fallback yet.
    - Task text: soft limit 70 chars (warning color), hard limit 100 chars (blocked).
    - On lock, warning styling clears to normal.

## Phase 5: Performance & Debug (Optional)
- [ ] **Performance + Cost**:
    - Keep ASR and extraction local to reduce latency and cost.
    - Cache extraction results until transcript changes.
    - Ensure single extraction call per capture session.
- [ ] **Debug Utilities**:
    - Debug screen with raw transcript, extracted candidates, overflow extras, final JSON, timing/confidence.

## Phase 6: Verification & Beta
- [ ] **Unit Tests**:
    - Test Extraction logic.
    - Test DataManager persistence + focus-day boundary logic (Create/Read/Update).
    - Test rolling 7-day momentum computation (including missed/unfinalized days counting as incomplete).
    - EOD finalize paths via **push notifications**: deferred; add tests when that milestone ships.
- [ ] **UI Tests**:
    - Record flow -> Edit -> Lock.

---

## V2 / Deferred (Not MVP)

| Feature | Notes |
|---------|-------|
| **Distraction Detection** | Requires Family Controls entitlement, complex Apple approval |
| **Distracting apps picker** | Depends on above |
| **Widgets** | Low priority, add after core is solid |
| **Live Activities** | Low priority |
| **Apple Watch** | Low priority |
| **Siri Shortcuts** | Low priority |
| **Multi-language** | English only for now |
| **Onboarding** | Add polish later |
| **Accessibility** | VoiceOver, Dynamic Type (add after MVP) |
| **Older-device compatibility** | Add after local MVP; not needed for first beta |
| **Cloud extraction fallback** | Optional later path for unsupported devices or power users |
| **Start-of-day / periodic reminder notifications** | Post-MVP; not in first local voice TestFlight |
| **EOD push notification + notification actions** | Post-MVP; in-app yesterday finalization can ship without push |
| **Reminder / EOD settings UI** | Post-MVP; ships with notification milestone |
