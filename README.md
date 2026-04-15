# PerchNotes

PerchNotes is an experimental app that converts images of birds on powerlines into musical note sequences.

This project is built using **Contract-Oriented Programming (COP)**, where contracts define system behavior and serve as the source of truth for development.

---

## Overview

Given an image of birds on a powerline, PerchNotes:

1. Detects bird positions along the line  
2. Maps those positions to musical notes  
3. Generates a sequence of notes  
4. Plays the sequence as a loop  

The goal is to explore how structured contracts and AI-assisted workflows can be used to build real applications.

---

## Purpose

This project serves as:

- A testbed for COP in a real application  
- A demonstration of contract-first, AI-assisted development  
- A simple but non-trivial system with edge cases and constraints  

---

## How It Works (Conceptually)

- Horizontal position → note order (time)  
- Vertical position → pitch  
- Bird spacing → influences rhythm or timing (to be defined in contracts)  

All behavior is defined through contracts in `docs/contracts/`.

---

## Project Structure

    .
    ├── AGENTS.md
    └── docs/
        ├── cop/         # COP doctrine (read-only)
        └── contracts/   # Feature contracts (source of truth)

---

## Getting Started

1. Read COP documentation in:
   `docs/cop/`

2. Start with the contract template:
   `docs/cop/contract-template.md`

3. Create or review contracts in:
   `docs/contracts/`

---

## Development Approach

This project follows these principles:

- Contracts are the source of truth  
- Implementation must conform to contracts  
- No behavior is introduced without being defined in a contract  
- All work should align with `AGENTS.md`  

---

## Standard COP Workflow

1. Contract Agent
2. Protocol Agent
3. Architecture Agent
4. Module Agent
5. Orchestrator Agent
6. Validation Agent

---

## Status

Early experimental phase.

The focus is on:
- defining clear contracts  
- validating COP in practice  
- iterating on system design  

---

## Related

- COP Starter Kit: <link your repo here>

---

## Philosophy

Define the system clearly.  
Then let humans and AI build it correctly.
