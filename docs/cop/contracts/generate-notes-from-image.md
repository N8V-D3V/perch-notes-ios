# Contract: Generate Notes From Image

Version: 0.3.0  
Status: Draft

---

## 1. Purpose
Define how the system transforms one source image of birds on a powerline into a deterministic note sequence for a completed session.

---

## 2. Actors
- User - submits a previously acquired source image for note generation
- System - analyzes the image, determines whether it contains a usable bird-on-powerline pattern, and produces note data or an explicit failure result

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
- order_index: integer - left-to-right event position within the sequence
- pitch_rank: integer - relative pitch value assigned from vertical bird position, where a bird higher on the image receives a higher `pitch_rank`
- start_offset_units: integer - uniform start position within the sequence timeline, where each value matches the event `order_index`
- duration_units: integer - uniform duration assigned to the event, fixed to `1` for every note in v0.1

### NoteSequence
- source_image_id: string - identifier of the image used to produce the sequence
- note_count: integer - number of note events in the sequence
- events: [NoteEvent] - ordered note events

### NoteGenerationResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit generation outcome or failure reason

---

## 6. Success Behavior

1. The system must accept exactly one `SourceImage` per note generation request.
2. The system must evaluate whether the image contains at least one valid powerline with birds that can be interpreted as note events.
3. If multiple valid powerlines are visible, the system must select the single most prominent valid powerline.
4. If a single most prominent valid powerline is selected, the system must derive one `NoteEvent` for each detected bird included on that powerline.
5. The system must order note events from left to right based on horizontal bird position.
6. The system must assign `pitch_rank` values from vertical bird position, where a bird higher on the image receives a higher `pitch_rank`.
7. The system must use uniform timing for v0.1, with `start_offset_units` equal to `order_index` and `duration_units` equal to `1` for every generated note event.
8. The same `SourceImage` submitted under the same contract rules must produce the same `NoteSequence`.

---

## 7. Failure Modes

- Condition: The image does not contain a valid powerline that can be used for note generation
  - System must: Return `NO_VALID_POWERLINE`

- Condition: The selected powerline does not contain any birds that can be included in the interpreted pattern
  - System must: Return `NO_BIRDS_DETECTED`

- Condition: Multiple valid powerlines are visible and the system cannot select a single most prominent valid powerline unambiguously
  - System must: Return `AMBIGUOUS_POWERLINE_SELECTION`

- Condition: The source image cannot be analyzed for note generation
  - System must: Return `IMAGE_ANALYSIS_FAILED`

- Condition: Two or more birds cannot be assigned a deterministic left-to-right order
  - System must: Return `AMBIGUOUS_NOTE_ORDER`

---

## 8. Edge Cases

- A source image with exactly one detectable bird must still produce a one-note sequence if all other requirements are met
- Birds detected outside the selected powerline must not be included in the resulting note sequence
- Two birds with the same horizontal position must still receive a deterministic order or produce `AMBIGUOUS_NOTE_ORDER`
- Two birds with the same vertical position may share the same `pitch_rank`

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define transformation from source image to note data only
- Must not generate audio
- Must not save, replay, browse, or share output
- Must be deterministic for the same source image under the same contract rules

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
- Distribution of generated note counts

### Logs
- Source image identifier
- Generation request identifier
- Note count on success
- Failure reason when note generation does not succeed

---

## 11. Acceptance Criteria

- [ ] A valid source image produces exactly one deterministic `NoteSequence`
- [ ] The number of generated note events matches the number of birds included in the interpreted pattern
- [ ] Note events are ordered from left to right by horizontal bird position
- [ ] `pitch_rank` is determined by vertical bird position, where a higher bird receives a higher `pitch_rank`
- [ ] `start_offset_units` is equal to `order_index` for every note event
- [ ] `duration_units` is equal to `1` for every note event
- [ ] An image with no valid powerline fails explicitly
- [ ] An image with no detectable birds fails explicitly
- [ ] Multiple powerlines without a single unambiguous most prominent valid powerline fail explicitly

---

## 12. Open Questions

- What criteria determine which powerline is the single most prominent valid powerline?
- What is the minimum image quality required for analysis to be considered valid?
