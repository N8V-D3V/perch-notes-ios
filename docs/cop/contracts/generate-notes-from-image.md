# Contract: Generate Notes From Image

Version: 0.3.0  
Status: Draft

---

## 1. Purpose
Define how the system transforms one source image of birds on powerlines into a deterministic note sequence for a completed session, allowing up to seven simultaneous pitch layers per time step.

---

## 2. Actors
- User - submits a previously acquired source image for note generation
- System - analyzes the image, selects valid powerlines, groups birds into time-ordered events, and produces note data or an explicit failure result

---

## 3. Inputs
- source_image: SourceImage - acquired image to interpret as music
- note_generation_request: NoteGenerationRequest - request to generate a note sequence from the image

---

## 4. Outputs
- note_sequence: NoteSequence | null - deterministic note data derived from the image when generation succeeds
- note_generation_result: NoteGenerationResult - explicit generation outcome

---

## 5. Data Models

### SourceImage
- image_id: string - stable identifier for the acquired image
- image_reference: string - reference to the acquired image content

### NoteGenerationRequest
- request_id: string - identifier for the generation attempt

### NoteEvent
- order_index: integer - left-to-right time-step position within the sequence
- pitch_ranks: [integer] - one or more simultaneous pitch values for the time step, sorted from highest to lowest
- start_offset_units: integer - uniform start position within the sequence timeline, where each value matches the event `order_index`
- duration_units: integer - uniform duration assigned to the event, fixed to `1` for every event in v0.1

### NoteSequence
- source_image_id: string - identifier of the image used to produce the sequence
- line_count: integer - number of selected powerlines represented in the sequence, from `1` to `7`
- note_count: integer - number of note events in the sequence, equal to the number of time steps
- events: [NoteEvent] - ordered note events

### NoteGenerationResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit generation outcome or failure reason

---

## 6. Success Behavior

1. The system must accept exactly one `SourceImage` per note generation request.
2. The system must evaluate whether the image contains one or more valid powerlines with birds that can be interpreted as note data.
3. The system must detect and use from `1` to `7` valid powerlines.
4. If more than `7` valid powerlines are detected, the system must deterministically select the top `7` most prominent valid powerlines.
5. Powerline prominence must be determined deterministically using, in order: higher bird count on the line, greater horizontal span, and stronger continuity or alignment quality.
6. After powerline selection, the system must sort the selected powerlines from top to bottom.
7. Each selected powerline must map to one unique `pitch_rank`, where a higher powerline receives a higher `pitch_rank`.
8. The system must consider only birds assigned to the selected powerlines when constructing note events.
9. The system must sort considered birds from left to right by horizontal position.
10. The system must group birds into time steps using one deterministic horizontal threshold for the generation request.
11. Birds whose horizontal positions fall within the same deterministic horizontal threshold must be placed into the same `NoteEvent`.
12. Each `NoteEvent` must represent exactly one time step and may contain from `1` to `line_count` simultaneous pitches.
13. `pitch_ranks` within each `NoteEvent` must contain the unique pitch ranks present in that time step and must be sorted from highest to lowest.
14. If more than one bird from the same selected powerline falls within the same time step, the resulting `NoteEvent` must contain that powerline's `pitch_rank` only once.
15. The system must use uniform timing for v0.1, with `start_offset_units` equal to `order_index` and `duration_units` equal to `1` for every generated note event.
16. `note_count` must equal the number of generated `NoteEvent` time steps, not the number of detected birds.
17. The same `SourceImage` submitted under the same contract rules must produce the same `NoteSequence`.

---

## 7. Failure Modes

- Condition: The image does not contain a valid powerline that can be used for note generation
  - System must: Return `NO_VALID_POWERLINE`

- Condition: No birds are detected on any selected powerlines
  - System must: Return `NO_BIRDS_DETECTED`

- Condition: The source image cannot be analyzed for note generation
  - System must: Return `IMAGE_ANALYSIS_FAILED`

- Condition: Birds cannot be grouped into a deterministic left-to-right event order using the required horizontal threshold
  - System must: Return `AMBIGUOUS_NOTE_ORDER`

- Condition: Selected powerlines cannot be ordered top to bottom deterministically for pitch assignment
  - System must: Return `AMBIGUOUS_NOTE_ORDER`

---

## 8. Edge Cases

- A source image with exactly one valid powerline must still produce a valid monophonic note sequence
- Multiple birds at the same horizontal position across different selected powerlines must be grouped into the same `NoteEvent`
- Events may contain from `1` to `N` pitches, where `N` is the number of selected powerlines and `N` must not exceed `7`
- Birds detected on valid powerlines outside the selected top `7` most prominent lines must not be included in the resulting note sequence
- Birds detected outside the selected powerlines must not be included in the resulting note sequence
- Multiple birds from the same selected powerline within the same time step must contribute only one pitch to that `NoteEvent`

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define transformation from source image to note data only
- Must not generate audio
- Must not save, replay, browse, or share output
- Must select no more than `7` pitch layers from detected powerlines
- Must assign one unique `pitch_rank` to each selected powerline
- Must produce at most one pitch per selected powerline within a single `NoteEvent`
- Maximum pitches per event must not exceed the number of selected powerlines and must never exceed `7`
- Must remain deterministic for the same source image under the same contract rules

---

## 10. Observability

### Events
- `NoteGenerationRequested`
- `NoteGenerationCompleted`
- `NoteGenerationFailed`

### Metrics
- Count of note generation requests
- Count of successful note sequences generated
- Count of failed note generation attempts by failure reason
- Distribution of selected powerline counts
- Distribution of generated note counts
- Distribution of pitches per event

### Logs
- Source image identifier
- Generation request identifier
- Selected powerline count on success
- Note event count on success
- Failure reason when note generation does not succeed

---

## 11. Acceptance Criteria

- [ ] A valid source image produces exactly one deterministic `NoteSequence`
- [ ] The system uses from `1` to `7` valid powerlines
- [ ] If more than `7` valid powerlines are detected, only the top `7` most prominent valid powerlines are used
- [ ] Powerline prominence is determined deterministically by bird count, horizontal span, and continuity or alignment quality
- [ ] Selected powerlines are sorted from top to bottom before assigning unique pitch ranks
- [ ] Higher selected powerlines receive higher `pitch_rank` values
- [ ] Birds are grouped into note events by left-to-right order and a deterministic horizontal threshold
- [ ] Each `NoteEvent` contains one or more `pitch_ranks` sorted from highest to lowest
- [ ] `start_offset_units` is equal to `order_index` for every note event
- [ ] `duration_units` is equal to `1` for every note event
- [ ] `note_count` equals the number of generated time steps, not the number of detected birds
- [ ] A single-line image still produces a valid monophonic sequence with one pitch per event when only one selected powerline contributes to each time step
- [ ] An image with no valid powerline fails explicitly
- [ ] An image with no birds on selected powerlines fails explicitly
- [ ] Non-deterministic grouping or ordering fails explicitly with `AMBIGUOUS_NOTE_ORDER`

---

## 12. Open Questions

- What exact contract-level rule should define the deterministic horizontal threshold for grouping birds into the same time step?
- What exact contract-level rule should define continuity or alignment quality when ranking powerline prominence?
