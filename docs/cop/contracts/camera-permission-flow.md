# Contract: Camera Permission Flow

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system requests camera access, resolves approval or denial, supports retry, and provides a fallback path when camera-based image acquisition is not available.

---

## 2. Actors
- User - responds to the camera access request and chooses retry or fallback actions
- System - evaluates current permission state, requests camera access when allowed, and returns the resolved permission outcome

---

## 3. Inputs
- permission_request: CameraPermissionRequest - request to enable camera-based image acquisition
- current_permission_state: CameraPermissionState - current known camera access state
- permission_response: PermissionResponse | null - user decision returned from the permission request when one is provided
- permission_action: PermissionAction - follow-up action such as retry or fallback

---

## 4. Outputs
- permission_resolution: PermissionResolution - resolved state and next available actions
- permission_result: PermissionResult - outcome of the permission flow

---

## 5. Data Models

### CameraPermissionRequest
- request_source: string - context in which camera access is being requested

### CameraPermissionState
- state: string - `UNKNOWN`, `GRANTED`, or `DENIED`

### PermissionResponse
- decision: string - `APPROVED`, `DENIED`, or `NO_DECISION`

### PermissionAction
- action_name: string - `REQUEST`, `RETRY`, or `FALLBACK`

### PermissionResolution
- resolved_state: string - `GRANTED`, `DENIED`, or `UNRESOLVED`
- camera_capture_available: boolean - whether camera-based acquisition may proceed
- fallback_image_selection_available: boolean - whether non-camera acquisition may proceed
- retry_available: boolean - whether the user may attempt the flow again

### PermissionResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit outcome or failure reason

---

## 6. Success Behavior

1. When camera-based acquisition is requested and the current permission state is `UNKNOWN`, the system must request a permission decision.
2. If the permission response is `APPROVED`, the system must resolve the permission state to `GRANTED`, mark camera capture as available, and keep fallback image selection available.
3. If the permission response is `DENIED`, the system must resolve the permission state to `DENIED`, block camera capture, and keep fallback image selection available.
4. If the user chooses `RETRY` after a denied or unresolved result, the system must evaluate the current permission state again and attempt the permission flow without implicitly granting camera capture.
5. If the user chooses `FALLBACK`, the system must end the permission flow with camera capture unavailable and fallback image selection available.

---

## 7. Failure Modes

- Condition: A permission request is initiated without a valid permission action
  - System must: Return `INVALID_PERMISSION_ACTION`

- Condition: The permission flow completes without an approval or denial decision
  - System must: Return `PERMISSION_UNRESOLVED`, keep camera capture unavailable, and keep fallback image selection available

- Condition: A retry action is requested but the permission state cannot be re-evaluated
  - System must: Return `PERMISSION_RETRY_FAILED`, keep camera capture unavailable, and keep fallback image selection available

---

## 8. Edge Cases

- Repeated denials must continue to keep fallback image selection available
- A previously granted state must not be downgraded unless a new evaluated state explicitly indicates denial
- Exiting the permission flow without a decision must produce an unresolved result rather than an implicit denial
- Choosing fallback after denial must end the permission flow without initiating camera capture

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define permission request, denial, approval, retry, and fallback only
- Must not capture or acquire an image
- Must not define screen navigation beyond returning permission outcomes and available next actions

---

## 10. Observability

### Events
- `CameraPermissionRequested`
- `CameraPermissionResolved`
- `CameraPermissionRetryRequested`
- `CameraPermissionFallbackChosen`

### Metrics
- Count of permission requests
- Count of approvals, denials, and unresolved outcomes
- Count of retry actions
- Count of fallback selections

### Logs
- Starting permission state
- Permission action requested
- Resolved permission state
- Failure reason when the flow does not resolve successfully

---

## 11. Acceptance Criteria

- [ ] When the starting permission state is `UNKNOWN`, the system requests a permission decision
- [ ] An approved response results in `GRANTED` with camera capture available
- [ ] A denied response results in `DENIED` with camera capture unavailable and fallback available
- [ ] A retry action reevaluates the permission flow without implicitly enabling camera capture
- [ ] A fallback action completes the flow with camera capture unavailable and non-camera acquisition available
- [ ] An unresolved permission flow returns an explicit failure result

---

## 12. Open Questions

- What exact conditions should make retry unavailable in v0.1?
- Should fallback image selection always remain available, or are there product scenarios where it may be disabled?
- Should a previously granted permission state bypass the visible permission flow entirely, or still produce an explicit resolved result for observability?
