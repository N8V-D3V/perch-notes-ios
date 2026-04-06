# Contract Template Usage Rules

Version: 0.1.0

---

## Purpose

This document defines how contracts must be written.

The goal is to ensure:
- clarity
- consistency
- AI compatibility
- enforceable behavior definitions

---

## Rule 1: No implementation details

Do NOT include:
- frameworks
- APIs
- databases
- code structures

Contracts define behavior only.

---

## Rule 2: Be explicit

Avoid vague language.

Bad:
"Handle errors gracefully"

Good:
"If the ticket is expired, system must return EXPIRED_TICKET error"

---

## Rule 3: Define all inputs and outputs

Nothing should be implicit.

---

## Rule 4: Define failure modes

Failure is not optional.

For every feature:
- list what can go wrong
- define system response

---

## Rule 5: Cover edge cases

Think beyond the happy path.

---

## Rule 6: Keep contracts minimal but complete

Do not:
- over-engineer
- add unnecessary detail

Do:
- include everything required for correct behavior

---

## Rule 7: Use consistent structure

Always follow the template.

---

## Rule 8: Use testable acceptance criteria

Every acceptance criterion must be verifiable.

---

## Rule 9: Do not invent behavior

If something is unclear:
- add it to Open Questions
- do not assume

---

## Rule 10: Contracts evolve

Contracts are not static.

They should be:
- refined
- updated
- improved based on real usage

---

## Summary

A good contract is:
- clear
- complete
- testable
- free of implementation detail

If an AI can misinterpret it, it is not good enough.