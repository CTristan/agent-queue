---
name: "Parallel Task Execution"
about: "Run multiple coding agents concurrently to process the queue faster"
title: "Parallel task execution — run multiple agents concurrently"
labels: enhancement
---

## Summary

Enable running multiple `pi` agent sessions in parallel to process the task queue faster, leveraging OTP's natural concurrency model.

## Motivation

The MVP processes tasks sequentially, but with a 5-hour usage window and tasks that vary in duration, parallel execution could significantly increase throughput — especially for tasks across different projects that have no dependencies on each other.

## Proposed Approach

- **Configurable concurrency:** `--parallel <n>` flag on `mix aq.run` to set max concurrent tasks (default: 1 for backward compatibility)
- **Worker pool:** Spawn `n` Runner worker GenServers under a DynamicSupervisor
- **Task assignment:** Workers pull from the approved queue by priority; each worker locks a task (status → `running`) before starting
- **Per-project locking:** Only one task per project can run at a time (agents shouldn't conflict on the same repo)
- **Budget splitting:** Time budget applies to wall-clock time, not cumulative agent time

## Architecture

```
AgentQueue.RunnerSupervisor (DynamicSupervisor)
├── AgentQueue.Runner.Worker (task 1, project A)
├── AgentQueue.Runner.Worker (task 2, project B)
└── AgentQueue.Runner.Worker (task 3, project C)
```

## Tasks

- [ ] Refactor Runner from single GenServer to DynamicSupervisor + Worker pattern
- [ ] Add database-level task locking (SELECT ... FOR UPDATE or advisory locks)
- [ ] Add per-project concurrency limit (max 1 task per project)
- [ ] Add `--parallel <n>` flag to `mix aq.run`
- [ ] Update LiveView dashboard to show multiple running tasks
- [ ] Update PubSub broadcasts for multi-worker status updates
- [ ] Add concurrency setting to config

## Considerations

- **Usage limits:** Multiple concurrent `pi` sessions may count against the same usage limit — need to test whether parallel execution actually helps or just burns the budget faster
- **Resource usage:** Each `pi` session consumes CPU/memory; limit concurrency to avoid overloading the home Mac
- **Git conflicts:** Per-project locking prevents two agents from modifying the same repo, but be aware of shared dependencies
- **Budget accounting:** With parallel execution, wall-clock budget and cumulative agent-time budget are different — decide which to enforce
