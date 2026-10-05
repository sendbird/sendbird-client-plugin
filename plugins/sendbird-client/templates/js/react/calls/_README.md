<!-- status: populated -->
# templates/js/react/calls

Sendbird Calls (voice/video) on the web (`sendbird-calls`). From the public README
(verified 2026-06-09). **Type-checked** against the real package (v1.10.21, `tsc --noEmit` clean) —
init / authenticate / connectWebSocket / dial param shape.

## Files
- `setup.ts` — `initCalls()` / `authenticate(...)` / `dial(...)`.

## How to splice
1. `npm install sendbird-calls` (set `esModuleInterop: true`, or use `import * as SendBirdCall`).
2. `initCalls()`, then `authenticate(...)` (which calls `connectWebSocket()`).
3. Browser prompts for mic/camera on first call.
4. App ID from env — never hard-code; access token is a secret.

## Variations (see knowledge/curated/js/products/calls.md, all cited)
- Incoming calls: `SendBirdCall.addListener(id, { onRinging })`.
- Video: `dial(calleeId, true)`.
