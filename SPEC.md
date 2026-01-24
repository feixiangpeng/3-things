# 3-things
**radical focus.**

## Purpose

**3-things** is a voice-first daily focus app that turns messy spoken thoughts into **exactly three actionable tasks**—then **locks them for the rest of the day**. Typing is always available as a fallback.

It’s built for one thing: **radical simplicity and radical focus**.
No endless task lists, no constant reshuffling, no productivity theater. Just three commitments.

## The Core Idea

Most productivity systems fail because they encourage accumulation:

* you add 12 tasks
* you carry them forward
* your list becomes guilt
* you stop trusting it

**3-things** does the opposite.

Every day you choose:

> “These are the only three things that matter today.”

You can edit them immediately after voice capture, but once you confirm, they’re **locked** until the next day. There’s **no carryover**—every morning starts fresh.

### Why only 3?

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

* **3 locked tasks for the day**
* optional transcript stored for reference (not part of the core UI)

### The experience in one line

**Speak → extract → edit → confirm → lock → execute.**

---

## UX Flow (Screen-by-Screen)

1) **Start-of-Day Prompt**
* Daily notification to set your 3 things
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
* If overflow, extras appear and user must reduce to 3
* Edit text, reorder, replace with extras
* Validation: non-empty, avoid duplicates

5) **Lock Confirmation**
* Explicit warning: tasks lock for the day
* Confirm to lock

6) **Locked Daily View**
* Read-only tasks with progress indicator
* Checkbox completion
* Show current streak
* Completion celebration at 3/3

7) **During-Day Nudges (Optional)**
* Periodic check-ins
* Distraction alerts if enabled

8) **End-of-Day Check-In**
* Yes / Not quite / Remind me later
* Updates current streak

9) **Next Day Reset**
* Tasks unlock overnight
* No carryover into the next day
* If the end-of-day check-in was missed, the next morning starts with a quick completion prompt for yesterday before setting today's 3 things

## Detailed Feature List

### 1) Daily Task System (Core Rules)

* Exactly **3 tasks per day**
* Tasks are created only during the daily capture flow
* **No adding tasks later**
* **No changing tasks later**
* Tasks reset / unlock only when the next day starts
* **No carryover**: yesterday’s tasks never roll into today

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
* Direct text field for each of the 3 tasks
* Skip voice entirely if preferred

### 3) On-Device Speech-to-Text (ASR)

* **Local transcription on the phone**
* Optional live streaming transcript while recording
* Final transcript produced at stop
* Basic transcript cleanup:
  * punctuation normalization (optional)
  * trimming filler words (optional)
* Works offline for ASR

### 4) Transcript Handling (Background Only)

* Transcript is generated on-device and used for extraction
* No transcript review or editing in the core flow

### 5) Extraction: Speech/Text → “Three Things”

* Extract distinct task candidates from transcript
* Normalize tasks into short actionable phrasing
* De-duplicate repeated ideas
* Select the top 3 based on:
  * spoken order
  * clarity/actionability
  * confidence (if supported)
* Produce a structured extraction result for the edit step (tasks, extras, overflow)

### 6) Overflow Detection (>3 Things)

If user says more than 3 items:

* App still extracts the best 3 tasks
* Flags overflow: `detected_more_than_3 = true`
* Shows message: “I detected more than 3 things…”
* Shows extras list (what else was detected)
* Prompts user to revise until only 3 remain

### 7) 3-Task Edit Screen (Before Lock)

Before the daily lock triggers, user can:

* Edit text of each of the 3 tasks
* Reorder tasks (drag/drop)
* Replace a task with one of the detected extras
* Clear & rewrite manually if extraction is off
* Validation rules:
  * all 3 must be non-empty
  * discourage duplicates
  * keep length reasonable

### 8) Lock Confirmation (Critical UX Moment)

A dedicated step that explicitly warns the user:

* “These 3 things will be locked for today.”
* “You cannot change them after confirming.”
* Confirm button: “Lock Today’s 3 Things”
* Optional double-confirm / hold-to-confirm
* Once locked:
  * edit controls disappear
  * tasks become read-only
  * app shows “Locked until tomorrow” status

### 9) Locked Daily View (Execution Mode)

After lock, the app becomes ultra-minimal:

* Display the 3 tasks clearly
* Checkbox completion
* Visual progress indicator (0/3, 1/3, etc.)
* Completion celebration when all 3 are done (e.g., a positive full-screen moment)
* No ability to modify tasks
* Optional “reflection note” (doesn’t alter tasks)

### 10) Focus Reminder System (Active Enforcement)

The app doesn't just set tasks—it **actively keeps you focused**.

**Start-of-Day Prompt:**
* Daily notification to set your 3 things
* Tapping opens the capture flow

**Periodic Check-Ins:**
* Configurable reminder intervals (e.g., every 30 min, 1 hour, 2 hours)
* Gentle nudge: "Still working on your 3 things?"
* Shows current progress (1/3 done, etc.)
* Quick "Mark Complete" action from notification

**Distraction Detection (Aggressive Mode):**
* User defines a list of "distracting apps" (e.g., Twitter, Instagram, TikTok, Reddit)
* When a distracting app is opened, the app **barrages with reminders**:
  * Immediate notification: "You have 3 things. Is this one of them?"
  * Repeated reminders until user returns or dismisses
  * Optional: escalating urgency (more frequent, louder)
* Uses Screen Time API / Device Activity framework on iOS
* Fully opt-in and configurable

**Customization:**
* Enable/disable reminder system
* Set quiet hours (no reminders during sleep, etc.)
* Choose reminder intensity: Gentle / Firm / Aggressive

### 11) End-of-Day Check-In

At a configurable evening time, the app prompts you:

* "Did you complete your 3 things today?"
* Quick options: "Yes, all done!" / "Not quite" / "Remind me later"
* If all 3 are already checked off, auto-congratulates
* If incomplete, gentle prompt to reflect (no judgment)
* Triggers streak update logic
* If the check-in is skipped, the next morning begins with a brief completion check for yesterday before starting today's capture

### 12) Streak Tracking (Dead Simple)

Track consistency with the simplest possible model:

* **One integer**: `currentStreak`
* **Logic**:
  * If all 3 tasks completed today: `currentStreak += 1`
  * If day ends with incomplete tasks: `currentStreak = 0`
* **Display**: Show current streak prominently
* **No date tracking**: Just one number. That's it.

### 13) Edge Case Handling

* If user says fewer than 3 tasks:
  * prompt: “I only caught 2—add one more”
  * allow manual fill
* If extraction is unclear:
  * show top task guesses + ask to restate or edit tasks
* If user rambles:
  * ignore filler, prioritize action statements
* If user lists sub-steps:
  * group into one task unless clearly separate

### 14) Privacy / Local-First

* Audio stays on device (primary design)
* Only transcript text ever needs to leave device (if using cloud extraction)
* Optional offline-only mode for everything
