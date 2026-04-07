# Contract: Generate Audio From Note Sequence

Version: 0.3.0  
Status: Draft

---

## 1. Purpose
Define how the system transforms a deterministic note sequence into playable, loopable audio.

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
- order_index: integer - event position within the note sequence
- pitch_rank: integer - relative pitch value derived from vertical bird position
- start_offset_units: integer - uniform start position within the sequence timeline, where each value matches the event `order_index`
- duration_units: integer - uniform event duration, fixed to `1` for every note in v0.1

### NoteSequence
- source_image_id: string - identifier of the image that originated the sequence
- note_count: integer - number of note events
- events: [NoteEvent] - ordered note events

### AudioGenerationRequest
- request_id: string - identifier for the audio generation attempt

### GeneratedAudio
- audio_id: string - stable identifier for the generated audio artifact
- source_image_id: string - identifier of the originating image
- note_count: integer - number of notes represented in the audio
- loopable: boolean - whether the audio is valid for repeated playback without additional transformation
- audio_reference: string - reference to the generated audio content

### AudioGenerationResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit generation outcome or failure reason

---

## 6. Success Behavior

1. The system must accept one `NoteSequence` per audio generation request.
2. The system must proceed only when a non-empty `NoteSequence` exists from successful upstream note generation.
3. The system must validate that the note sequence contains at least one note event, that `note_count` matches the number of events, that `order_index` values are sequential, that `start_offset_units` equals `order_index`, and that `duration_units` equals `1` for every event.
4. The system must render all note events into one playable audio artifact that preserves the event order and uniform timing defined by the note sequence.
5. The system must produce audio marked as loopable.
6. The same `NoteSequence` submitted under the same contract rules must produce the same `GeneratedAudio`.

---

## 7. Failure Modes

- Condition: No note sequence is available for audio generation
  - System must: Return `MISSING_NOTE_SEQUENCE`

- Condition: The note sequence is empty
  - System must: Return `EMPTY_NOTE_SEQUENCE`

- Condition: The note sequence contains invalid timing values
  - System must: Return `INVALID_NOTE_TIMING`

- Condition: The note sequence contains values that cannot be converted into playable audio
  - System must: Return `INVALID_NOTE_SEQUENCE`

- Condition: The system cannot produce a playable audio artifact from an otherwise valid note sequence
  - System must: Return `AUDIO_GENERATION_FAILED`

---

## 8. Edge Cases

- A one-note sequence must still produce playable, loopable audio
- Multiple note events with the same `start_offset_units` must fail explicitly because v0.1 timing is uniform and sequential
- Gaps between note events must be preserved in the generated audio
- A note sequence with non-sequential `order_index` values must fail explicitly

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define note-sequence-to-audio behavior only
- Must not analyze images
- Must not save, replay, browse, or share output
- Must produce loopable output for every successful generation
- Must be deterministic for the same note sequence under the same contract rules

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

### Logs
- Audio generation request identifier
- Source image identifier
- Note count
- Failure reason when audio generation does not succeed

---

## 11. Acceptance Criteria

- [ ] A valid non-empty `NoteSequence` produces one playable `GeneratedAudio` artifact
- [ ] Generated audio preserves the event order and uniform timing defined by the note sequence
- [ ] Successful output is explicitly marked as loopable
- [ ] The same valid note sequence generates the same audio output under the same contract rules
- [ ] Audio generation fails explicitly when no note sequence is available
- [ ] An empty note sequence fails explicitly
- [ ] Invalid note timing fails explicitly

---

## 12. Open Questions

- What audible pitch mapping should correspond to each `pitch_rank` value in v0.1?
- What overall tonal character should the generated audio use in v0.1?
- Should successful audio generation include any additional metadata such as total duration?
