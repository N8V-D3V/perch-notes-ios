# Protocol: ImageProvider

Version: 0.3.0
Status: Draft

Derived From:
- `docs/cop/contracts/capture-image.md`

---

## 1. Name
ImageProvider

---

## 2. Purpose
Provide the capability to acquire exactly one `SourceImage` from either a new capture request or an existing-image selection request.

---

## 3. Inputs
- `image_acquisition_request: ImageAcquisitionRequest` - acquisition request for one image
- `camera_permission_state: CameraPermissionState` - current camera availability state when camera capture is requested

---

## 4. Outputs
- `source_image: SourceImage | null` - acquired image when acquisition succeeds
- `image_acquisition_result: ImageAcquisitionResult` - explicit acquisition outcome

---

## 5. Behavior Requirements
1. Must accept exactly one acquisition method per request.
2. When `acquisition_method` is `CAPTURE_NEW_IMAGE`, must proceed only when `camera_permission_state.state` is `GRANTED`.
3. When `acquisition_method` is `SELECT_EXISTING_IMAGE`, must allow acquisition without requiring camera permission.
4. On success, must produce exactly one `SourceImage`.
5. A successful `SourceImage.origin_method` must match the requested acquisition method.
6. A successful `SourceImage` must include a stable `image_id` and a non-null `image_reference`.
7. Must return at most one `SourceImage` for each acquisition request.
8. A new acquisition request after cancellation or failure must be treated as a new independent attempt.

---

## 6. Failure Behavior
- Failures must be represented by `image_acquisition_result.status = FAILED`.
- When acquisition does not succeed, `source_image` must be `null`.
- Failure reason must be one of:
  - `CAMERA_PERMISSION_REQUIRED`
  - `NO_IMAGE_ACQUIRED`
  - `MULTIPLE_IMAGES_NOT_SUPPORTED`
  - `IMAGE_ACQUISITION_CANCELLED`
  - `INVALID_SOURCE_IMAGE`
  - `IMAGE_ACQUISITION_FAILED`

---

## 7. Constraints
- Must define image acquisition capability only.
- Must not request or resolve camera permission.
- Must not perform note generation, audio generation, saving, replay, browsing, or sharing.
- Must not reuse a prior failed or cancelled acquisition result as the output of a new request.
- Must not produce more than one upstream image artifact for a single request.
