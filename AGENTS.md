# AGENTS.md

This project follows **Contract-Oriented Programming (COP)**.

---

## Core Rule

Before performing any work, you MUST review:

- `docs/cop/manifesto.agent.md`
- `docs/cop/contract-template.md`
- `docs/cop/contract-template-usage.md`
- `docs/cop/glossary.md`

These documents define how this system operates.

---

## Expectations

- Contracts are the source of truth
- Do not introduce behavior not defined in contracts
- Do not skip layers (contract → protocol → module → orchestrator)
- Do not invent missing requirements
- Follow all template and usage rules

---

## When in doubt

If something is unclear or undefined:
- ask for clarification
- or document it in "Open Questions"

---

## Goal

Your role is to produce work that:
- is consistent
- is predictable
- strictly follows defined contracts