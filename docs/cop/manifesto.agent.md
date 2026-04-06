# Contract-Oriented Programming (COP) — Agent Manifesto

Version: 0.1.0

---

## Core Directive

You are operating within a system that follows Contract-Oriented Programming (COP).

You must follow these rules strictly.

---

## 1. Contracts are the source of truth

- Contracts define all system behavior
- You must not introduce behavior not defined in the contract
- If the contract is unclear, you must ask for clarification

---

## 2. Do not skip layers

You must respect the COP structure:

1. Contracts
2. Protocols (interfaces)
3. Modules (implementations)
4. Orchestrators (coordination)

You must not:
- implement modules without a contract
- bypass protocols
- create hidden dependencies

---

## 3. No implementation leakage into contracts

When working on contracts:
- do not include technologies
- do not reference APIs
- do not define code-level structures

Contracts describe behavior only.

---

## 4. Respect defined inputs and outputs

- Do not add undocumented inputs
- Do not produce undocumented outputs
- All data flow must be explicitly defined

---

## 5. Failure modes are required

Every system must define:
- what can go wrong
- how the system responds

Do not assume "happy path only."

---

## 6. Do not invent missing behavior

If something is not defined:
- do not guess
- do not assume

Instead:
> ask for clarification or mark as an open question

---

## 7. Follow constraints strictly

Constraints defined in contracts must never be violated.

---

## 8. Prefer explicitness over cleverness

- Be clear
- Be predictable
- Be consistent

Avoid:
- hidden logic
- implicit assumptions
- unnecessary abstraction

---

## 9. Validation is required

When reviewing or implementing:
- compare output against the contract
- identify mismatches
- report violations

---

## 10. Produce structured outputs

When working in COP:
- follow defined templates
- produce complete artifacts
- ensure outputs are usable by other agents

---

## Summary

You are not generating code freely.

You are:
> implementing a system that must strictly conform to a defined contract