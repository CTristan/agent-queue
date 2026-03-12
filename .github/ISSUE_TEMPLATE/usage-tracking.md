---
name: "Usage Tracking"
about: "Track and visualize agent usage to optimize budget allocation"
title: "Usage tracking — monitor cumulative agent time and budget utilization"
labels: enhancement
---

## Summary

Track cumulative `pi` agent usage time across sessions and visualize it in the dashboard, enabling better budget allocation and usage optimization.

## Motivation

The current time budget is a rough proxy — it limits wall-clock time per execution session but doesn't track cumulative usage across days or correlate with actual `pi` platform limits. Better tracking would help:
- Understand how much of the 5-hour daily limit is actually being used
- Identify which projects consume the most agent time
- Optimize task prioritization based on estimated duration
- Avoid accidentally exceeding limits

## Proposed Approach

### Data Collection
- Track per-run duration (already stored in `runs` table)
- Aggregate daily/weekly/monthly usage from run data
- If `pi` ever exposes a usage API, integrate with it directly

### Dashboard Widgets
- **Daily usage meter:** visual gauge showing estimated usage vs. 5-hour limit
- **Usage over time:** chart showing daily/weekly agent time consumption
- **Per-project breakdown:** which projects use the most agent time
- **Task duration estimates:** learn from historical run data to estimate future task durations

### Smart Budgeting
- Auto-calculate remaining budget based on daily usage so far
- Warn before starting a queue run that would likely exceed the daily limit
- Suggest optimal time budgets based on historical patterns

## Tasks

- [ ] Create usage aggregation queries (daily, weekly, monthly rollups)
- [ ] Add usage dashboard LiveView with charts (consider `VegaLite` or `Contex`)
- [ ] Add per-project usage breakdown view
- [ ] Implement task duration estimation from historical data
- [ ] Add smart budget suggestions to the run trigger panel
- [ ] Add daily usage limit to config (default: 300 minutes)
- [ ] Add warning when estimated queue time exceeds remaining daily budget
- [ ] If/when available: integrate with `pi` usage API

## Considerations

- Duration tracking is already captured per-run; this feature is mostly about aggregation and visualization
- Task duration estimation will be inaccurate initially but should improve as historical data accumulates
- The 5-hour limit may reset at different times depending on the provider — make the reset time configurable
