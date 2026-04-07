# Product Vision: PerchNotes

Version: 0.3.0  
Status: Draft

---

## Overview

PerchNotes is an experimental application that converts images of birds perched on powerlines into musical note sequences and playable audio loops.

The application explores how visual patterns in the real world can be transformed into sound.

---

## Core Idea

Birds sitting on a powerline form natural spatial patterns.

PerchNotes interprets those patterns as music by:

- treating horizontal position as time/order
- treating vertical position as pitch
- optionally using spacing to influence rhythm

---

## Goals

- Convert a single image into a deterministic musical sequence
- Generate audio that can be looped
- Allow users to replay and share generated results
- Explore Contract-Oriented Programming (COP) in a real application

---

## Non-Goals (for v0.1)

- Perfect bird detection accuracy
- Advanced music theory or composition tools
- Real-time video processing
- Complex editing of generated music

---

## Core Capabilities

The system should support:

- Capturing or selecting an image
- Detecting bird positions relative to a powerline
- Mapping positions to musical notes
- Generating a loopable audio sequence
- Saving generated sessions (optional)
- Replaying saved sessions
- Sharing generated audio

---

## User Experience (High-Level)

1. User opens the app
2. User captures or selects an image
3. System processes the image
4. System generates a musical loop
5. User listens to the result
6. User can:
   - replay
   - save
   - share

---

## Key Constraints

- Output must be deterministic for the same input
- System must handle failure cases (no birds, no line, etc.)
- Behavior must be defined through contracts
- Contracts must remain implementation-agnostic

---

## Open Questions

- How exactly should pitch mapping be defined?
- Should rhythm be uniform or spacing-based?
- How should multiple powerlines be handled?
- What constitutes a “valid” musical output?