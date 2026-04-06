# Contract: App Navigation Flow

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define the application entry point, the set of user-visible screens, and the valid navigation paths for creating a completed session, browsing saved sessions, and reopening a replay-ready session.

---

## 2. Actors
- User - navigates between screens to capture an image, review a completed session, browse saved sessions, and reopen a replay-ready session
- System - maintains the current screen and enforces valid navigation paths

---

## 3. Inputs
- app_launch_request: AppLaunchRequest - request to open the application
- navigation_action: NavigationAction - requested movement from one screen to another
- current_navigation_state: NavigationState - current screen and allowed next actions

---

## 4. Outputs
- navigation_state: NavigationState - updated screen and allowed next actions after a valid transition
- navigation_result: NavigationResult - outcome of the requested transition

---

## 5. Data Models

### AppLaunchRequest
- launch_source: string - identifies that the application has been opened for user interaction

### NavigationAction
- action_name: string - requested navigation action
- source_screen: string - screen from which the action was initiated
- target_screen: string - screen to which navigation is requested

### NavigationState
- current_screen: string - active screen
- previous_screen: string | null - most recent prior screen if one exists
- allowed_actions: [string] - navigation actions that are valid from the active screen
- has_source_image: boolean - whether a source image exists for the current session flow
- has_completed_session: boolean - whether note generation and audio generation have both succeeded for the current session flow
- has_selected_saved_session: boolean - whether a valid saved session has been selected for replay

### NavigationResult
- status: string - `SUCCESS` or `REJECTED`
- destination_screen: string | null - screen reached after the action if successful
- reason: string | null - rejection reason when navigation is not allowed

---

## 6. Success Behavior

1. On application launch, the system must enter the `Home` screen.
2. From `Home`, the user must be able to navigate to `Image Acquisition` and `Saved Sessions`.
3. From `Image Acquisition`, the user must be able to navigate to `Camera Permission` when camera-based acquisition requires camera access resolution.
4. From `Camera Permission`, the user must be able to return to `Image Acquisition` after permission is resolved or fallback is chosen.
5. From `Image Acquisition`, the user must be able to proceed to `Processing` only after a valid source image has been acquired.
6. From `Processing`, the system must navigate to `Generated Session` only after note generation and audio generation both succeed and a completed session exists.
7. `Generated Session` must represent one completed session and allow the user to remain on that screen while invoking replay, save, and share behaviors for that completed session.
8. From `Generated Session`, the user must be able to navigate back to `Home`.
9. From `Saved Sessions`, the user must be able to navigate to `Saved Session Replay` only after a valid saved session has been selected.
10. `Saved Session Replay` must open with a replay-ready session and must not begin playback automatically.
11. From `Saved Session Replay`, the user must be able to navigate back to `Saved Sessions` and `Home`.

---

## 7. Failure Modes

- Condition: A navigation action is requested from a screen that does not allow that action
  - System must: Reject the action, keep the current screen unchanged, and return `INVALID_NAVIGATION_ACTION`

- Condition: A navigation action targets a screen that requires missing prerequisite context
  - System must: Reject the action, keep the current screen unchanged, and return `MISSING_NAVIGATION_CONTEXT`

- Condition: Application launch does not produce an initial navigation state
  - System must: Return `NAVIGATION_INITIALIZATION_FAILED`

---

## 8. Edge Cases

- Back navigation requested from `Home` must leave the user on `Home`
- Direct navigation to `Processing` must be rejected when no acquired image exists
- Direct navigation to `Generated Session` must be rejected when no completed session exists
- Direct navigation to `Saved Session Replay` must be rejected when no saved session has been selected
- Entering `Saved Session Replay` must not change replay state from `READY` to active playback automatically

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define navigation paths only
- Must not define permission resolution behavior beyond the existence of the `Camera Permission` screen
- Must not define image acquisition, note generation, audio generation, save, replay, or share behavior beyond screen entry and exit paths

---

## 10. Observability

### Events
- `AppLaunched`
- `ScreenEntered`
- `NavigationRequested`
- `NavigationCompleted`
- `NavigationRejected`

### Metrics
- Count of app launches
- Count of successful navigation transitions by source and destination screen
- Count of rejected navigation transitions by rejection reason

### Logs
- Navigation action requested
- Source screen and target screen
- Navigation outcome and rejection reason when applicable

---

## 11. Acceptance Criteria

- [ ] On application launch, the initial screen is `Home`
- [ ] From `Home`, the user can navigate to `Image Acquisition`
- [ ] From `Home`, the user can navigate to `Saved Sessions`
- [ ] From `Image Acquisition`, the user can reach `Camera Permission` when camera access is required
- [ ] From `Image Acquisition`, the user can reach `Processing` only after a valid source image has been acquired
- [ ] From `Processing`, successful note generation and audio generation lead to `Generated Session`
- [ ] `Generated Session` represents a completed session
- [ ] From `Saved Sessions`, selecting a valid saved session leads to `Saved Session Replay`
- [ ] `Saved Session Replay` opens in a replay-ready state and does not begin playback automatically
- [ ] Invalid direct navigation to screens with missing prerequisite context is rejected with an explicit reason

---

## 12. Open Questions

- Should `Saved Sessions` also be reachable directly from `Generated Session`, or only from `Home`?
- Should any additional non-functional screens exist in v0.1, such as an informational landing screen before `Home`?
- Should processing failures navigate back to `Image Acquisition` automatically, or remain on `Processing` with an explicit retry path?
