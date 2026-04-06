# Contract: Share Generated Audio

Version: 0.1.0  
Status: Draft

---

## 1. Purpose
Define how the system shares generated audio without requiring the session to be saved first.

---

## 2. Actors
- User - requests that generated audio be shared
- System - validates the generated audio, prepares a shareable audio artifact, and returns a share result

---

## 3. Inputs
- share_generated_audio_request: ShareGeneratedAudioRequest - request to share one generated audio artifact

---

## 4. Outputs
- share_result: ShareResult - explicit share outcome
- shareable_audio: ShareableAudio | null - share-ready audio artifact when sharing preparation succeeds

---

## 5. Data Models

### GeneratedAudio
- audio_id: string - stable identifier for the generated audio artifact
- source_image_id: string - identifier of the originating image
- note_count: integer - number of notes represented in the audio
- audio_reference: string - reference to the generated audio content

### ShareGeneratedAudioRequest
- generated_audio: GeneratedAudio - generated audio requested for sharing

### ShareableAudio
- audio_id: string - identifier of the audio being shared
- audio_reference: string - reference to the share-ready audio content

### ShareResult
- status: string - `SUCCESS`, `CANCELLED`, or `FAILED`
- reason: string | null - explicit share outcome or failure reason

---

## 6. Success Behavior

1. The system must accept one `GeneratedAudio` artifact per share request.
2. The system must validate that the submitted generated audio is present and shareable.
3. When validation succeeds, the system must produce one `ShareableAudio` artifact for that generated audio.
4. A successful share flow must return `SUCCESS`.
5. Sharing generated audio must not require that the session has been saved previously.

---

## 7. Failure Modes

- Condition: The share request does not include generated audio
  - System must: Return `MISSING_GENERATED_AUDIO`

- Condition: The submitted audio cannot be prepared for sharing
  - System must: Return `SHARE_PREPARATION_FAILED`

- Condition: The user exits the share flow before completion
  - System must: Return `CANCELLED`

- Condition: The system cannot complete the share flow
  - System must: Return `SHARE_FAILED`

---

## 8. Edge Cases

- The same generated audio may be shared more than once through separate share requests
- Generated audio may be shared whether or not it has been saved as part of a session
- A share request made while audio playback is active must not invalidate the generated audio being shared
- A successful share must not modify the generated audio artifact

---

## 9. Constraints

- Must not introduce behavior outside this contract
- Must not bypass defined interfaces
- Must follow system-level rules
- Must define generated-audio sharing only
- Must not save, browse, replay, or regenerate the session
- Must not require sharing of source image, note data, or other artifacts not defined in this contract

---

## 10. Observability

### Events
- `GeneratedAudioShareRequested`
- `GeneratedAudioSharePrepared`
- `GeneratedAudioShareCompleted`
- `GeneratedAudioShareCancelled`
- `GeneratedAudioShareFailed`

### Metrics
- Count of share requests
- Count of successful shares
- Count of cancelled share flows
- Count of failed shares by failure reason

### Logs
- Generated audio identifier
- Share preparation outcome
- Share completion status
- Failure reason when sharing does not succeed

---

## 11. Acceptance Criteria

- [ ] A share request with valid generated audio produces one `ShareableAudio` artifact
- [ ] A completed share flow returns `SUCCESS`
- [ ] A share request without generated audio fails explicitly
- [ ] Exiting the share flow before completion returns `CANCELLED`
- [ ] Sharing does not require the originating session to be saved first
- [ ] Sharing does not modify the generated audio artifact

---

## 12. Open Questions

- Should the shared artifact include any user-visible title or label in v0.1?
- Should share behavior differ between newly generated audio and audio loaded from a saved session?
- Are there any product limits on how large a shareable audio artifact may be in v0.1?
