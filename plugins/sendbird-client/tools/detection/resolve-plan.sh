#!/usr/bin/env bash
# Resolve the customer's Sendbird plan for one project, and decide what to do with a plan-limited feature.
# Usage: resolve-plan.sh <project-dir>                     -> starter | pro | enterprise | unsure
#        resolve-plan.sh <project-dir> --check <feature-id> -> one JSON decision (see core/plans.json)
# Order: SENDBIRD_PLAN > .sendbird-client/profile.json plan > unsure (both read in any case; "free trial" is unsure).
# Decisions: ok (the plan includes it), confirm (ask the customer before building it),
# sales (Enterprise only, not built).
set -euo pipefail
dir="${1:?usage: resolve-plan.sh <project-dir> [--check <feature-id>]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/core/plans.json"

# The environment and the profile are read the same way: any case, spaces ignored,
# and a free trial counts as unsure (knowledge/curated/common/plans.md).
normalize() {
  local p
  p="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$p" in freetrial) p="unsure" ;; esac
  printf '%s' "$p"
}
plan=""
if [ -n "${SENDBIRD_PLAN:-}" ]; then
  plan="$(normalize "$SENDBIRD_PLAN")"
else
  profile="$dir/.sendbird-client/profile.json"
  [ -f "$profile" ] && plan="$(normalize "$(jq -r '.plan // empty' "$profile" 2>/dev/null || true)")"
fi
[ -n "$plan" ] || plan="unsure"
jq -e --arg p "$plan" '(.plans + [.unsure]) | index($p)' "$P" >/dev/null || {
  echo "unknown plan: $plan (expected one of: $(jq -r '(.plans + [.unsure]) | join(", ")' "$P"))" >&2
  exit 1
}

if [ "${2:-}" != "--check" ]; then
  printf '%s\n' "$plan"
  exit 0
fi
feature="${3:?usage: resolve-plan.sh <project-dir> --check <feature-id>}"
jq -e --arg f "$feature" '.features | map(.id) | index($f)' "$P" >/dev/null || {
  echo "unknown feature: $feature (see core/plans.json)" >&2
  exit 2
}

jq -c --arg plan "$plan" --arg f "$feature" '
  def cap: (.[0:1] | ascii_upcase) + .[1:];
  .salesUrl as $sales | .plans as $order |
  (.features[] | select(.id == $f)) as $x |
  ($order | index($plan)) as $have | ($order | index($x.minPlan)) as $need |
  (if $have != null and $need != null and $have >= $need then "ok"
   elif $x.minPlan == "enterprise" then "sales"
   else "confirm" end) as $decision |
  {
    feature: $x.id, label: $x.label, where: $x.where, plan: $plan, requiredPlan: $x.minPlan, decision: $decision,
    message: (
      if $decision == "ok" then null
      elif $decision == "sales" then "\($x.label) is available only on the Enterprise plan, so it is not added to the code. To get it, contact Sendbird sales: \($sales)"
      elif $plan == "unsure" then "\($x.label) works only on the \($x.minPlan | cap) plan or higher (the free trial includes it), and the plan for this project is not known. Add it anyway?"
      else "\($x.label) works only on the \($x.minPlan | cap) plan or higher, and this project is on the \($plan | cap) plan. Add it anyway? It will not work until the plan is changed in the Sendbird Dashboard."
      end)
  }' "$P"
