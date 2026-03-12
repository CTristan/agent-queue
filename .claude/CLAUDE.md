# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
mix setup                    # Install deps, create DB, run migrations, build assets
mix phx.server               # Start dev server on localhost:4000
mix deps.get                 # Install dependencies
mix ecto.setup               # Create DB + migrate + seed
mix ecto.reset               # Drop and recreate DB
mix ecto.gen.migration <name> # Generate a new migration
```

## Testing

```bash
mix test                              # Run all tests (auto-creates/migrates test DB)
mix test test/agent_queue/runner_test.exs  # Run a single test file
mix test test/path_test.exs:42        # Run a specific test by line number
```

## Code Quality

```bash
mix format                   # Auto-format code
mix format --check-formatted # Check formatting (CI mode)
mix credo                    # Run linter (strict mode)
./scripts/ci.sh              # Full CI: compile warnings + format + credo
./scripts/ci.sh --check      # CI in read-only mode
```

CI compiles with `--warnings-as-errors` (MIX_ENV=ci). Credo is configured strict with 120-char line limit.

## Application CLI

```bash
mix aq.discover              # Scan ~/projects for tasks via pi agent
mix aq.run                   # Execute approved tasks sequentially
mix aq.run --budget 240      # Set 4-hour time budget
mix aq.run --dry-run         # Preview without executing
```

## Architecture

Elixir/Phoenix LiveView app that discovers coding tasks across git repos and executes them via the `pi` CLI agent.

**Core OTP processes** (supervised in `application.ex`):
- `Discoverer` (GenServer) — scans projects, runs `pi -p` to propose tasks, broadcasts status via PubSub
- `Runner` (GenServer) — executes approved tasks sequentially on isolated `aq/<task-id>` git branches within a time budget

**Context modules** (`lib/agent_queue/`):
- `Discovery` — project scanning, pi agent invocation, JSON output parsing with validation (max 10 tasks, 10KB limit)
- `Projects`, `Tasks`, `Runs`, `Settings` — domain CRUD via Ecto/PostgreSQL

**Web layer** (`lib/agent_queue_web/`):
- `TasksLive` — real-time task dashboard (approve/reject/reorder)
- `ProjectsLive` — project management and discovery controls
- `SettingsLive` — discovery configuration
- All LiveViews subscribe to PubSub topics for real-time updates

**Task lifecycle:** proposed → approved → running → review → completed (or failed/rejected)

**PubSub topics:** `"discoverer:status"`, `"discoverer:logs"`, `"runner:status"`, `"tasks:update"`

## Bug Fix Process

When fixing a bug, always write a regression test FIRST that reproduces the issue and confirms it fails. Only then fix the bug and verify the test passes. This ensures the fix actually addresses the problem and prevents future regressions.

## Key Conventions

- Phoenix Context pattern: domain logic in `lib/agent_queue/`, web layer in `lib/agent_queue_web/`
- HEEx templates formatted via `Phoenix.LiveView.HTMLFormatter` plugin
- Test database uses Ecto SQL Sandbox for isolation; async-safe via `DataCase` and `ConnCase`
- Environment configs: dev.exs, test.exs, ci.exs, prod.exs; runtime env vars in runtime.exs
