# 3-things
**radical focus.**

## Current TestFlight MVP Scope

The first shippable milestone is **voice-first and local-AI-first**:

* Record a short voice capture
* Transcribe locally with Apple SpeechAnalyzer/SpeechTranscriber
* Extract 1-3 tasks locally with Apple Foundation Models
* Review extracted tasks, extras, and overflow
* Type 1-3 tasks
* Review validation
* Explicitly confirm the daily lock
* Complete locked tasks
* Roll over at the 2:00 AM local focus-day boundary
* Track rolling 7-day momentum

Manual text entry remains available as a fallback input mode. Cloud extraction, notification reminders, and older-device compatibility are deferred until after the local voice MVP is stable.

### MVP Compatibility

The MVP intentionally targets only devices that can support the local Apple AI stack:

* iPhone 15 Pro
* iPhone 15 Pro Max
* All iPhone 16 models
* All iPhone 17 models

Required OS: whichever iOS version provides Apple SpeechAnalyzer/SpeechTranscriber and Apple Foundation Models APIs. There is no backwards compatibility path yet for older devices or older iOS versions.

## Purpose

**3-things** is a voice-first daily focus app that turns messy spoken thoughts into **1 to 3 actionable tasks**—then **locks them for the rest of the day**. Typing is always available as a fallback.

It’s built for one thing: **radical simplicity and radical focus**.
No endless task lists, no constant reshuffling, no productivity theater. Just a small set of commitments.

## The Core Idea

Most productivity systems fail because they encourage accumulation:

* you add 12 tasks
* you carry them forward
* your list becomes guilt
* you stop trusting it

**3-things** does the opposite.

Every day you choose:

> “These are the 1-3 things that matter today.”

You can edit them immediately after voice capture, but once you confirm, they’re **locked** until the next day. There’s **no carryover**—every morning starts fresh.

### Why max 3?

Because three is the sweet spot:

* small enough to finish
* large enough to matter
* easy to remember
* forces prioritization

More than three turns into avoidance disguised as planning.

### Why “locked for the day”?

Because focus requires protection.

Locking prevents the most common failure mode:

* “I’ll just add one more thing…”
* suddenly you have 9 things
* you finish none
* your day becomes reactive

**3-things** makes your daily plan non-negotiable after confirmation.
You commit once. You execute.

### What the app outputs

At the end of capture + edit, you have:

* **1-3 locked tasks for the day**

### The experience in one line

**Speak → extract → edit → confirm → lock → execute.**

---

## UX Flow (Screen-by-Screen)

**Local Voice MVP path:** the first TestFlight is **capture → transcribe → extract → review → lock → complete**. Items **1)**, **7)**, and **8)** below are **post-MVP** (they require notification scheduling, settings, and notification actions). In-app pending-yesterday finalization in **9)** remains MVP where implemented.

1) **Start-of-Day Prompt** — **post-MVP**
* Daily notification to set your things
* Tap opens capture flow

2) **Capture (Voice or Type)**
* Voice-first recording with clear mic/waveform feedback
* "Type instead" available at all times
* Cancel or re-record if needed

3) **Extraction (Background)**
* Transcript + extraction run out of view
* No transcript review/edit step
* If extraction fails, prompt to retry or type instead

4) **Edit Tasks (Only Edit Step)**
* Pre-filled with extracted tasks (<= 3)
* If overflow, extras appear and user must reduce to <= 3
* Edit text, reorder, replace with extras
* Validation: non-empty, avoid duplicates

5) **Lock Confirmation**
* Explicit warning: tasks lock for the day
* Confirm to lock

6) **Locked Daily View**
* Read-only tasks with progress indicator
* Checkbox completion
* Show momentum (`X/7` completed focus days)
* Completion celebration when all locked tasks are complete

7) **During-Day Nudges (Optional)** — **post-MVP**
* Periodic check-ins
* Distraction alerts if enabled

8) **End-of-Day Check-In** — **post-MVP** (push); in-app finalize-yesterday without push is OK for MVP
* Sent only if the day is not already fully complete
* Yes / Not quite / Remind me later (max 2 deferrals, 30 minutes each)
* "Yes" auto-marks all tasks complete and updates momentum (`X/7`)

9) **Next Day Reset**
* Tasks unlock overnight
* No carryover into the next day
* If the end-of-day check-in was missed, the next morning starts with a quick "Done / Not done" prompt for yesterday before setting today's things
* Once yesterday is finalized, yesterday's result is read-only

## Detailed Feature List

### 1) Daily Task System (Core Rules)

* **1 to 3 tasks per day**
* Tasks are created only during the daily capture flow
* **No adding tasks later**
* **No changing tasks later**
* **Day resets at 2:00 AM local time** (even night owls should be done by then)
* **Before 2:00 AM, activity still belongs to the previous focus day**
* **Timezone source is always current device local timezone**
* Tasks reset / unlock only when the next day starts
* **No carryover**: yesterday's tasks never roll into today

### 2) Task Input: Voice or Text

Voice is the primary input, but **manual text entry is always available** for those who prefer typing.

**Voice Capture:**
* Tap to start recording
* Tap to stop recording
* Optional hold-to-record mode
* Visual recording indicator (mic + waveform)
* Cancel recording (discard)
* Retry / re-record

**Manual Text Input:**
* "Type instead" option always visible
* Direct text fields for up to 3 tasks
* Skip voice entirely if preferred

### 3) On-Device Speech-to-Text (ASR)

* **Local transcription on the phone**
* Use Apple SpeechAnalyzer/SpeechTranscriber for the MVP path
* Optional live streaming transcript while recording
* Final transcript produced at stop
* Basic transcript cleanup:
  * punctuation normalization (optional)
  * trimming filler words (optional)
* Works offline for ASR
* No cloud transcription fallback in MVP

### 4) Transcript Handling (Background Only)

* Transcript is generated on-device and used for extraction
* No transcript review or editing in the core flow
* Transcript stays on device in the MVP

### 5) Extraction: Speech/Text → "Three Things"

* **Runs locally on device for MVP**
* Use Apple Foundation Models as the default extraction engine
* Use structured/guided generation where available to produce typed output instead of fragile JSON strings
* Extract distinct task candidates from transcript
* Normalize tasks into short actionable phrasing
* De-duplicate repeated ideas
* Select up to 3 based on:
  * spoken order
  * clarity/actionability
* Produce a structured extraction result for the edit step (tasks, extras, overflow)
* Voice capture, transcription, and extraction should all work without network on supported devices
* If local extraction is unavailable or fails: prompt immediate manual entry ("Type instead"), no cloud retry queue in MVP

**Local Voice MVP — explicit fallback states**

* **Unsupported device / OS** (below MVP compatibility): show a short explanation that the local voice stack is not supported on this device; primary path is manual text entry (or block install via TestFlight targeting if preferred).
* **Unavailable or disabled on-device AI** (Foundation Models not usable at runtime): same as extraction failure — clear message and **Type instead**; no silent failure.
* **Empty transcript** (user stopped without speech, ASR returned blank): do not call extraction; show guidance to re-record or **Type instead**.
* **Failed extraction** (model error, invalid/empty structured output): reset voice draft, switch to text mode, status includes **Type instead** (already covered by tests).

### 6) Overflow Detection (>3 Things)

If user says more than 3 items:

* App still extracts the best 3 tasks
* Flags overflow: `detected_more_than_3 = true`
* Shows message: “I detected more than 3 things…”
* Shows extras list (what else was detected)
* Prompts user to revise until 1-3 remain

### 7) 1-3 Task Edit Screen (Before Lock)

Before the daily lock triggers, user can:

* Edit text of each selected task (up to 3)
* Reorder tasks (drag/drop)
* Replace a task with one of the detected extras
* Clear & rewrite manually if extraction is off
* Validation rules:
  * at least 1 task must be non-empty
  * no more than 3 tasks can be non-empty
  * discourage duplicates
  * **soft limit: 70 characters** (text turns warning color past this)
  * **hard limit: 100 characters** (cannot type beyond this)
  * once locked, warning styling clears — text displays normal

### 8) Lock Confirmation (Critical UX Moment)

A dedicated step that explicitly warns the user:

* “These things will be locked for today.”
* “You cannot change them after confirming.”
* Confirm button: “Lock Today’s Things”
* Optional double-confirm / hold-to-confirm
* Once locked:
  * edit controls disappear
  * tasks become read-only
  * app shows “Locked until tomorrow” status

### 9) Locked Daily View (Execution Mode)

After lock, the app becomes ultra-minimal:

* Display the locked tasks clearly (1-3)
* Checkbox completion (tap to toggle; unchecking allowed)
* Visual progress indicator (0/N, 1/N, etc.)
* Small completion animation when all locked tasks are done (not a full screen takeover)
* No ability to modify task text

### 10) Focus Reminder System (Active Enforcement) — **post-MVP**

The app doesn't just set tasks—it **actively keeps you focused**. *Not in the first local voice TestFlight; ships after the on-device capture loop is stable.*

**Start-of-Day Prompt:**
* Daily notification to set your things
* Tapping opens the capture flow

**Periodic Check-Ins:**
* Configurable reminder intervals (e.g., every 30 min, 1 hour, 2 hours)
* Gentle nudge: "Still working on your focus tasks?"
* Shows current progress (1/N done, etc.)
* Quick action opens app to choose task completion (no blind completion from notification)

**Distraction Detection (V2 — Not MVP):**
* User defines a list of "distracting apps" (e.g., Twitter, Instagram, TikTok, Reddit)
* When a distracting app is opened, the app **barrages with reminders**:
  * Immediate notification: "You have locked focus tasks. Is this one of them?"
  * Repeated reminders until user returns or dismisses
  * Optional: escalating urgency (more frequent, louder)
* Uses Screen Time API / Device Activity framework on iOS
* Fully opt-in and configurable
* *Deferred: requires special Apple entitlements and complex setup*

**Customization:**
* Enable/disable reminder system
* Set quiet hours (no reminders during sleep, etc.)
* Reminders that fall inside quiet hours are skipped (not delayed)
* Choose reminder intensity: Gentle / Firm / Aggressive

### 11) End-of-Day Check-In — **post-MVP** (push scheduling)

At a configurable evening time, the app prompts you: *(push notification version deferred; MVP may use in-app prompts only.)*

* Prompt is sent only if fewer than all locked tasks are checked complete
* Prompt question: "Did you complete your locked tasks today?"
* Quick options: "Yes, all done!" / "Not quite" / "Remind me later"
* "Yes, all done!" auto-marks all locked tasks complete, then finalizes the day as complete
* "Not quite" finalizes the day as incomplete
* "Remind me later" is limited to 2 deferrals, 30 minutes each
* If all locked tasks are already checked off before EOD time, skip the prompt and finalize the day as complete automatically
* If the EOD check-in is missed, the next morning shows a brief "Done / Not done" prompt for yesterday before today's capture
* Once a day is finalized, that day's result is immutable

### 12) Momentum Tracking (Rolling 7)

Track consistency with a less brittle rolling metric:

* **Primary metric**: `momentum7` = completed focus days in the last 7 focus days
* **Logic**:
  * Finalize each focus day exactly once as complete or incomplete
  * Store outcome per `focusDayID`
  * Compute `momentum7` by counting complete outcomes in the trailing 7 focus days
  * Missing focus-day outcomes in that 7-day window count as incomplete
  * A self-report of "Yes, all done!" counts as complete (and auto-checks all tasks)
  * Focus day boundaries use 2:00 AM in current local timezone (before 2:00 AM belongs to previous day)
* **Display**: Show momentum as `X/7`
* **Minimal storage**: Only rolling completion outcomes for recent focus-day IDs and a last-finalized focus-day marker persist across sessions

### 13) Edge Case Handling

* If user says no clear tasks:
  * prompt: “I didn't catch a clear task—add at least one”
  * allow manual fill
* If user says 1 or 2 tasks:
  * allow lock as-is (no forced fill to 3)
* If extraction is unclear:
  * show top task guesses + ask to restate or edit tasks
* If user rambles:
  * ignore filler, prioritize action statements
* If user lists sub-steps:
  * group into one task unless clearly separate

### 14) Data & Privacy

**Minimal Persistence:**
* Only current focus day's tasks are stored
* Persist only minimal momentum metadata (rolling completion outcomes for recent focus-day IDs + last finalized focus-day marker)
* Previous day plan is wiped once that day is finalized and a new focus day starts
* On reinstall: momentum metadata is lost
* No task history or archive

**Privacy:**
* Audio stays on device
* Transcript text stays on device for MVP extraction
* Cloud extraction is deferred and should be opt-in/fallback only if added later
* **English only** for now

### 15) Settings — **post-MVP** for reminder/EOD scheduling

User-configurable options: *(reminder and EOD timing UI ships with the notification milestone, not the first local voice MVP.)*

* **Reminders**: Enable/disable periodic check-ins
* **Reminder interval**: 30 min / 1 hour / 2 hours
* **Reminder intensity**: Gentle / Firm / Aggressive
* **Quiet hours**: Start and end time (reminders in this window are skipped)
* **End-of-day check-in time**: When to prompt for daily completion
* **Start-of-day prompt time**: When to remind user to set tasks

---

## V2 / Deferred Features

The following are **not in MVP** — punted to later:

| Feature | Why Deferred |
|---------|--------------|
| **Distraction Detection** | Requires Screen Time API / Family Controls entitlement (complex Apple approval process) |
| **Distracting apps list** | Depends on Distraction Detection |
| **Widgets** | Nice-to-have, not core |
| **Live Activities** | Nice-to-have, not core |
| **Apple Watch app** | Nice-to-have, not core |
| **Siri Shortcuts** | Nice-to-have, not core |
| **Multi-language support** | English only for MVP |
| **Onboarding flow** | Ship fast, add polish later |
| **Older iPhone / older iOS support** | MVP intentionally targets iPhone 15 Pro/Pro Max and all iPhone 16/17 devices only |
| **Cloud extraction fallback** | Add only after local MVP is validated |
| **Start-of-day / periodic reminder notifications** | Post-MVP |
| **EOD push + notification actions** | Post-MVP |
| **Reminder interval, quiet hours, intensity settings** | Post-MVP |
