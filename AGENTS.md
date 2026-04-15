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
- Do not skip workflow stages (contract → protocol → architecture → module → orchestrator → validation)
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

---

## Commit Format

Commits should be structured like:

- Title -> `ADD/REMOVE/UPDATE/FIX/BUMP: <short description>`
- Description -> Human friendly and accurate description
- `BUMP` commits are for version bumps and should look like: `BUMP: vx.x.x`

---

## Orchestrator Reporting Requirement

After completing any task, you MUST report back to the Orchestrator.

You MUST use the report format defined in:

`docs/cop/report-template.md`

---

## Rules

- Do not skip reporting
- Do not use unstructured summaries
- Follow the report template exactly
- Ensure all sections are completed

---

## Purpose

This ensures:

- visibility across agents
- consistent handoffs
- better decision-making by the orchestrator
