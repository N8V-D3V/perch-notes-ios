# Contract: Save Session

Version: 0.1.0  
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

### NoteSequence
- source_image_id: string - identifier of the image that originated the sequence
- note_count: integer - number of note events in the sequence

### GeneratedAudio
- audio_id: string - stable identifier for the generated audio artifact
- source_image_id: string - identifier of the originating image
- note_count: integer - number of notes represented in the audio
- audio_reference: string - reference to the generated audio content

### SaveSessionRequest
- source_image: SourceImage - image used for the completed session
- note_sequence: NoteSequence - note data produced from the image
- generated_audio: GeneratedAudio - audio produced from the note sequence

### SavedSessionRecord
- session_id: string - stable identifier for the saved session
- source_image: SourceImage - saved source image artifact
- note_sequence: NoteSequence - saved note sequence artifact
- generated_audio: GeneratedAudio - saved generated audio artifact
- saved_at: string - timestamp of the successful save

### SaveSessionResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit save outcome or failure reason

---

## 6. Success Behavior

1. The system must accept a save request only when source image, note sequence, and generated audio are all present.
2. The system must validate that the note sequence references the submitted source image and that the generated audio references the same originating image.
3. When validation succeeds, the system must create one complete `SavedSessionRecord` containing the submitted artifacts.
4. A successful save must return a stable `session_id`.
5. A successfully saved session must become available to browse and replay flows.

---

## 7. Failure Modes

- Condition: One or more required session artifacts are missing
  - System must: Return `INCOMPLETE_SESSION`

- Condition: The submitted artifacts do not reference the same originating session data
  - System must: Return `SESSION_ARTIFACT_MISMATCH`

- Condition: The system cannot persist the session record
  - System must: Return `SESSION_SAVE_FAILED`

- Condition: The save request cannot be processed
  - System must: Return `SESSION_SAVE_UNAVAILABLE`

---

## 8. Edge Cases

- Repeating a save request for the same submitted artifacts must produce an explicit success or failure result and must not be silently ignored
- A save request with valid image and note data but missing audio must fail explicitly
- A save request with audio derived from a different originating image must fail explicitly
- A partially created saved session record must not be returned as a successful result

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define saving completed session artifacts only
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
- [ ] A save request fails explicitly when submitted artifacts do not belong to the same originating session data
- [ ] A successful save returns one complete `SavedSessionRecord` with a stable `session_id`
- [ ] A successful save makes the session available for later browse and replay flows
- [ ] A partially persisted session is never returned as a successful result

---

## 12. Open Questions

- Should repeated saves of the same completed session create distinct saved sessions or resolve as a single saved record?
- Should a saved session include any additional user-visible metadata beyond the required artifacts and save timestamp?
- Are there retention limits or save quotas for v0.1?
