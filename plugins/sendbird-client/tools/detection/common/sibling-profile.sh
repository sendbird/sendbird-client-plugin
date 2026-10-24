# shellcheck shell=bash
# sibling_app_id <project-dir> <own state folder name> : prints the appId that another edition of this
# plugin stored in its own state folder in the project, or nothing. Each edition keeps its state in a
# hidden folder of the project named after it (config/plugin-config.json .stateDir: a dot, the plugin
# name, ending in "-client"), with a profile.json that detect.sh writes (it always has "platform").
# Folders are matched by that shape, not by name, so no edition names another. The value is printed for
# the caller to store; callers never echo it to the customer.
sibling_app_id() {
  local dir="$1" own="$2" p a
  for p in "$dir"/.*-client/profile.json; do
    [ -f "$p" ] || continue
    [ "$(basename "$(dirname "$p")")" = "$own" ] && continue
    jq -e 'type == "object" and has("platform")' "$p" >/dev/null 2>&1 || continue
    a="$(jq -r '.appId // empty | strings' "$p" 2>/dev/null)"
    case "$a" in ''|YOUR*|REPLACE*|'<'*) continue ;; esac
    printf '%s' "$a"
    return 0
  done
  return 0
}
