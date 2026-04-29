# AGENTS.md

## Stack
<!-- One line per layer. Detected from project. -->

## Build / Test / Lint
<!-- Copy exact commands so agents don't guess. -->

## Memory Bank

This project uses a two-tier memory bank at `memory-bank/`.

### Always read on session start:
- `memory-bank/activeContext.md` — Current focus, last decision, known risks (≤20 lines, local only / gitignored)

### Read on demand:
| File | Read when... |
|---|---|
| `projectOverview.md` | Starting a new feature or onboarding |
| `decisionLog.md` | Making an architectural or scoping decision |
| `dataContracts.md` | Creating or modifying data-consuming components |
| `conventions.md` | Writing new code or reviewing patterns |
| `openQuestions.md` | Encountering ambiguity — check here before guessing |

### Updating the bank:
- After completing a feature or making a significant decision, update `activeContext.md` and the relevant on-demand file.
- `activeContext.md` is a queue: evict completed items to `decisionLog.md`.
- Never let `activeContext.md` exceed 20 lines.

## Conventions
<!-- Populated from detection or manually. Keep to ≤10 rules. -->
