# Implementation Plan (iOS)

This document outlines the step-by-step implementation strategy for **3-things** as a native iOS application.

## High-Level Stack
*   **Language**: Swift 6
*   **UI Framework**: SwiftUI
*   **Architecture**: MVVM (Model-View-ViewModel) + Coordinator pattern for flow
*   **Persistence**: SwiftData (or Core Data if backward compatibility needed < iOS 17)
*   **Speech**: `SFSpeechRecognizer` + `AVAudioEngine`
*   **Local Intelligence**: CoreML / NaturalLanguage framework (or simple heuristic fallback for MVP)
*   **Focus Enforcement**: `DeviceActivityMonitor` (Screen Time API) + `UserNotifications`

---

## Phase 1: Project Setup & Foundation
- [ ] **Initialize Xcode Project**:
    - Create new iOS App with SwiftUI.
    - Deployment Target: iOS 17.0+ (to leverage SwiftData and latest SwiftUI macros).
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
- [ ] **Data Model (SwiftData)**:
    - Create models:
      ```swift
      @Model
      class DailyPlan {
          var date: Date
          var isLocked: Bool
          var source: String // "voice" or "text"
          var transcript: String? // stored for extraction/debug only
          @Relationship(.cascade) var tasks: [TaskItem]
          var extras: [String]
          var detectedMoreThanThree: Bool
      }
      
      @Model 
      class TaskItem {
          var text: String
          var isCompleted: Bool
          var sortOrder: Int
      }
      ```
    - Store app-level state (UserDefaults or SwiftData):
      ```swift
      var currentStreak: Int = 0
      ```
- [ ] **DataManager**:
    - Singleton or dependency-injected service to handle fetching/saving the "Current Day".
    - "New Day" logic: On app launch, check if today's `DailyPlan` exists; if not, create it.
    - Enforce no carryover: never prefill tasks from a prior day.

## Phase 3: Feature Implementation

### 3.1: Task Input (Voice or Text)
- [ ] **Audio Permissions**: Handle `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`.
- [ ] **Speech Manager**:
    - Wrapper around `SFSpeechRecognizer`.
    - Functions: `startRecording()`, `stopRecording()`, `cancelRecording()`.
    - Produce transcript for extraction (no transcript UI).
- [ ] **Manual Text Input**:
    - "Type instead" toggle on CaptureView.
    - Direct `TextField` entry for each of the 3 tasks.
    - Skip voice flow entirely if user prefers typing.
- [ ] **Haptics**: Add haptic feedback for start/stop/fail.

### 3.2: Extraction Logic
- [ ] **Extraction Service**:
    - Input: Raw String.
    - Output: structured JSON model (tasks, extras, overflow flag) for the edit step.
- [ ] **Strategy**:
    - *MVP*: Regex/NLP heuristics (split by "and", "then", newlines, identifying verbs).
    - *V2*: On-device `NLModel` or API call (if permitted) to extract structured data.

### 3.3: Edit & Confirm Flow
- [ ] **EditView**:
    - `List` or `ForEach` with editable `TextField` rows.
    - Drag-and-drop capability using `.onMove`.
    - "Extras" drawer at the bottom when overflow is detected.
    - No transcript review/edit step; only final task editing.
- [ ] **Validation**:
    - Compute property `isValid` (count == 3 && !empty).
    - Disable Lock button if invalid.

### 3.4: The Lock Mechanism
- [ ] **Lock Confirmation Sheet**:
    - Custom modal with "scary/serious" warning text.
    - Action: Update `dailyPlan.isLocked = true`, save context.
    - Trigger "Locking" animation.

### 3.5: Locked Execution Mode
- [ ] **LockedView**:
    - Read-only display of tasks.
    - Tap to toggle completion (strikethrough animation).
    - Show completion celebration when all 3 are done.

### 3.6: Focus Reminder System
- [ ] **Start-of-Day Prompt**:
    - Schedule a daily notification to set the day's 3 things.
    - Tap opens the capture flow.
- [ ] **Periodic Check-Ins**:
    - Use `UNUserNotificationCenter` for local notifications.
    - Configurable intervals (30 min, 1 hr, 2 hr).
    - Notification content: "Still working on your 3 things?" + progress.
    - Actionable notification with "Mark Complete" quick action.
- [ ] **Distraction Detection** (Advanced):
    - Request Family Controls entitlement (Screen Time API).
    - Use `DeviceActivityMonitor` to detect when "distracting apps" are opened.
    - Define user-configurable list of distracting apps.
    - On detection: Fire immediate notification barrage.
    - Escalation logic: increase frequency if user stays in distracting app.
- [ ] **Settings View**:
    - Enable/disable reminders toggle.
    - Quiet hours picker (start/end time).
    - Reminder intensity selector (Gentle / Firm / Aggressive).
    - Distracting apps picker (uses `FamilyActivitySelection`).

### 3.7: End-of-Day Check-In
- [ ] **EOD Notification**:
    - Schedule local notification at configurable evening time.
    - Content: "Did you complete your 3 things today?"
    - Actionable buttons: "Yes!" / "Not quite" / "Remind me later"
- [ ] **Auto-Completion Detection**:
    - If all 3 tasks already marked complete, skip prompt and show celebration.
    - Trigger streak update automatically.
- [ ] **Missed Check-In Fallback**:
    - If the EOD check-in is missed, show a quick completion prompt the next morning before new capture.
    - Apply responses to the current streak, then proceed to the capture flow.

### 3.8: Streak Tracking
- [ ] **Streak Logic**:
    - On EOD check-in completion:
      - If all 3 done: `currentStreak += 1`
      - If incomplete: `currentStreak = 0`
- [ ] **Streak Display**:
    - Show `currentStreak` prominently on LockedView.

## Phase 4: Polish & Experience
- [ ] **Micro-interactions**:
    - Hero animations when transitioning from Edit -> Locked.
    - Confetti or subtle success haptic on completing all 3.
- [ ] **Accessibility**:
    - Proper VoiceOver labels for custom controls.
    - Dynamic Type support.

## Phase 5: Performance & Debug (Optional)
- [ ] **Performance + Cost**:
    - Keep ASR local to reduce latency and cost.
    - Cache extraction results until transcript changes.
    - Ensure single extraction call per capture session.
- [ ] **Debug Utilities**:
    - Debug screen with raw transcript, extracted candidates, overflow extras, final JSON, timing/confidence.

## Phase 6: Verification & Beta
- [ ] **Unit Tests**:
    - Test Extraction logic.
    - Test DataManager persistence (Create/Read/Update).
- [ ] **UI Tests**:
    - Record flow -> Edit -> Lock.
