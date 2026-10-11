<!-- last-verified-against: n/a (conceptual host guidance) -->
<!-- status: populated -->
# android host — View

> Conceptual host guidance (no SDK API asserted). Verified 2026-06-10.

## Detection signals
- XML layouts (`res/layout`), `Activity`/`Fragment`, ViewBinding, `AppCompatActivity`, no Jetpack Compose dependency.

## Integration notes
- Sendbird UIKit / AI Agent are View/Fragment-based — the native fit. Enable `buildFeatures { viewBinding = true }`.
- `MessengerLauncher` / UIKit fragments need a `FragmentActivity` (see products/ai-agent.md, uikit.md).
- Init in `Application.onCreate`; add/remove channel handlers in the Activity/Fragment lifecycle (see cross-cutting/performance.md).
- Customizing UIKit screens (message views, input, channel list, header): see the "(View host)" sections in products/uikit.md; theme, fonts, and strings are in cross-cutting/theme.md.

## Related
- UIKit product: knowledge/curated/android/products/uikit.md
- Compose host: knowledge/curated/android/hosts/compose.md
