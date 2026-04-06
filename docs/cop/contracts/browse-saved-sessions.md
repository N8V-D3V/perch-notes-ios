# Contract: Browse Saved Sessions

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system lists saved sessions and returns a selected saved session reference for replay.

---

## 2. Actors
- User - requests the saved session list and selects a saved session
- System - returns saved session summaries, validates selection, and returns a selected session reference or an explicit failure result

---

## 3. Inputs
- browse_saved_sessions_request: BrowseSavedSessionsRequest - request to list saved sessions
- saved_session_selection_request: SavedSessionSelectionRequest | null - request to select one saved session from the list

---

## 4. Outputs
- saved_sessions_list: SavedSessionsList - list of available saved session summaries
- saved_session_selection_result: SavedSessionSelectionResult | null - explicit result of selecting a saved session when selection is attempted

---

## 5. Data Models

### BrowseSavedSessionsRequest
- request_id: string - identifier for the browse attempt

### SessionSummary
- session_id: string - stable identifier for the saved session
- saved_at: string - timestamp of the successful save
- note_count: integer - number of notes in the saved session
- audio_available: boolean - whether playable audio is present for replay

### SavedSessionsList
- sessions: [SessionSummary] - selectable saved session summaries
- total_count: integer - number of summaries returned
- status: string - `HAS_RESULTS` or `EMPTY`

### SavedSessionSelectionRequest
- session_id: string - identifier of the saved session the user wants to open

### SavedSessionSelectionResult
- status: string - `SUCCESS` or `FAILED`
- selected_session_id: string | null - selected saved session identifier on success
- reason: string | null - explicit selection outcome or failure reason

---

## 6. Success Behavior

1. When browsing is requested, the system must return a `SavedSessionsList` representing all selectable saved sessions available to the user.
2. If no saved sessions exist, the system must return an empty list with status `EMPTY`.
3. When a selection request is provided, the system must validate that the requested `session_id` is currently selectable.
4. A valid selection must return a successful `SavedSessionSelectionResult` containing the selected `session_id`.

---

## 7. Failure Modes

- Condition: The system cannot access saved session records for browsing
  - System must: Return `BROWSE_SAVED_SESSIONS_UNAVAILABLE`

- Condition: A selection request references a session that is not selectable
  - System must: Return `SAVED_SESSION_NOT_FOUND`

- Condition: A saved session exists but is not complete enough to be replayed
  - System must: Exclude it from the selectable list or return `SAVED_SESSION_UNAVAILABLE` when selected

---

## 8. Edge Cases

- An empty saved session list must still return a successful browse response with zero results
- Two saved sessions with identical summary values other than `session_id` must remain separately selectable
- A session that becomes unavailable after browsing but before selection must fail explicitly at selection time
- Browse results must not include sessions that cannot be opened by the replay flow without additional undefined behavior

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define listing and selecting saved sessions only
- Must not replay, save, delete, edit, or share saved sessions
- Must return selection by stable saved session identifier

---

## 10. Observability

### Events
- `SavedSessionsBrowseRequested`
- `SavedSessionsBrowseCompleted`
- `SavedSessionSelected`
- `SavedSessionSelectionFailed`

### Metrics
- Count of browse requests
- Count of empty browse results
- Count of returned saved session summaries
- Count of successful and failed selection attempts

### Logs
- Browse request identifier
- Number of saved sessions returned
- Selected session identifier when selection succeeds
- Failure reason when browsing or selection does not succeed

---

## 11. Acceptance Criteria

- [ ] A browse request returns all currently selectable saved session summaries
- [ ] When no saved sessions exist, the response is an empty list with explicit empty status
- [ ] Selecting a listed `session_id` returns a successful selection result
- [ ] Selecting a non-selectable `session_id` fails explicitly
- [ ] Saved sessions that cannot be replayed are not silently treated as valid selections

---

## 12. Open Questions

- What default ordering should the saved session list use in v0.1?
- Should browse results include any additional summary metadata beyond save time, note count, and audio availability?
- Will pagination or filtering be required in v0.1?
