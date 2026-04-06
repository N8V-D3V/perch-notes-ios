# Contract: Capture Image

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system acquires a single source image either by capturing a new image or selecting an existing image.

---

## 2. Actors
- User - chooses an acquisition method and provides or selects a single image
- System - validates the acquisition request and returns one acquired image or an explicit failure result

---

## 3. Inputs
- image_acquisition_request: ImageAcquisitionRequest - request to acquire one image
- camera_permission_state: CameraPermissionState - current camera availability state when camera capture is requested
- acquisition_response: ImageAcquisitionResponse | null - result of the user acquisition action when one is provided

---

## 4. Outputs
- source_image: SourceImage | null - the acquired image when acquisition succeeds
- image_acquisition_result: ImageAcquisitionResult - explicit acquisition outcome

---

## 5. Data Models

### ImageAcquisitionRequest
- acquisition_method: string - `CAPTURE_NEW_IMAGE` or `SELECT_EXISTING_IMAGE`

### CameraPermissionState
- state: string - `GRANTED`, `DENIED`, or `UNKNOWN`

### ImageAcquisitionResponse
- status: string - `COMPLETED`, `CANCELLED`, or `FAILED`
- image_count: integer - number of images returned by the acquisition action
- image_reference: string | null - reference to the acquired image when one exists

### SourceImage
- image_id: string - stable identifier for the acquired image
- origin_method: string - method used to acquire the image
- image_reference: string - reference to the acquired image content

### ImageAcquisitionResult
- status: string - `SUCCESS` or `FAILED`
- reason: string | null - explicit acquisition outcome or failure reason

---

## 6. Success Behavior

1. The system must accept an image acquisition request for exactly one acquisition method.
2. If the acquisition method is `CAPTURE_NEW_IMAGE`, the system must require the camera permission state to be `GRANTED` before acquisition can proceed.
3. If the acquisition method is `SELECT_EXISTING_IMAGE`, the system must allow acquisition without requiring camera permission.
4. When acquisition returns exactly one valid image, the system must produce one `SourceImage` and return a successful acquisition result.
5. If the user initiates a new acquisition request after a cancellation or failure, the system must treat it as a new independent acquisition attempt.

---

## 7. Failure Modes

- Condition: Camera capture is requested while camera permission is not `GRANTED`
  - System must: Return `CAMERA_PERMISSION_REQUIRED`

- Condition: The acquisition action completes with no image
  - System must: Return `NO_IMAGE_ACQUIRED`

- Condition: The acquisition action returns more than one image
  - System must: Return `MULTIPLE_IMAGES_NOT_SUPPORTED`

- Condition: The user cancels the acquisition action
  - System must: Return `IMAGE_ACQUISITION_CANCELLED`

- Condition: The returned image cannot be treated as a valid source image
  - System must: Return `INVALID_SOURCE_IMAGE`

---

## 8. Edge Cases

- Repeating an acquisition request after a cancellation must not reuse a prior failed result
- Selecting an existing image after camera denial must remain valid
- A failed capture attempt followed by a successful selection attempt must return only the successful source image
- An acquisition response marked `COMPLETED` with a missing image reference must be treated as invalid

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define image acquisition only
- Must not request or resolve camera permission
- Must not perform note generation, audio generation, saving, replay, or sharing
- Must return at most one source image per acquisition request

---

## 10. Observability

### Events
- `ImageAcquisitionRequested`
- `ImageAcquisitionCompleted`
- `ImageAcquisitionCancelled`
- `ImageAcquisitionFailed`

### Metrics
- Count of acquisition requests by method
- Count of successful acquisitions by method
- Count of cancellations
- Count of failures by failure reason

### Logs
- Acquisition method requested
- Camera permission state when camera capture is requested
- Acquisition response status
- Failure reason when acquisition does not succeed

---

## 11. Acceptance Criteria

- [ ] Camera capture requests fail explicitly when camera permission is not `GRANTED`
- [ ] Existing-image selection can succeed without camera permission
- [ ] A completed acquisition with exactly one valid image returns one `SourceImage`
- [ ] A cancelled acquisition returns an explicit cancellation result
- [ ] An acquisition response with zero or multiple images fails explicitly
- [ ] Retrying acquisition after cancellation or failure is treated as a new attempt

---

## 12. Open Questions

- What criteria determine whether an acquired image is valid for downstream bird-on-powerline processing?
- Should the contract allow user adjustment of an acquired image before it becomes the `SourceImage`?
- Should the system preserve any user-visible metadata about how the image was acquired beyond the origin method?
