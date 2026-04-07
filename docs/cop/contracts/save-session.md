# Contract: Save Session

Version: 0.3.0  
Status: Draft

---

## 1. Purpose
Define how the system saves a completed session so it can later be browsed and replayed.

---

## 2. Actors
- User - requests that a completed session be saved
- System - validates session completeness and creates one saved session record or an explicit failure result

---

## 3. Inputs
- save_session_request: SaveSessionRequest - request to save one completed session

---

## 4. Outputs
- saved_session_record: SavedSessionRecord | null - persisted session record when save succeeds
- save_session_result: SaveSessionResult - explicit save outcome

---

## 5. Data Models

### SourceImage
- image_id: string - stable identifier for the acquired image
- image_reference: string - reference to the acquired image content

### NoteEvent
- order_index: integer - left-to-right event position within the sequence
- pitch_rank: integer - relative pitch value assigned from vertical bird position
- start_offset_units: integer - uniform start position within the sequence timeline
- duration_units: integer - uniform duration assigned to the event

### NoteSequence
- source_image_id: string - identifier of the image that originated the sequence
- note_count: integer - number of note events in the sequence
- events: [NoteEvent] - ordered note events in the sequence

### GeneratedAudio
- audio_id: string - stable identifier for the generated audio artifact
- source_image_id: string - identifier of the originating image
- note_count: integer - number of notes represented in the audio
- loopable: boolean - whether the audio is valid for repeated playback
- audio_reference: string - reference to the generated audio content

### CompletedSession
- source_image: SourceImage - image used for the session
- note_sequence: NoteSequence - full note sequence generated from the source image
- generated_audio: GeneratedAudio - playable audio generated from the note sequence

### SaveSessionRequest
- completed_session: CompletedSession - completed session requested for saving

### SavedSessionRecord
- session_id: string - stable identifier for the saved session
- completed_session: CompletedSession - completed session stored in the saved session
- saved_at: string - timestamp of the successful save

### SaveSessionResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit save outcome or failure reason

---

## 6. Success Behavior

1. The system must accept a save request only when one completed session exists.
2. The system must validate that the completed session contains source image, note sequence, and generated audio artifacts.
3. The system must validate that the note sequence references the source image, that the generated audio references the same originating image, and that the generated audio is loopable.
4. Each explicit user save request must create one new `SavedSessionRecord`, even when the submitted completed session matches a previously saved session.
5. A successful save must return a new stable `session_id` and a `saved_at` timestamp.
6. A successfully saved session must become available to browse and replay flows.

---

## 7. Failure Modes

- Condition: The submitted completed session is missing one or more required artifacts
  - System must: Return `INCOMPLETE_COMPLETED_SESSION`

- Condition: The submitted artifacts do not reference the same originating session data
  - System must: Return `SESSION_ARTIFACT_MISMATCH`

- Condition: The submitted completed session does not include loopable generated audio
  - System must: Return `INVALID_COMPLETED_SESSION`

- Condition: The system cannot persist the session record
  - System must: Return `SESSION_SAVE_FAILED`

- Condition: The save request cannot be processed
  - System must: Return `SESSION_SAVE_UNAVAILABLE`

---

## 8. Edge Cases

- Repeating a save request for the same completed session must create a distinct saved session with a distinct `session_id`
- A save request with valid image and note data but missing audio must fail explicitly
- A save request with audio derived from a different originating image must fail explicitly
- A partially created saved session record must not be returned as a successful result

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define saving completed sessions only
- Must not generate notes or audio
- Must not define browsing, replay, or sharing behavior beyond making a successful save available to those flows

---

## 10. Observability

### Events
- `SessionSaveRequested`
- `SessionSaveCompleted`
- `SessionSaveFailed`

### Metrics
- Count of save requests
- Count of successful saves
- Count of failed saves by failure reason

### Logs
- Presence of required session artifacts
- Validation outcome for artifact consistency
- Saved session identifier on success
- Failure reason when save does not succeed

---

## 11. Acceptance Criteria

- [ ] A save request succeeds only when source image, note sequence, and generated audio are all present
- [ ] A save request succeeds only when the submitted generated audio is loopable
- [ ] A save request fails explicitly when submitted artifacts do not belong to the same originating session data
- [ ] A successful save returns one complete `SavedSessionRecord` with a stable `session_id`
- [ ] Repeating an explicit save of the same completed session creates a new saved session with a new `session_id`
- [ ] A successful save makes the session available for later browse and replay flows
- [ ] A partially persisted session is never returned as a successful result

---

## 12. Open Questions

- Should a saved session include any additional user-visible metadata beyond the required artifacts and save timestamp?
- Are there retention limits or save quotas for v0.1?
