# Contract: Replay Saved Session

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system reopens a previously saved session and returns it in a replay-ready state.

---

## 2. Actors
- User - requests that a saved session be reopened and replayed
- System - validates the saved session and returns a replay-ready session or an explicit failure result

---

## 3. Inputs
- replay_saved_session_request: ReplaySavedSessionRequest - request to reopen one saved session for replay

---

## 4. Outputs
- replay_ready_session: ReplayReadySession | null - reopened replay-ready session when replay succeeds
- replay_saved_session_result: ReplaySavedSessionResult - explicit replay outcome

---

## 5. Data Models

### ReplaySavedSessionRequest
- session_id: string - identifier of the saved session to reopen

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
- source_image: SourceImage - saved source image artifact
- note_sequence: NoteSequence - full saved note sequence artifact
- generated_audio: GeneratedAudio - saved audio artifact

### ReplayReadySession
- session_id: string - identifier of the reopened saved session
- completed_session: CompletedSession - completed session reopened from the saved session
- replay_status: string - `READY`

### ReplaySavedSessionResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit replay outcome or failure reason

---

## 6. Success Behavior

1. The system must accept one saved `session_id` per replay request.
2. The system must validate that the saved session exists and contains one complete completed session with source image, note sequence, and generated audio required for replay.
3. When validation succeeds, the system must return one `ReplayReadySession` for that saved session.
4. The reopened saved session must be returned with `replay_status` set to `READY`.
5. Reopening a saved session for replay must not begin playback automatically.
6. The system must make the saved generated audio available for manual replay without requiring note regeneration or audio regeneration.
7. A replay request made again for the same saved session must reopen that same saved session rather than creating a new one.

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
- A reopened saved session must remain in `READY` state until a separate replay action occurs
- Replay must remain possible even when the completed session artifacts are not being modified

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define reopening and replaying a saved session only
- Must not regenerate notes or audio
- Must not save, browse, edit, or share saved sessions
- Must return replay-ready state without automatic playback

---

## 10. Observability

### Events
- `SavedSessionReplayRequested`
- `SavedSessionReplayReady`
- `SavedSessionReplayFailed`

### Metrics
- Count of replay requests
- Count of successful replay-ready session loads
- Count of replay failures by failure reason

### Logs
- Requested saved session identifier
- Replay validation outcome
- Replay-ready status returned
- Failure reason when replay does not succeed

---

## 11. Acceptance Criteria

- [ ] A replay request with a valid saved `session_id` returns one `ReplayReadySession`
- [ ] Successful replay does not require note regeneration or audio regeneration
- [ ] Successful replay returns `replay_status` equal to `READY`
- [ ] Successful replay does not begin playback automatically
- [ ] Missing saved sessions fail explicitly
- [ ] Incomplete saved sessions fail explicitly
- [ ] Replay failures caused by unavailable saved audio fail explicitly
- [ ] Repeating replay for the same saved session continues to reference the same `session_id`

---

## 12. Open Questions

- Should replay expose the saved source image and note data to the user alongside audio playback in v0.1?
- Should replay preserve the last known playback position, or always restart from the beginning?
