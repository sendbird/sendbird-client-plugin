<!-- last-verified-against: n/a (conceptual) -->
<!-- status: populated -->
# common — dashboard flow

> Conceptual cross-platform guidance (no SDK API asserted). Verified 2026-06-10.

## Getting your IDs
- **Application ID** identifies your Sendbird application; required to initialize any SDK. From the Sendbird dashboard.

## Credentials handled by your server (not the dashboard)
- **Session/access tokens** are issued by your server via the Sendbird Platform API, not copied from the dashboard. Never hard-code them.
- Push credentials (APNs key/cert, FCM service account) are uploaded on the dashboard by following the official push setup guide for your platform — see cross-cutting/push.md.

## Plugin behavior
- The plugin reads `app_id` from env (`SENDBIRD_APP_ID`) > userConfig > `.sendbird-client/profile.json` > asks. It never stores tokens.

## Related
- Push setup: per-platform cross-cutting/push.md
- Auth: per-platform products/auth.md
