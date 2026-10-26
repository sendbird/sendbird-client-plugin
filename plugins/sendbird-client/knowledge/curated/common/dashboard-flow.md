<!-- last-verified-against: n/a (conceptual) -->
<!-- status: populated -->
# common — dashboard flow

> Conceptual cross-platform guidance (no SDK API asserted). Verified 2026-06-10.

## Getting your IDs
- **Application ID** identifies your Sendbird application; required to initialize any SDK. From the Sendbird dashboard.

## Credentials handled by your server (not the dashboard)
- **Session/access tokens** are issued by your server via the Sendbird Platform API, not copied from the dashboard. Never hard-code them.
- Push credentials (APNs key/cert, FCM service account) are uploaded on the dashboard by following the official push setup guide for your platform — see cross-cutting/push.md.

## UIKit features turned on or off in the dashboard (UIKit config)
The dashboard can turn some UIKit features on or off without code, for example typing indicator, reactions, reply type, threads, voice messages, attachment types, read and delivery receipts, link preview, and message search. Setup starts under **Chat > Try UIKit for Chat**, and the dashboard shows a preview. Points that explain most "I changed it in the dashboard and nothing happened" questions:
- **Code wins.** The docs rank the sources as module call, then code, then dashboard value, then dashboard default, and say "even if you configure from the dashboard, it will be ignored" when the app already sets the value in code.
- **Not live.** "The UIKit config isn't applied in real-time"; it takes effect after the app connects again, so close and restart the app to check.
- **Some features also need the Chat feature on.** Message search, link preview (OG tag), and reactions depend on the application's Chat settings; if those are off, the UIKit config switch has no effect. Message search also needs its premium feature.
- **One config per application.** "Only one UIKit config is allowed per application."
- **Minimum versions:** iOS — Chat SDK 4.9.2, UIKit 3.6.0; Android — Chat SDK 4.8.2, UIKit 3.6.0; React — Chat SDK (JavaScript) 4.9.2, UIKit React 3.6.0; React Native — Chat SDK (JavaScript) 4.9.2, UIKit React Native 3.0.0.

(source: https://sendbird.com/docs/chat/uikit/v3/android-view/dashboard-configuration/uikit-config-in-dashboard — steps, real-time note, app attributes, priority ; https://sendbird.com/docs/chat/uikit/v3/react/dashboard-configuration/overview — priorities, feature table, premium note ; https://sendbird.com/docs/chat/uikit/v3/ios/dashboard-configuration/overview ; https://sendbird.com/docs/chat/uikit/v3/android-view/dashboard-configuration/overview ; https://sendbird.com/docs/chat/uikit/v3/react-native/dashboard-configuration/overview — requirements)

## Plugin behavior
- The plugin reads `app_id` from env (`SENDBIRD_APP_ID`) > userConfig > `.sendbird-client/profile.json` > asks. It never stores tokens.

## Related
- Push setup: per-platform cross-cutting/push.md
- Auth: per-platform products/auth.md
