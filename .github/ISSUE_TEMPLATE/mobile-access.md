---
name: "Mobile Access"
about: "Enable reviewing and managing the task queue from a mobile phone"
title: "Mobile access — review and manage queue from phone"
labels: enhancement
---

## Summary

Expose the Phoenix LiveView dashboard for access from a mobile phone on the home network (or remotely via Tailscale/WireGuard), enabling task review and queue management on the go.

## Motivation

The morning review workflow would benefit from being accessible on a phone — quickly approve/reject tasks, check status, or trigger a run without needing to sit at the computer.

## Proposed Approach

- **Local network access:** Bind Phoenix to `0.0.0.0` instead of `127.0.0.1` so it's accessible from other devices on the home network
- **Remote access (optional):** Set up Tailscale or WireGuard for secure access from outside the home network
- **Responsive design:** Ensure the LiveView dashboard is fully usable on small screens
  - Touch-friendly approve/reject buttons
  - Swipe gestures for task actions
  - Collapsible task details
  - Mobile-optimized drag-and-drop (or alternative reordering UI)
- **Authentication:** Once exposed beyond localhost, add basic auth or token-based authentication

## Tasks

- [ ] Configure Phoenix endpoint to bind to `0.0.0.0` (with env variable toggle)
- [ ] Audit and improve responsive CSS for all LiveView pages
- [ ] Add touch-friendly interactions for task management
- [ ] Add basic authentication (bearer token or simple password)
- [ ] Document Tailscale setup for remote access
- [ ] Test on iOS Safari and Android Chrome

## Considerations

- Security: exposing the dashboard beyond localhost requires authentication
- LiveView WebSocket connections should work fine over Tailscale but may need keepalive tuning for mobile networks
