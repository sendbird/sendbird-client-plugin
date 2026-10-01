<!-- last-verified-against: n/a (conceptual; no figures quoted) -->
<!-- status: populated -->
# common — pricing & quotas

> Conceptual only. Do NOT quote prices, MAU limits, or quota numbers — they change and are plan-dependent. Point customers to the official sources. Verified 2026-06-10.

## Where to check
- Pricing + plan limits: https://sendbird.com/pricing/chat (authoritative; figures change; /pricing without a product 404s — link-check verified 2026-06-10).
- Per-app quotas/usage: the Sendbird dashboard for the customer's application.

## What the plugin should do
- Never state a specific price, MAU cap, message/feature quota, or rate limit number from memory — these are not verifiable in code and change over time.
- If a customer hits a quota error at runtime (e.g. rate-limit / plan-quota error codes), explain the error category and direct them to the pricing page + dashboard rather than guessing limits. See per-platform cross-cutting/errors.md (e.g. rate-limit / plan-quota codes).

## Related
- Errors: per-platform cross-cutting/errors.md
