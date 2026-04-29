# Copilot Project Instructions

## Memory Bank

This project maintains a two-tier memory bank at `memory-bank/` for cross-session context.

### Always read on session start:
- `memory-bank/activeContext.md` — Current focus, last decision, known risks (≤20 lines, local only)

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
- You can invoke the `@memory-bank-synchronizer` agent or type `/update-memory-bank` to trigger a full sync.
