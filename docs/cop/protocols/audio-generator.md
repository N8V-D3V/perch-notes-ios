# Protocol: AudioGenerator

Version: 0.3.0
Status: Draft

Derived From:
- `docs/cop/contracts/generate-audio-from-note-sequence.md`
- `docs/cop/contracts/generate-notes-from-image.md` for upstream `NoteSequence` shape

---

## 1. Name
AudioGenerator

---

## 2. Purpose
Provide the capability to transform one deterministic `NoteSequence` into one playable, loopable `GeneratedAudio` artifact, including note events that may contain one or more simultaneous pitches.

---

## 3. Inputs
- `note_sequence: NoteSequence` - note data to convert into playable audio
- `audio_generation_request: AudioGenerationRequest` - request to generate audio

---

## 4. Outputs
- `generated_audio: GeneratedAudio | null` - playable audio derived from the note sequence when generation succeeds
- `audio_generation_result: AudioGenerationResult` - explicit generation outcome

---

## 5. Data Model Expectations
- `NoteEvent`
  - `order_index: integer` - event position within the note sequence
  - `pitch_ranks: [integer]` - one or more simultaneous pitch values for the time step, sorted from highest to lowest
  - `start_offset_units: integer` - uniform start position within the sequence timeline and equal to `order_index`
  - `duration_units: integer` - uniform event duration and fixed to `1` for every event in v0.1
- `NoteSequence`
  - `source_image_id: string` - identifier of the image that originated the sequence
  - `line_count: integer` - number of selected pitch layers represented in the sequence, from `1` to `7`
  - `note_count: integer` - number of note events or time steps
  - `events: [NoteEvent]` - ordered note events that may be monophonic or polyphonic

---

## 6. Behavior Requirements
1. Must accept exactly one `NoteSequence` per audio generation request.
2. Must proceed only when the provided note sequence is non-empty and structurally valid.
3. Must validate that `note_count` matches the number of `events`.
4. Must validate that `line_count` is from `1` to `7`.
5. Must validate that `order_index` values are sequential within the event order.
6. Must validate that `start_offset_units` equals `order_index` for every note event.
7. Must validate that `duration_units` equals `1` for every note event.
8. Must validate that each `NoteEvent` contains one or more `pitch_ranks`, that `pitch_ranks` are unique within the event, and that they are sorted from highest to lowest.
9. Must validate that the number of simultaneous pitches in an event does not exceed `line_count` and does not exceed `7`.
10. Must render each `NoteEvent` as one time step in the generated audio.
11. When a `NoteEvent` contains multiple `pitch_ranks`, must render those pitches as simultaneous audio within the same time step.
12. Must render all note events into one playable audio artifact that preserves the input event order, simultaneous pitch membership, and uniform timing.
13. Must set `generated_audio.source_image_id` to the originating `note_sequence.source_image_id`.
14. Must set `generated_audio.note_count` to the input `note_sequence.note_count`.
15. Must set `generated_audio.loopable` to `true` for every successful generation.
16. The same `NoteSequence` under the same contract rules must produce the same `GeneratedAudio`.

---

## 7. Failure Behavior
- Failures must be represented by `audio_generation_result.status = FAILED`.
- When generation does not succeed, `generated_audio` must be `null`.
- Polyphonic input validation failures, including invalid `pitch_ranks`, invalid `line_count`, or unsupported simultaneous-pitch structure, must be represented as `INVALID_NOTE_SEQUENCE` unless the failure is specifically an invalid timing failure.
- Failure reason must be one of:
  - `MISSING_NOTE_SEQUENCE`
  - `EMPTY_NOTE_SEQUENCE`
  - `INVALID_NOTE_TIMING`
  - `INVALID_NOTE_SEQUENCE`
  - `AUDIO_GENERATION_FAILED`

---

## 8. Constraints
- Must define note-sequence-to-audio capability only.
- Must not analyze images.
- Must not save, replay, browse, or share output.
- Must accept note events that contain one or more simultaneous `pitch_ranks`.
- Must produce loopable output for every successful generation.
- Must be deterministic for the same `NoteSequence` under the same contract rules.
- Must remain reusable as a note-to-audio capability without embedding orchestration logic.
