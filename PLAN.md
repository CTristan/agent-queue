# Plan: Agent Queue — Automated Personal Coding Agent Orchestrator

## Context

Personal coding agents (`pi` CLI) have 5-hour daily usage limits that go underutilized during work hours. This project creates an orchestration system that:
1. **Discovers** potential tasks across all personal projects in `~/projects/`
2. Lets you **review and prioritize** tasks via a web dashboard each morning
3. **Executes** tasks autonomously using `pi -p` (non-interactive mode) within a configurable time budget

The system runs on a home Mac.

## Goals

- Maximize utilization of the 5-hour daily `pi` usage window
- Minimize manual effort — discovery is automated, review is quick (web UI)
- Tasks execute unattended with clear status tracking and result visibility
- Simple, single-machine deployment (no cloud infra needed)

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  agent-queue                     │
│                                                  │
│  CLI (Mix tasks)     Web Dashboard (LiveView)    │
│  ┌──────────┐        ┌──────────────────────┐    │
│  │ discover │        │ Review / Prioritize  │    │
│  │ run      │        │ Task Results / Diffs  │    │
│  │ serve    │        │ Project Overview      │    │
│  └────┬─────┘        └──────────┬───────────┘    │
│       │                         │                │
│       └────────┬────────────────┘                │
│                │                                 │
│         ┌──────▼──────┐                          │
│         │  Phoenix    │  (LiveView)              │
│         │  Server     │                          │
│         └──────┬──────┘                          │
│                │                                 │
│         ┌──────▼──────┐    ┌─────────────┐       │
│         │  PostgreSQL │    │  pi -p      │       │
│         │   (Ecto)    │    │  (Port /    │       │
│         │             │    │   GenServer)│       │
│         └─────────────┘    └─────────────┘       │
└─────────────────────────────────────────────────┘
```

## Tech Stack

- **Backend:** Elixir, Phoenix Framework
- **Database:** PostgreSQL via Ecto
- **Frontend:** Phoenix LiveView (no separate JS build needed)
- **CLI:** Mix tasks (e.g., `mix aq.discover`, `mix aq.run`)
- **Agent invocation:** `pi -p` via Elixir `Port` / `System.cmd`
- **Process management:** OTP GenServers + Supervisors for fault-tolerant task execution

## Data Model

### `projects` table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| path | TEXT UNIQUE | Absolute path to project |
| name | TEXT | Directory name |
| last_scanned | DATETIME | Last discovery scan time |
| enabled | BOOLEAN | Whether to include in scans |

### `tasks` table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| project_id | INTEGER FK | References projects |
| title | TEXT | Short task description |
| description | TEXT | Detailed task spec / prompt for `pi` |
| status | TEXT | `proposed` / `approved` / `running` / `review` / `completed` / `failed` / `rejected` |
| priority | INTEGER | Lower = higher priority |
| source | TEXT | How discovered: `auto` / `manual` |
| created_at | DATETIME | When proposed |
| started_at | DATETIME | When execution began |
| completed_at | DATETIME | When finished |

### `runs` table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| task_id | INTEGER FK | References tasks |
| command | TEXT | Full `pi` command executed |
| stdout | TEXT | Agent output |
| stderr | TEXT | Error output |
| exit_code | INTEGER | Process exit code |
| duration_seconds | INTEGER | How long the run took |
| started_at | DATETIME | Run start time |
| completed_at | DATETIME | Run end time |

## Tasks

### Phase 1: Project Scaffolding
- [ ] Generate Phoenix project: `mix phx.new agent_queue --database postgres`
- [ ] Set up project structure:
  ```
  lib/
    agent_queue/
      projects/        # Project context (Ecto schemas, queries)
      tasks/           # Task context (Ecto schemas, queries)
      runner/          # GenServer for task execution
      discovery/       # Task discovery logic
    agent_queue_web/
      live/            # LiveView pages
      components/      # Reusable UI components
  ```
- [ ] Create Ecto migrations for projects, tasks, and runs tables
- [ ] Create Mix tasks for CLI (`mix aq.discover`, `mix aq.run`)

### Phase 2: Project Scanner
- [ ] `mix aq.discover` task that scans `~/projects/` for git repositories
- [ ] Auto-register new projects in the `projects` table via Ecto
- [ ] Skip projects that already have pending/approved tasks (configurable)

### Phase 3: Task Discovery
- [ ] Build a discovery prompt template that instructs `pi` to examine a repo and output structured task suggestions (JSON)
- [ ] The prompt should tell `pi` to look at:
  - GitHub issues (via `gh` CLI if available)
  - TODO/FIXME/HACK comments in code
  - Failing tests or lint errors
  - Outdated dependencies
  - Existing PLAN.md, CLAUDE.md, or similar planning docs
  - General code quality improvements
- [ ] Parse `pi -p` output and insert proposed tasks into the database
- [ ] Rate-limit discovery to avoid burning the usage budget (configurable max time for discovery phase)

### Phase 4: Task Execution Engine
- [ ] `AgentQueue.Runner` GenServer supervised by OTP for fault tolerance
- [ ] `mix aq.run` task (and LiveView trigger) to start processing approved tasks
- [ ] Accept `--budget <minutes>` flag to set maximum total runtime
- [ ] Execute tasks sequentially by priority order:
  1. `cd` into the project directory
  2. Run `pi -p "<task description>"` via Elixir `Port` (streams output in real-time)
  3. Capture stdout/stderr and exit code into `runs` table via Ecto
  4. On success: set task status to `review` (changes left uncommitted for human verification)
  5. On failure: set task status to `failed`
  6. Check remaining time budget before starting next task
- [ ] Support `--dry-run` to show what would execute without running
- [ ] Use git branches to isolate agent changes (create `aq/<task-id>` branch before running)
- [ ] Broadcast status updates via Phoenix PubSub for real-time LiveView updates

### Phase 5: LiveView Dashboard
- [ ] **Project list LiveView:** shows all projects, last scanned, task counts
- [ ] **Task queue LiveView:**
  - Filterable by status (proposed / approved / review / completed / failed)
  - Drag-and-drop reordering for priority (via LiveView JS hooks or `SortableJS`)
  - Approve/reject buttons for proposed tasks
  - `review` tasks highlighted — click to inspect changes, then mark `completed` or send back
  - Click to expand task details and view run output
  - Real-time status updates via PubSub (no polling)
- [ ] **Run trigger panel:**
  - Set time budget (slider or input)
  - Start/stop execution (sends message to Runner GenServer)
  - Live status indicator with real-time streaming output
- [ ] **Task creation:** manually add tasks for any project
- [ ] Keep it simple — no auth needed (local-only tool)
- [ ] Mobile-responsive layout (future: accessible from phone on home network)

### Phase 6: Scheduling & Automation
- [ ] Mix tasks for cron integration (`mix aq.discover`, `mix aq.run --budget 240`)
- [ ] Example crontab entries:
  - Discovery: `0 2 * * * cd ~/projects/agent-queue && mix aq.discover` (2 AM nightly)
  - Execution: `0 8 * * * cd ~/projects/agent-queue && mix aq.run --budget 240` (8 AM, 4-hour budget)
- [ ] Or: discovery runs nightly, execution waits for manual trigger via LiveView after morning review
- [ ] Application config (`config/runtime.exs`) for:
  - Projects directory path
  - Default time budget
  - Discovery settings (max time, skip patterns)
  - `pi` CLI flags and provider/model overrides

## Resolved Decisions

- **Post-execution behavior:** Changes are left uncommitted on the `aq/<task-id>` branch. Task status moves to `review` — visible in the dashboard but skipped by the runner. Human manually inspects, commits/discards, and marks as `completed`.
- **Notifications:** Not in MVP scope. Future enhancement candidate (macOS notifications, email, etc.).

## Risks & Considerations

- **Usage budget tracking:** `pi` doesn't expose remaining usage via API — the time budget is a proxy, not exact. May need to track cumulative runtime across sessions.
- **Task quality:** Auto-discovered tasks may be low quality or irrelevant. The review step is critical — never auto-approve and auto-execute without human review.
- **Git safety:** Always run agents on branches, never directly on main. The execution engine should create `aq/<task-id>` branches before running.
- **Concurrent execution:** Start with sequential execution. Parallel execution would be more efficient but adds complexity (multiple `pi` sessions may count against the same usage limit).
- **Output size:** Agent stdout can be very large. Consider truncating or streaming to files rather than storing entirely in Postgres.
- **Discovery prompt engineering:** The quality of auto-discovered tasks depends heavily on the discovery prompt. This will need iteration.
