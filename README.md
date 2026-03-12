# Agent Queue

Automated orchestration system for personal coding agents. Discovers tasks across your projects, lets you review and prioritize them via a real-time web dashboard, then executes them unattended using [`pi`](https://github.com/anthropics/pi) within a configurable time budget.

## Problem

If you have coding agents with daily usage limits but can't actively guide them during work hours, those limits go to waste. Agent Queue solves this by automating the discovery and execution of tasks so your agents stay productive while you're busy.

## How It Works

1. **Discover** — A scheduled scan (or manual trigger) examines your `~/projects/` repos and proposes tasks based on open issues, TODOs, failing tests, outdated deps, and planning docs.
2. **Review** — Each morning, open the LiveView dashboard to approve, reject, or reprioritize proposed tasks.
3. **Run** — Kick off the queue with a time budget. Tasks execute sequentially via `pi -p` (non-interactive mode) on isolated git branches. Completed tasks move to a `review` state with changes left uncommitted for your inspection.

## Features

- Automatic task discovery across all personal projects
- Real-time LiveView dashboard for review, prioritization, and status tracking
- Configurable time budget to stay within usage limits
- Git branch isolation (`aq/<task-id>`) for safe, unattended execution
- OTP-supervised task runner with fault tolerance
- Mix tasks for CLI and cron integration

## Quick Start

```bash
# Install dependencies
mix deps.get

# Create and migrate the database
mix ecto.setup

# Start the Phoenix server
mix phx.server

# In another terminal — discover tasks across your projects
mix aq.discover

# Run approved tasks with a 4-hour budget
mix aq.run --budget 240
```

Then visit [`localhost:4000`](http://localhost:4000) to open the dashboard.

## CLI Commands

| Command | Description |
|---------|-------------|
| `mix phx.server` | Start the web dashboard |
| `mix aq.discover` | Scan projects and propose tasks |
| `mix aq.run` | Execute approved tasks sequentially |
| `mix aq.run --budget <min>` | Set a maximum runtime in minutes |
| `mix aq.run --dry-run` | Preview what would execute |

## Scheduling

Set up cron jobs for hands-free operation:

```crontab
# Discover new tasks nightly at 2 AM
0 2 * * * cd ~/projects/agent-queue && mix aq.discover

# Execute approved tasks at 8 AM with a 4-hour budget
0 8 * * * cd ~/projects/agent-queue && mix aq.run --budget 240
```

## Task Lifecycle

```
proposed → approved → running → review → completed
                        ↓
                      failed
```

- **proposed** — Auto-discovered or manually created, awaiting review
- **approved** — Ready for the next execution run
- **running** — Currently being worked on by an agent
- **review** — Agent finished successfully; changes on branch awaiting human inspection
- **completed** — Reviewed and accepted
- **failed** — Agent encountered an error
- **rejected** — Dismissed during review

## Tech Stack

- Elixir, Phoenix Framework, LiveView
- PostgreSQL via Ecto
- OTP GenServers + Supervisors

## License

MIT
