# Voice Extraction Behavior

This file describes desired behavior for transcript -> task extraction.

Overall product goal: voice capture should feel natural, forgiving, and pleasant. The model should help the user get from messy speech to a tiny editable list, but it must not invent work the user did not say.

Core rule: **literal-first, no invention, editable over clever.**

The app should extract the user's stated commitments, not what a productivity coach guesses they meant.

## Eval Philosophy

This should be tested semantically, not by exact string equality.

For each scenario, we should have multiple transcript variants:

- clean wording
- filler-heavy wording (`um`, `uh`, `like`, `so`, `I guess`)
- casual speech
- ASR-ish punctuation
- corrections and backtracking
- reordered phrasing

For each transcript, run extraction multiple times:

- dev loop: `passRate@5`
- release gate: `passRate@10`

Important metrics:

- `passRate@N`: how many runs produce an acceptable review draft
- `firstPass`: whether the first run passed, because the user only sees one run
- `hallucinationCount`: selected/extras containing invented meanings
- `overflowWrongCount`: model says `>3` when there are only 1-3 explicit tasks, or misses true overflow
- `emptyWrongCount`: model extracts tasks from mic tests / filler / no-task speech

Classic `pass@N` ("at least one run passed") is useful for capability, but product quality mostly depends on stability. A 1/10 pass rate means the model can do it, but the UX is bad.

## Semantic Pass Rubric

An extraction passes if:

- selected tasks match the user's explicit stated task meanings
- extras include only explicit stated additional task meanings
- no selected task or extra is inferred from context alone
- `detectedMoreThanThree` is true only when more than 3 distinct explicit tasks were stated
- corrections are respected: the final corrected intent wins
- duplicates are collapsed
- vague-but-stated commitments are preserved as editable tasks instead of over-inferred
- no-task transcripts produce no draft and a "No tasks extracted from transcript" style fallback

An extraction fails if:

- it invents extras or selected tasks
- it rewrites a vague task into a more specific task the user did not say
- it treats examples, filler, or mic tests as real tasks
- it ignores "never mind", "scratch that", "actually", or replacement language
- it marks overflow for exactly 1-3 explicit tasks

## Product Defaults To Decide

Current recommendation:

- Inference: mostly not allowed.
- Light wording cleanup: allowed.
- Vague tasks: allowed if explicitly stated.
- Future tasks (`tomorrow`, `next week`): likely exclude unless user frames them as today's task to prepare/schedule.
- Subtasks: group under a parent if clearly part of one larger commitment.
- Negative commitments (`don't scroll Twitter`): probably valid as a task if explicitly stated.

## Eval Categories And Starter Cases

### 1. Literal 1-3 Tasks

Goal: extract exactly the explicit tasks, no extras, no inferred details.

#### Case literal_three_store_park_food

Transcripts:

- `Go to a store, go to the park, and eat food.`
- `Um, I need to go to a store, uh, go to the park, and eat food.`
- `So today I guess the things are go to a store, go to the park, and eat food.`
- `Go to the store. Go to the park. Eat food.`
- `I just need to go to a store and then go to the park and then eat food.`

Expected selected meanings:

- go to a store
- go to the park
- eat food

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- buy groceries
- enjoy the park
- prepare dinner
- organize errands

#### Case literal_one_email

Transcripts:

- `Email Sam.`
- `Uh, email Sam. That's the main thing.`
- `I need to email Sam today.`
- `Could you put email Sam as my thing?`
- `Email Sam about the proposal.`

Expected selected meanings:

- email Sam

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- write proposal
- schedule meeting with Sam
- follow up with client

#### Case literal_two_call_and_pay

Transcripts:

- `Call mom and pay rent.`
- `Um, call mom, uh, and pay rent.`
- `Today, call my mom and pay rent.`
- `The two things are call mom and pay the rent.`
- `I need to call mom. Also pay rent.`

Expected selected meanings:

- call mom
- pay rent

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- visit mom
- budget finances
- pay bills generally

### 2. Overflow: More Than 3 Explicit Tasks

Goal: select up to 3 and put the rest in extras. Lock should be blocked until extras are resolved/discarded.

#### Case overflow_four_clean

Transcripts:

- `Email Sam, pay rent, buy milk, and call mom.`
- `Um, email Sam, pay rent, buy milk, call mom.`
- `Today I need to email Sam. Pay rent. Buy milk. Call mom.`
- `The list is email Sam, pay rent, buy milk, and call my mom.`
- `Okay, things: email Sam, pay rent, buy milk, call mom.`

Expected selected meanings:

- email Sam
- pay rent
- buy milk

Expected extras meanings:

- call mom

Expected overflow: true

Forbidden/invented meanings:

- grocery shopping beyond milk
- family planning
- financial planning

#### Case overflow_six_messy

Transcripts:

- `Uh today I need to finish the deck, call Alex, book dentist, buy milk, clean the kitchen, and return the package.`
- `So, finish the deck, um, call Alex, book the dentist, buy milk, clean kitchen, return package.`
- `I have too much. Finish deck. Call Alex. Dentist. Milk. Kitchen. Return package.`
- `The things are finish the deck, call Alex, book a dentist appointment, buy milk, clean the kitchen, and return the package.`
- `Okay, finish deck, call Alex, book dentist, buy milk, clean kitchen, return package, that's too many.`

Expected selected meanings:

- finish the deck
- call Alex
- book dentist

Expected extras meanings:

- buy milk
- clean the kitchen
- return the package

Expected overflow: true

Forbidden/invented meanings:

- prepare presentation, unless equivalent to finish deck
- go to dentist
- grocery shopping beyond buy milk

#### Case overflow_one_extra_only

Transcripts:

- `Do laundry, submit timesheet, text Jamie, and take out trash.`
- `Um, laundry, submit the timesheet, text Jamie, take out trash.`
- `I need to do laundry. Submit timesheet. Text Jamie. Take out the trash.`
- `The tasks are do laundry, submit my timesheet, text Jamie, take out trash.`
- `Do the laundry, submit timesheet, text Jamie, and trash.`

Expected selected meanings:

- do laundry
- submit timesheet
- text Jamie

Expected extras meanings:

- take out trash

Expected overflow: true

Forbidden/invented meanings:

- clean house
- message team
- organize chores

### 3. Corrections And Cancellations

Goal: respect "never mind", "scratch that", "actually", and replacements.

#### Case correction_never_mind_single

Transcripts:

- `Go to the park, wait never mind, go to the store.`
- `Uh go to the park. Actually no, scratch that, go to the store.`
- `I was going to say go to the park, but never mind. Go to the store.`
- `Go to park, no, go to store.`
- `Let's do go to the park. Wait, cancel that. Go to the store.`

Expected selected meanings:

- go to the store

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- go to the park
- buy groceries

#### Case correction_replace_call_with_text

Transcripts:

- `Call Alex, actually make that text Alex.`
- `I need to call Alex. Wait, no, text Alex instead.`
- `Call Alex, scratch that, text Alex.`
- `Uh, text Alex, not call Alex.`
- `Put text Alex. I said call at first but I mean text.`

Expected selected meanings:

- text Alex

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- call Alex
- schedule with Alex

#### Case correction_remove_one_keep_others

Transcripts:

- `Email Sam, go to the gym, actually skip gym, and pay rent.`
- `Email Sam, gym, no gym today, pay rent.`
- `I need email Sam, go gym, wait never mind on gym, pay rent.`
- `Email Sam. Scratch going to the gym. Pay rent.`
- `Put email Sam and pay rent. I almost said gym but not today.`

Expected selected meanings:

- email Sam
- pay rent

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- go to gym
- exercise

### 4. Duplicates And Rephrases

Goal: collapse duplicated intent without creating extras.

#### Case duplicate_email_sam

Transcripts:

- `Email Sam, send Sam an email, and pay rent.`
- `Uh email Sam, like send him the email, and pay rent.`
- `I need to email Sam, email Sam about the thing, and pay rent.`
- `Email Sam. Also send Sam the email. And pay rent.`
- `The tasks are email Sam and pay rent. I said email Sam twice.`

Expected selected meanings:

- email Sam
- pay rent

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- follow up with Sam as a separate task
- write email draft as separate from send email

#### Case duplicate_grocery_wording

Transcripts:

- `Buy milk, get milk from the store, and call mom.`
- `Uh buy milk, pick up milk, call mom.`
- `Need milk, buy milk, and call mom.`
- `Go get milk, buy milk, call mom.`
- `Milk from store, buy milk, call mom.`

Expected selected meanings:

- buy/get milk
- call mom

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- grocery shopping generally
- go to store as a separate task, unless the task is explicitly get milk from store

### 5. No Task / Mic Test / Filler

Goal: no draft. Show no-tasks fallback.

#### Case no_task_testing

Transcripts:

- `Hello? Testing, testing.`
- `Um, hello, is this working?`
- `Testing one two three.`
- `Uh, I don't know, just testing the mic.`
- `This is a test. Hello hello.`

Expected selected meanings: none

Expected extras: none

Expected overflow: false

Expected behavior:

- no draft
- message should say no tasks extracted from transcript

Forbidden/invented meanings:

- prepare for meeting
- review emails
- call client
- organize workspace
- set reminders

#### Case no_task_random_talk

Transcripts:

- `I'm tired and I don't really know what I'm doing today.`
- `Uh, today feels weird. I need coffee.`
- `I'm just talking to see what happens.`
- `So yeah, lots going on, not sure yet.`
- `I don't have tasks right now.`

Expected selected meanings: none, except possibly `get coffee` only if we decide "I need coffee" is a task

Expected extras: none

Expected overflow: false

Product decision:

- decide whether "I need coffee" is a task or just context

Forbidden/invented meanings:

- plan day
- rest
- organize priorities

### 6. Inference Traps

Goal: do not infer hidden goals from explicit words.

#### Case inference_store_only

Transcripts:

- `Go to the store.`
- `Uh, go to a store.`
- `I need to go to the store today.`
- `Put go to the store.`
- `The only thing is go to the store.`

Expected selected meanings:

- go to the store

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- buy groceries
- buy milk
- run errands

#### Case inference_eat_food_only

Transcripts:

- `Eat food.`
- `Uh, eat food today.`
- `I need to eat lunch.`
- `Put eat food as a thing.`
- `Honestly just eat a meal.`

Expected selected meanings:

- eat food / eat lunch / eat a meal

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- prepare dinner
- cook meal
- meal prep
- grocery shop

#### Case inference_doctor

Transcripts:

- `Call the doctor.`
- `Uh call my doctor.`
- `I need to call the doctor today.`
- `Call the doctor office.`
- `Put call doctor.`

Expected selected meanings:

- call the doctor

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- schedule appointment, unless explicitly said
- go to doctor
- refill prescription

### 7. Rambling But Actionable

Goal: ignore filler, extract explicit commitments.

#### Case ramble_two_clear_tasks

Transcripts:

- `I have a lot going on, um, but really today I need to finish the deck and book the dentist.`
- `So I'm kind of scattered. The actual things are finish the deck and book dentist.`
- `Uh there's too much, but today: finish deck, book dentist.`
- `I keep thinking about work and health. I need to finish the deck and book the dentist appointment.`
- `Okay, don't overthink it, finish deck and book dentist.`

Expected selected meanings:

- finish the deck
- book dentist

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- manage health
- plan work
- reduce stress

#### Case ramble_three_clear_tasks

Transcripts:

- `Um okay so today I need to ship the build, reply to Nora, and clean my desk. That's it.`
- `Lots of stuff, but only three: ship build, reply to Nora, clean desk.`
- `I guess the three are ship the build, reply to Nora, and clean the desk.`
- `Ship the app build. Reply to Nora. Clean desk. The rest can wait.`
- `For focus today: ship build, reply to Nora, clean my desk.`

Expected selected meanings:

- ship the build
- reply to Nora
- clean desk

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- prepare release notes
- organize office
- message team

### 8. Vague But Stated

Goal: preserve vague-but-stated commitments as editable tasks instead of over-inferred specifics.

#### Case vague_taxes

Transcripts:

- `Figure out taxes.`
- `Uh, deal with taxes.`
- `I need to handle tax stuff today.`
- `Put taxes as one thing, I know it's vague.`
- `Work on taxes for an hour.`

Expected selected meanings:

- figure out/deal with taxes

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- file tax return, unless explicitly said
- call accountant, unless explicitly said
- gather receipts, unless explicitly said

#### Case vague_apartment

Transcripts:

- `Deal with apartment stuff.`
- `Um, handle the apartment situation.`
- `I need to work on apartment things today.`
- `Apartment stuff, that's one of the things.`
- `Figure out the apartment issue.`

Expected selected meanings:

- deal with apartment stuff

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- call landlord, unless explicitly said
- pay rent, unless explicitly said
- clean apartment, unless explicitly said

### 9. Subtasks / Grouping

Goal: group substeps when they clearly belong to one parent commitment.

#### Case substeps_launch_email

Transcripts:

- `For the launch email, write the subject line, draft the body, and send it.`
- `Launch email: subject line, body, send it.`
- `I need to finish the launch email, like subject, body, and send.`
- `Work on launch email: write subject, draft body, send.`
- `The thing is finish launch email. Steps are subject, body, send.`

Expected selected meanings:

- finish/send launch email

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- write subject line as separate task
- draft body as separate task
- send email as separate task

Product decision:

- confirm whether substeps should always collapse when user clearly names the parent task

#### Case separate_not_substeps

Transcripts:

- `Write launch email, call Sam, and pay rent.`
- `Uh, launch email, call Sam, pay rent.`
- `I need to write the launch email. Also call Sam. Also pay rent.`
- `Three things: write launch email, call Sam, pay rent.`
- `Write the launch email, call Sam, pay rent, that's all.`

Expected selected meanings:

- write launch email
- call Sam
- pay rent

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- send launch email, unless explicitly said
- schedule with Sam

### 10. Future / Not Today

Goal: only extract today's commitments. This needs product confirmation.

#### Case future_tomorrow_exclude

Transcripts:

- `Tomorrow I need to call Sam, but today I need to pay rent.`
- `Uh tomorrow call Sam. Today pay rent.`
- `Not today, but tomorrow I should call Sam. Today just pay rent.`
- `Pay rent today. Call Sam tomorrow.`
- `Today's thing is pay rent. Tomorrow is call Sam.`

Expected selected meanings:

- pay rent

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- call Sam

Product decision:

- future tasks probably excluded unless the user says "plan/schedule that today"

#### Case future_prepare_today

Transcripts:

- `For tomorrow's meeting, prepare the notes today.`
- `I need to prep notes today for tomorrow's meeting.`
- `Prepare notes for the meeting tomorrow.`
- `Uh, today, prep tomorrow's meeting notes.`
- `Put prepare meeting notes for tomorrow.`

Expected selected meanings:

- prepare meeting notes

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- attend meeting
- schedule meeting

### 11. Negative Commitments

Goal: decide whether "don't do X" can be a focus commitment. Recommendation: yes if explicitly stated.

#### Case negative_no_twitter

Transcripts:

- `Don't scroll Twitter.`
- `Uh, do not scroll Twitter today.`
- `My thing is don't open Twitter.`
- `Stay off Twitter.`
- `Avoid Twitter until tonight.`

Expected selected meanings:

- don't scroll/open Twitter

Expected extras: none

Expected overflow: false

Forbidden/invented meanings:

- use social media less generally
- delete Twitter
- focus on work

Product decision:

- confirm whether negative commitments count as valid tasks

## Judge Output Format

When we run evals, each run should store:

- case ID
- transcript variant
- run number
- selected tasks
- extras
- overflow flag
- pass/fail
- failure reasons
- hallucinated meanings, if any
- notes

Potential failure reason enum:

- `invented_selected`
- `invented_extra`
- `missing_task`
- `wrong_overflow`
- `ignored_correction`
- `duplicate_not_collapsed`
- `over_specific_rewrite`
- `no_task_false_positive`
- `bad_grouping`

## Next Step

Convert these examples into a machine-readable fixture file, then build a device eval runner that can execute Foundation Models extraction `N` times per case and produce a pass/fail report.
This is a file where i will say describe desired behavior and problems with current behavior. 

we will go from transcript

Current beh:


example 1:

Transcript:

Go to a store, go to the park, and eat food.

3 things:
 
 - go to store
- go to park
- eat food

extras:
- None


create examples where we have multiple things to cut (or just 1 thing to cut)


examples where you change the things 

[ex: go to park, wait nevermind, go to store] should extract to just go to store]. 

our task is to generate examples transcripts to test extraction. 

our test suite shuold include a spread of test cases designed to test if the app actually extracts meaning well. 