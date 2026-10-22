<!-- last-verified-against: https://sendbird.com/pricing/chat (Compare features table), 2026-10-15 -->
<!-- status: populated -->
# common — features that depend on the Sendbird plan

Some Chat features work only on higher plans. The plugin builds what the customer's plan includes, and asks before it adds a feature the plan does not include. Plan names and which plan includes a feature come from the pricing page's comparison table; prices and quota numbers are not quoted (see `knowledge/curated/common/pricing-quotas.md`). Verified 2026-10-15.

## Where the plan comes from

`bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-plan.sh" <project-dir>` prints the plan: `SENDBIRD_PLAN` first, then `plan` in `.sendbird-client/profile.json`, otherwise `unsure`. The plan is one of `starter`, `pro`, `enterprise`, or `unsure` (a free trial, a plan not decided yet, or one the customer did not give). Both sources are read in any case with spaces ignored, and `free trial` reads as `unsure`.

- New app: setup asks the `plan` question in `core/catalog.json` and saves the answer as `plan` in the profile.
- Existing project: when the plan is `unsure` and the customer names their plan, save it the same way so it is asked only once.
- The free trial includes every Pro feature ("All pro features" on the pricing page), but the plan the app moves to afterwards decides what keeps working, so a free trial counts as `unsure`.

## Before adding a feature

When a request needs a feature listed in `core/plans.json`, run `resolve-plan.sh <project-dir> --check <feature-id>` before writing any file (in new-app setup, before the starter is copied) and follow `decision`:

| `decision` | What to do |
| --- | --- |
| `ok` | The plan includes it. Build it as asked. For `where: "dashboard"`, it is turned on in the Sendbird Dashboard, not in code; say so. |
| `confirm` | Show `message` and wait for the customer's answer. Interactive: AskUserQuestion with "Add it" and "Leave it out". Non-interactive (`SENDBIRD_NONINTERACTIVE`): the caller answers with `confirm-<feature-id>=yes` (build it) or `confirm-<feature-id>=no` (leave it out). Without that answer, the run changes nothing at all, so check before writing any file, and ends with `status: "needs_input"` and one question per such feature, with id `confirm-<feature-id>` and options `yes` and `no` (a `needs_input` run summary lists no changes). If the customer says yes, build it and list it in the run summary's manual steps as needing the plan named in `requiredPlan`. |
| `sales` | Enterprise only. Do not write code for it. Show `message`. |

Translate `message` into the customer's language; keep plan and feature names as written.

Do not add a plan-limited feature the customer did not ask for, for example by choosing a Supergroup channel or adding message search on your own. A customer request that only works with such a feature counts as asking for it: check it first.

## Plan-limited features

From the pricing page's comparison table (Free trial, Starter, Pro, Enterprise). Every other Chat feature in that table is on every plan.

| Feature (pricing-page name) | Lowest plan | Where it lives | Where the plugin's guidance names it |
| --- | --- | --- | --- |
| Supergroup channel | Pro | app code | the `isSuper` channel property (source: knowledge/curated/js/products/chat.md) (source: knowledge/curated/android/cross-cutting/troubleshooting.md) |
| Delivery receipts | Pro | app code | `SendbirdChat.markAsDelivered` for members who are offline (source: knowledge/curated/ios/cross-cutting/push.md) |
| Message search | Pro | app code | `SendbirdChat.createMessageSearchQuery` (source: knowledge/curated/ios/products/chat.md) (source: knowledge/curated/android/products/chat.md) (source: knowledge/curated/js/products/chat.md) |
| Auto message translation | Pro | app code | — |
| On-demand translation | Pro | app code | — |
| Push translation | Pro | Dashboard | — |
| Announcements | Pro | server (Platform API) | — |
| AI image moderation | Pro | Dashboard | A blocked file fails to send with 900066 (source: knowledge/curated/ios/cross-cutting/errors.md) |
| Profanity filter | Pro | Dashboard | A blocked message fails to send with 900060 (source: knowledge/curated/ios/cross-cutting/errors.md) (source: knowledge/curated/android/cross-cutting/errors.md) |
| Advanced analytics | Pro | server (Platform API) | — |
| Moderation rule engine, Moderation ticket system, Moderation logs, Hive moderation | Enterprise | Dashboard | — |
| Message retention beyond the 6 months listed for Starter and Pro | Enterprise ("Request a quote") | server | — |

Data export is a Sendbird Dashboard feature, outside what this plugin builds: point the customer to the Dashboard.

A "—" means this plugin's curated guidance does not name an SDK entry point for it yet: verify one before writing code, as for any other API.

Handling 900060 or 900066 in app code (showing the customer why a message or file was not sent) needs no plan check. Turning the filter itself on is a Dashboard setting on Pro or higher.

## Sales

Enterprise features: https://sendbird.com/contact-sales (the "Contact sales" link on the pricing page).

(source: https://sendbird.com/pricing/chat — Compare features table columns Free trial, Starter, Pro, Enterprise; the Free trial card's "All pro features"; the FAQ answer on the Developer plan; read 2026-10-15)
