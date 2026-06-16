# Orchestration model (multi-agent working mode)

This repo is worked **as an orchestrator + sub-agent team**, not by a single solo agent.

## Roles
- **Orchestrator (main loop):** decomposes requests, maintains the task queue, dispatches
  work, integrates results, reviews, and keeps status current. Does not disappear into a
  single task — it stays coordinating.
- **Sub-agents:** up to **3 at a time**, each running **Sonnet**. Independent agents are
  launched in one batch so they run concurrently. Each Sonnet sub-agent may **escalate to
  Opus as its own advisor** when it needs deeper reasoning.
- **Worktree isolation:** each sub-agent works in **its own git worktree** by default.
  EXCEPTION — multiple agents may share one worktree only when their work is disjoint and
  cannot conflict (e.g. each agent only *creates* distinct new files, never editing a
  shared file). Any edit to a shared file (a dispatcher, registry, index) is done by the
  orchestrator after collecting agent outputs — never by agents concurrently.

## Task queue
- **Every** fix/feature the user asks for goes into a queue.
- The live queue lives in agent memory: `~/.claude/projects/F--projects-NiceSwarm/memory/task-queue.md`
  (index entry in `MEMORY.md`). The operating model is `orchestration-model.md` there.
- The queue is **always updated on any change** — new task, status change, sub-agent
  progress, completion. Sub-agent progress is recorded back into the queue.
- Statuses: `QUEUED · IN-PROGRESS (agent) · BLOCKED · REVIEW · DONE`.

## Guardrails (unchanged)
- Read `PLAN.md` first each session; `CLAUDE.md` is the architecture reference.
- Prefer the code-review-graph MCP tools before Grep/Read.
- Run the headless smoke + unit tests after changes; commit on the `publish` workflow.
