---
name: "Notifications"
about: "Get notified when the task queue finishes or tasks need attention"
title: "Notifications — alerts when queue finishes or tasks need review"
labels: enhancement
---

## Summary

Add a notification system to alert when the task execution queue finishes, when tasks fail, or when new tasks are proposed and ready for review.

## Motivation

Since the queue runs unattended, there's no way to know when it's done or if something failed without manually checking the dashboard. Notifications close this feedback loop.

## Proposed Approach

Implement a pluggable notification system with multiple backends:

### Notification Backends

1. **macOS native notifications** (via `terminal-notifier` or `osascript`)
   - Simplest to implement, works immediately on the home Mac
   - "Agent Queue: 5 tasks completed, 1 failed"

2. **Email notifications** (via SMTP or a service like Mailgun/SES)
   - Summary email after queue completion
   - Immediate alert on task failure

3. **Push notifications** (via Pushover, Ntfy, or similar)
   - Best for mobile — get notified on your phone
   - Pairs well with the mobile access feature

4. **Webhook** (generic HTTP POST)
   - Enables integration with Slack, Discord, or custom systems

### Notification Events

- Queue execution started
- Queue execution completed (with summary)
- Individual task failed
- New tasks discovered and ready for review
- Time budget exhausted (queue stopped early)

## Tasks

- [ ] Design notification behaviour/protocol in Elixir (pluggable backends)
- [ ] Implement macOS native notification backend
- [ ] Implement Ntfy/Pushover push notification backend
- [ ] Implement email notification backend
- [ ] Implement webhook notification backend
- [ ] Add notification preferences to config
- [ ] Add notification settings to LiveView dashboard
- [ ] Hook notification dispatching into Runner GenServer events

## Considerations

- Notifications should be non-blocking — failures to notify should not affect task execution
- Rate limiting — avoid spamming during large queue runs (batch into summaries)
- Config should support enabling multiple backends simultaneously
