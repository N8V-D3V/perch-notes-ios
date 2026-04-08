# Contract: Generate Audio From Note Sequence

Version: 0.3.0  
Status: Draft

---

## 1. Purpose
Define how the system transforms a deterministic note sequence into playable, loopable audio, including note events that contain one or more simultaneous pitches.

---

## 2. Actors
- User - requests playable audio from generated note data
- System - validates the note sequence and produces playable audio or an explicit failure result

---

## 3. Inputs
- note_sequence: NoteSequence - note data to convert into audio
- audio_generation_request: AudioGenerationRequest - request to generate playable audio

---

## 4. Outputs
- generated_audio: GeneratedAudio | null - playable audio derived from the note sequence when generation succeeds
- audio_generation_result: AudioGenerationResult - explicit generation outcome

---

## 5. Data Models

### NoteEvent
- order_index: integer - time-step position within the note sequence
- pitch_ranks: [integer] - one or more simultaneous pitch values for the time step, sorted from highest to lowest, containing unique values only
- start_offset_units: integer - start position within the sequence timeline, where each value matches the event `order_index`
- duration_units: integer - event duration, fixed to `1` for every event in v0.1

### NoteSequence
- source_image_id: string - identifier of the image that originated the sequence
- line_count: integer - number of pitch layers represented in the sequence, from `1` to `7`
- note_count: integer - number of note events in the sequence, equal to the number of time steps
- events: [NoteEvent] - ordered note events, where each event may be monophonic or polyphonic

### AudioGenerationRequest
- request_id: string - identifier for the audio generation attempt

### GeneratedAudio
- audio_id: string - stable identifier for the generated audio artifact
- source_image_id: string - identifier of the originating image
- note_count: integer - number of time steps represented in the audio
- loopable: boolean - whether the audio is valid for repeated playback without additional transformation
- audio_reference: string - reference to the generated audio content

### AudioGenerationResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit generation outcome or failure reason

---

## 6. Success Behavior

1. The system must accept one `NoteSequence` per audio generation request.
2. The system must proceed only when a non-empty `NoteSequence` exists from successful upstream note generation.
3. The system must validate that `line_count` is from `1` to `7`.
4. The system must validate that `note_count` equals the number of events and therefore equals the number of time steps.
5. The system must validate that `order_index` values are sequential starting at `0`.
6. The system must validate that `start_offset_units` equals `order_index` for every event.
7. The system must validate that `duration_units` equals `1` for every event.
8. The system must validate that each `NoteEvent` contains a non-empty `pitch_ranks` list.
9. The system must validate that each `pitch_ranks` list contains unique pitch values only and is sorted from highest to lowest.
10. The system must render each `NoteEvent` as one time step in increasing `order_index`.
11. All pitches within a single `NoteEvent` must be rendered simultaneously.
12. Rendering must preserve the `start_offset_units` and `duration_units` defined by the note sequence.
13. The system must support monophonic, polyphonic, and mixed note sequences.
14. The system must produce one playable audio artifact marked as loopable.
15. The same `NoteSequence` submitted under the same contract rules must produce identical `GeneratedAudio`.
16. No randomness is allowed in rendering.

---

## 7. Failure Modes

- Condition: The note sequence is missing, empty, or structurally invalid
  - System must: Return `INVALID_NOTE_SEQUENCE`

- Condition: A `NoteEvent` contains an empty `pitch_ranks` list
  - System must: Return `INVALID_NOTE_SEQUENCE`

- Condition: A `NoteEvent` contains duplicate pitch values or pitch values not sorted from highest to lowest
  - System must: Return `INVALID_NOTE_SEQUENCE`

- Condition: `note_count` does not equal the number of events, or `line_count` is outside `1` to `7`
  - System must: Return `INVALID_NOTE_SEQUENCE`

- Condition: `order_index` values are not sequential starting at `0`
  - System must: Return `INVALID_EVENT_ORDER`

- Condition: `start_offset_units` does not equal `order_index`, or `duration_units` does not equal `1`
  - System must: Return `INVALID_TIMING`

- Condition: The system cannot produce a playable audio artifact from an otherwise valid note sequence
  - System must: Return `AUDIO_GENERATION_FAILED`

---

## 8. Edge Cases

- A note sequence containing exactly one event with one pitch must still produce playable, loopable audio
- A note sequence containing exactly one event with multiple pitches must produce one polyphonic time step
- A note sequence may mix monophonic and polyphonic events and must still produce playable, loopable audio
- A `NoteEvent` may contain from `1` to `line_count` pitches
- A `NoteEvent` must never contain more than `7` pitches
- A note sequence with `note_count` equal to the number of time steps but not the number of original birds must still be treated as valid

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define note-sequence-to-audio behavior only
- Must not analyze images
- Must not save, replay, browse, or share output
- Must not include synthesis implementation details
- Must not include platform-specific details
- Must produce loopable output for every successful generation
- Must remain deterministic for the same note sequence under the same contract rules

---

## 10. Observability

### Events
- `AudioGenerationRequested`
- `AudioGenerationCompleted`
- `AudioGenerationFailed`

### Metrics
- Count of audio generation requests
- Count of successful audio generations
- Count of failed audio generations by failure reason
- Distribution of generated note counts
- Distribution of pitches per event
- Distribution of line counts

### Logs
- Audio generation request identifier
- Source image identifier
- Line count
- Note count
- Failure reason when audio generation does not succeed

---

## 11. Acceptance Criteria

- [ ] A valid non-empty `NoteSequence` produces one playable `GeneratedAudio` artifact
- [ ] A `NoteEvent` with multiple `pitch_ranks` is accepted and rendered as simultaneous output for one time step
- [ ] A `NoteEvent` with exactly one pitch is accepted and rendered as monophonic output for one time step
- [ ] A note sequence containing both monophonic and polyphonic events is accepted and rendered correctly
- [ ] `note_count` is validated as the number of time steps, not the number of birds
- [ ] `pitch_ranks` must be non-empty, unique, and sorted from highest to lowest
- [ ] `order_index` values must be sequential starting at `0`
- [ ] `start_offset_units` must equal `order_index` for every event
- [ ] `duration_units` must equal `1` for every event
- [ ] Successful output is explicitly marked as loopable
- [ ] The same valid note sequence generates identical audio output under the same contract rules
- [ ] Invalid note-sequence structure fails explicitly with `INVALID_NOTE_SEQUENCE`
- [ ] Invalid event order fails explicitly with `INVALID_EVENT_ORDER`
- [ ] Invalid timing fails explicitly with `INVALID_TIMING`

---

## 12. Open Questions

- What audible mapping should correspond to each `pitch_rank` value in v0.1?
- What overall tonal character should the generated audio use in v0.1?
- Should successful audio generation include any additional metadata such as total duration?
