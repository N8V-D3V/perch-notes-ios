# Contract: Generate Notes From Image

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system transforms one source image of birds on a powerline into a deterministic note sequence.

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
- pitch_rank: integer - relative pitch value assigned from bird position
- start_offset_units: integer - relative start position within the sequence timeline
- duration_units: integer - relative duration assigned to the event

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
2. The system must evaluate whether the image contains one deterministically interpretable bird-on-powerline pattern.
3. If the image contains a usable pattern, the system must derive one `NoteEvent` for each detected bird included in that pattern.
4. The system must order note events from left to right based on bird position in the image.
5. The system must assign `pitch_rank` values deterministically from bird position relative to the interpreted powerline pattern.
6. The system must assign `start_offset_units` and `duration_units` deterministically for every generated note event.
7. The same `SourceImage` submitted under the same contract rules must produce the same `NoteSequence`.

---

## 7. Failure Modes

- Condition: The image does not contain a usable powerline pattern
  - System must: Return `NO_USABLE_POWERLINE_PATTERN`

- Condition: The image does not contain any birds that can be included in the interpreted pattern
  - System must: Return `NO_BIRDS_DETECTED`

- Condition: The image contains multiple plausible patterns and the system cannot deterministically choose one
  - System must: Return `AMBIGUOUS_IMAGE_PATTERN`

- Condition: The system cannot assign deterministic timing values to generated events
  - System must: Return `UNDEFINED_NOTE_TIMING`

- Condition: The source image cannot be analyzed for note generation
  - System must: Return `IMAGE_ANALYSIS_FAILED`

---

## 8. Edge Cases

- A source image with exactly one detectable bird must still produce a one-note sequence if all other requirements are met
- Birds detected outside the interpreted powerline pattern must not be included in the resulting note sequence
- Two birds with the same horizontal position must still receive a deterministic order or produce an explicit failure if deterministic ordering is not possible
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
- [ ] Note events are ordered from left to right
- [ ] Each note event includes deterministic pitch and timing values
- [ ] An image with no usable powerline pattern fails explicitly
- [ ] An image with no detectable birds fails explicitly
- [ ] An ambiguous image pattern fails explicitly rather than producing a non-deterministic sequence

---

## 12. Open Questions

- What exact rule should determine `pitch_rank` values in v0.1?
- What exact rule should determine `start_offset_units` and `duration_units` in v0.1?
- How should multiple powerlines be handled when more than one appears visually valid?
- What is the minimum image quality required for analysis to be considered valid?
