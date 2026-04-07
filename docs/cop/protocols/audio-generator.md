# Protocol: AudioGenerator

Version: 0.3.0
Status: Draft

Derived From:
- `docs/cop/contracts/generate-audio-from-note-sequence.md`

---

## 1. Name
AudioGenerator

---

## 2. Purpose
Provide the capability to transform one deterministic `NoteSequence` into one playable, loopable `GeneratedAudio` artifact.

---

## 3. Inputs
- `note_sequence: NoteSequence` - note data to convert into playable audio
- `audio_generation_request: AudioGenerationRequest` - request to generate audio

---

## 4. Outputs
- `generated_audio: GeneratedAudio | null` - playable audio derived from the note sequence when generation succeeds
- `audio_generation_result: AudioGenerationResult` - explicit generation outcome

---

## 5. Behavior Requirements
1. Must accept exactly one `NoteSequence` per audio generation request.
2. Must proceed only when the provided note sequence is non-empty and structurally valid.
3. Must validate that `note_count` matches the number of `events`.
4. Must validate that `order_index` values are sequential within the event order.
5. Must validate that `start_offset_units` equals `order_index` for every note event.
6. Must validate that `duration_units` equals `1` for every note event.
7. Must render all note events into one playable audio artifact that preserves the input event order and uniform timing.
8. Must set `generated_audio.source_image_id` to the originating `note_sequence.source_image_id`.
9. Must set `generated_audio.note_count` to the input `note_sequence.note_count`.
10. Must set `generated_audio.loopable` to `true` for every successful generation.
11. The same `NoteSequence` under the same contract rules must produce the same `GeneratedAudio`.

---

## 6. Failure Behavior
- Failures must be represented by `audio_generation_result.status = FAILED`.
- When generation does not succeed, `generated_audio` must be `null`.
- Failure reason must be one of:
  - `MISSING_NOTE_SEQUENCE`
  - `EMPTY_NOTE_SEQUENCE`
  - `INVALID_NOTE_TIMING`
  - `INVALID_NOTE_SEQUENCE`
  - `AUDIO_GENERATION_FAILED`

---

## 7. Constraints
- Must define note-sequence-to-audio capability only.
- Must not analyze images.
- Must not save, replay, browse, or share output.
- Must produce loopable output for every successful generation.
- Must be deterministic for the same `NoteSequence` under the same contract rules.
- Must remain reusable as a note-to-audio capability without embedding orchestration logic.
