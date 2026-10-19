<!-- status: populated -->
# templates/js/react/calls

Sendbird Calls (1:1 voice and video) on the web (`sendbird-calls`). From the public README and the package's
`SendBirdCall.min.d.ts` 1.10.21 (verified 2026-10-17). **Type-checked** against the real package
(`tools/templates/compile-check-js.sh`, `tsc --noEmit` clean) and **run** between two browsers against a test
application with Calls turned on: sign-in, dial, ringing, accept, connected, and end.

## Files
- `setup.ts` — `initCalls()`, `authenticate(userId, accessToken?)` (also connects the WebSocket), `signOut()`,
  `listenForCalls(handlerId, onRinging)` (returns a cleanup), `dial(calleeId, isVideoCall, views)`,
  `accept(call, views)`, `end(call)`.
- `DirectCallPanel.tsx` — a call screen on top of `setup.ts`: a user ID field with "Voice call" and "Video call",
  "Accept" and "Decline" while ringing, "End" while dialing or connected, and the remote and local `<video>`
  elements. The status line reads `Call: idle | dialing | ringing | connecting | connected | ended`.

## How to splice
1. `npm install sendbird-calls` with the project's package manager. Keep the default import
   (`import SendBirdCall from 'sendbird-calls'`, needs `esModuleInterop: true`): the browser build exposes the API
   on the default export only.
2. `initCalls()` once at startup; then, in the app's sign-in code (`onLoginSucceeded`, after the Chat connect when
   the app uses Chat), `await authenticate(userId)`. In the sign-out code (`onLogout`), `signOut()`.
3. Render `<DirectCallPanel />` on the signed-in screen (or call `listenForCalls`, `dial`, `accept`, and `end`
   from your own screen). Keep a remote media element mounted for voice calls too; it plays the other side's audio.
4. Permissions: the browser asks for the microphone (and the camera for video) the first time a call starts.
   Pages must be served over HTTPS or from `localhost`.
5. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the
   customer to add a bundler; the access token is a secret.
   Hand-off (`manualSteps`) holds only the steps in `knowledge/curated/js/products/calls.md` "Manual steps" (App ID, a token server when the app uses tokens, push credentials). No Calls doc has a dashboard step that enables Calls, so never tell the customer to enable Calls.

## Notes (see knowledge/curated/js/products/calls.md, all cited)
- The web SDK receives calls only while its WebSocket is connected; there is no push-based incoming call on the web.
- The callee must have authenticated to Calls before the dial: a dial right after the callee signs in can fail
  with "The callee hasn't authenticated with SendBird Calls yet".
