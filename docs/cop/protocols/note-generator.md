# Protocol: NoteGenerator

Version: 0.3.0
Status: Draft

Derived From:
- `docs/cop/contracts/generate-notes-from-image.md`

---

## 1. Name
NoteGenerator

---

## 2. Purpose
Provide the capability to transform one `SourceImage` into one deterministic `NoteSequence` when the image contains a usable bird-on-powerline pattern.

---

## 3. Inputs
- `source_image: SourceImage` - acquired image to interpret as note data
- `note_generation_request: NoteGenerationRequest` - request to generate a note sequence from the image

---

## 4. Outputs
- `note_sequence: NoteSequence | null` - deterministic note data derived from the image when generation succeeds
- `note_generation_result: NoteGenerationResult` - explicit generation outcome

---

## 5. Behavior Requirements
1. Must accept exactly one `SourceImage` per note generation request.
2. Must evaluate whether the image contains at least one valid powerline with birds that can be interpreted as note events.
3. When multiple valid powerlines are visible, must select one single most prominent valid powerline.
4. Must derive exactly one `NoteEvent` for each detected bird included on the selected powerline and must exclude birds outside the selected powerline.
5. Must order note events from left to right based on horizontal bird position.
6. Must assign `order_index` values that preserve the deterministic event order and align with the returned event sequence.
7. Must assign `pitch_rank` values from vertical bird position so that a bird higher in the image receives a higher `pitch_rank`.
8. Must set `start_offset_units` equal to `order_index` for every generated note event.
9. Must set `duration_units` equal to `1` for every generated note event.
10. Must set `note_sequence.source_image_id` to the originating `SourceImage.image_id`.
11. Must set `note_sequence.note_count` to the number of generated note events.
12. The same `SourceImage` under the same contract rules must produce the same `NoteSequence`.

---

## 6. Failure Behavior
- Failures must be represented by `note_generation_result.status = FAILED`.
- When generation does not succeed, `note_sequence` must be `null`.
- Failure reason must be one of:
  - `NO_VALID_POWERLINE`
  - `NO_BIRDS_DETECTED`
  - `AMBIGUOUS_POWERLINE_SELECTION`
  - `IMAGE_ANALYSIS_FAILED`
  - `AMBIGUOUS_NOTE_ORDER`

---

## 7. Constraints
- Must define source-image-to-note-sequence capability only.
- Must not generate audio.
- Must not save, replay, browse, or share output.
- Must be deterministic for the same `SourceImage` under the same contract rules.
- Must remain reusable as an image-to-note capability without embedding orchestration logic.
