# Contract: App Navigation Flow

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define the application entry point, the set of user-visible screens, and the valid navigation paths between those screens.

---

## 2. Actors
- User - navigates between screens to capture an image, review generated output, browse saved sessions, and replay saved sessions
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

### NavigationResult
- status: string - `SUCCESS` or `REJECTED`
- destination_screen: string | null - screen reached after the action if successful
- reason: string | null - rejection reason when navigation is not allowed

---

## 6. Success Behavior

1. On application launch, the system must enter the `Home` screen.
2. From `Home`, the user must be able to navigate to `Image Acquisition` and `Saved Sessions`.
3. From `Image Acquisition`, the user must be able to navigate to `Camera Permission` when camera access is required, or proceed to `Processing` after a valid image has been acquired.
4. From `Camera Permission`, the user must be able to return to `Image Acquisition` after permission is resolved or fallback is chosen.
5. From `Processing`, the system must navigate to `Generated Session` when note generation and audio generation both complete successfully.
6. From `Generated Session`, the user must be able to remain on the same screen while invoking replay, save, and share behaviors, and must be able to navigate back to `Home`.
7. From `Saved Sessions`, the user must be able to navigate to `Saved Session Replay` after selecting a saved session.
8. From `Saved Session Replay`, the user must be able to navigate back to `Saved Sessions` and `Home`.

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
- Direct navigation to `Generated Session` must be rejected when generated output does not exist
- Direct navigation to `Saved Session Replay` must be rejected when no saved session has been selected

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
- [ ] From `Image Acquisition`, the user can reach `Processing` only after a valid image has been acquired
- [ ] From `Processing`, successful generation leads to `Generated Session`
- [ ] From `Saved Sessions`, selecting a saved session leads to `Saved Session Replay`
- [ ] Invalid direct navigation to screens with missing prerequisite context is rejected with an explicit reason

---

## 12. Open Questions

- Should `Saved Sessions` also be reachable directly from `Generated Session`, or only from `Home`?
- Should any additional non-functional screens exist in v0.1, such as an informational landing screen before `Home`?
- Should processing failures navigate back to `Image Acquisition` automatically, or remain on `Processing` with an explicit retry path?
