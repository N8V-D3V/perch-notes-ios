# Contract: Replay Saved Session

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system reopens a previously saved session and makes its saved audio replayable.

---

## 2. Actors
- User - requests that a saved session be reopened and replayed
- System - validates the saved session and returns a replay-ready session or an explicit failure result

---

## 3. Inputs
- replay_saved_session_request: ReplaySavedSessionRequest - request to reopen one saved session for replay

---

## 4. Outputs
- replay_session: ReplaySession | null - reopened session data when replay succeeds
- replay_saved_session_result: ReplaySavedSessionResult - explicit replay outcome

---

## 5. Data Models

### ReplaySavedSessionRequest
- session_id: string - identifier of the saved session to reopen

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

### ReplaySession
- session_id: string - identifier of the reopened saved session
- source_image: SourceImage - saved source image artifact
- note_sequence: NoteSequence - saved note sequence artifact
- generated_audio: GeneratedAudio - saved audio artifact
- replay_status: string - `READY` or `PLAYING`

### ReplaySavedSessionResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit replay outcome or failure reason

---

## 6. Success Behavior

1. The system must accept one saved `session_id` per replay request.
2. The system must validate that the saved session exists and contains the source image, note sequence, and generated audio required for replay.
3. When validation succeeds, the system must return one `ReplaySession` containing the saved artifacts for that session.
4. The system must make the saved generated audio replayable without requiring note regeneration or audio regeneration.
5. A replay request made again for the same saved session must reopen that same saved session rather than creating a new one.

---

## 7. Failure Modes

- Condition: The requested saved session does not exist
  - System must: Return `SAVED_SESSION_NOT_FOUND`

- Condition: The requested saved session is missing one or more required replay artifacts
  - System must: Return `REPLAY_SESSION_INCOMPLETE`

- Condition: The saved generated audio cannot be made replayable
  - System must: Return `REPLAY_AUDIO_UNAVAILABLE`

- Condition: The replay request cannot be processed
  - System must: Return `REPLAY_SESSION_FAILED`

---

## 8. Edge Cases

- Replaying the same saved session multiple times must continue to reference the same `session_id`
- A saved session with valid metadata but missing audio content must fail explicitly
- A saved session that can be opened but not transitioned to `PLAYING` state must not be reported as a successful replay start
- Replay must remain possible even when the source image and note sequence are not being modified

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define reopening and replaying a saved session only
- Must not regenerate notes or audio
- Must not save, browse, edit, or share saved sessions

---

## 10. Observability

### Events
- `SavedSessionReplayRequested`
- `SavedSessionReplayLoaded`
- `SavedSessionReplayStarted`
- `SavedSessionReplayFailed`

### Metrics
- Count of replay requests
- Count of successful replay loads
- Count of successful replay starts
- Count of replay failures by failure reason

### Logs
- Requested saved session identifier
- Replay validation outcome
- Replay status transition
- Failure reason when replay does not succeed

---

## 11. Acceptance Criteria

- [ ] A replay request with a valid saved `session_id` returns one `ReplaySession`
- [ ] Successful replay does not require note regeneration or audio regeneration
- [ ] Missing saved sessions fail explicitly
- [ ] Incomplete saved sessions fail explicitly
- [ ] Replay failures caused by unavailable saved audio fail explicitly
- [ ] Repeating replay for the same saved session continues to reference the same `session_id`

---

## 12. Open Questions

- Should reopening a saved session automatically start playback, or only make playback available?
- Should replay expose the saved source image and note data to the user alongside audio playback in v0.1?
- Should replay preserve the last known playback position, or always restart from the beginning?
