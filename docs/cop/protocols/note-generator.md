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
Provide the capability to transform one `SourceImage` into one deterministic `NoteSequence` built from one to seven selected powerlines, where each time step may contain one or more simultaneous pitches.

---

## 3. Inputs
- `source_image: SourceImage` - acquired image to interpret as note data
- `note_generation_request: NoteGenerationRequest` - request to generate a note sequence from the image

---

## 4. Outputs
- `note_sequence: NoteSequence | null` - deterministic note data derived from the image when generation succeeds
- `note_generation_result: NoteGenerationResult` - explicit generation outcome

---

## 5. Data Model Expectations
- `NoteEvent`
  - `order_index: integer` - left-to-right time-step position within the sequence
  - `pitch_ranks: [integer]` - one or more simultaneous pitch values for the time step, sorted from highest to lowest
  - `start_offset_units: integer` - uniform start position within the sequence timeline and equal to `order_index`
  - `duration_units: integer` - uniform duration assigned to the event and fixed to `1` in v0.1
- `NoteSequence`
  - `source_image_id: string` - identifier of the image used to produce the sequence
  - `line_count: integer` - number of selected powerlines represented in the sequence, from `1` to `7`
  - `note_count: integer` - number of `NoteEvent` time steps in the sequence
  - `events: [NoteEvent]` - ordered time-step events that may be monophonic or polyphonic

---

## 6. Behavior Requirements
1. Must accept exactly one `SourceImage` per note generation request.
2. Must evaluate whether the image contains one or more valid powerlines with birds that can be interpreted as note data.
3. Must detect and use from `1` to `7` valid powerlines.
4. If more than `7` valid powerlines are detected, must deterministically select the top `7` most prominent valid powerlines.
5. Must determine powerline prominence deterministically using, in order: higher bird count on the line, greater horizontal span, and stronger continuity or alignment quality.
6. After powerline selection, must sort the selected powerlines from top to bottom.
7. Must assign one unique `pitch_rank` to each selected powerline, where a higher powerline receives a higher `pitch_rank`.
8. Must consider only birds assigned to the selected powerlines when constructing note events.
9. Must sort considered birds from left to right by horizontal position.
10. Must group birds into time steps using one deterministic horizontal threshold for the generation request.
11. Birds whose horizontal positions fall within the same deterministic horizontal threshold must be placed into the same `NoteEvent`.
12. Each `NoteEvent` must represent exactly one time step and may contain from `1` to `line_count` simultaneous pitches.
13. `pitch_ranks` within each `NoteEvent` must contain the unique pitch ranks present in that time step and must be sorted from highest to lowest.
14. If more than one bird from the same selected powerline falls within the same time step, the resulting `NoteEvent` must contain that powerline's `pitch_rank` only once.
15. Must assign `order_index` values that preserve the deterministic event order and align with the returned event sequence.
16. Must set `start_offset_units` equal to `order_index` for every generated note event.
17. Must set `duration_units` equal to `1` for every generated note event.
18. Must set `note_sequence.source_image_id` to the originating `SourceImage.image_id`.
19. Must set `note_sequence.line_count` to the number of selected powerlines represented in the sequence.
20. Must set `note_sequence.note_count` to the number of generated `NoteEvent` time steps, not the number of detected birds.
21. The same `SourceImage` under the same contract rules must produce the same `NoteSequence`.

---

## 7. Failure Behavior
- Failures must be represented by `note_generation_result.status = FAILED`.
- When generation does not succeed, `note_sequence` must be `null`.
- When birds cannot be grouped into a deterministic left-to-right event order or selected powerlines cannot be ordered top to bottom deterministically for pitch assignment, failure must be represented as `AMBIGUOUS_NOTE_ORDER`.
- Failure reason must be one of:
  - `NO_VALID_POWERLINE`
  - `NO_BIRDS_DETECTED`
  - `IMAGE_ANALYSIS_FAILED`
  - `AMBIGUOUS_NOTE_ORDER`

---

## 8. Constraints
- Must define source-image-to-note-sequence capability only.
- Must not generate audio.
- Must not save, replay, browse, or share output.
- Must select no more than `7` pitch layers from detected powerlines.
- Must assign one unique `pitch_rank` to each selected powerline.
- Must produce at most one pitch per selected powerline within a single `NoteEvent`.
- Maximum pitches per event must not exceed the number of selected powerlines and must never exceed `7`.
- Must be deterministic for the same `SourceImage` under the same contract rules.
- Must remain reusable as an image-to-note capability without embedding orchestration logic.
