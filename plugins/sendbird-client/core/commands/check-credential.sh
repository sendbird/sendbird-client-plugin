#!/usr/bin/env bash
# Pure command (core-lite): does the given text contain a credential literal?
# Reads text on stdin, never touches any file. Report-only — the caller
# decides what to do with the result (the plugin's credential-guard hook
# turns a hit into a PreToolUse deny).
#
# References to environment variables (process.env.X, System.getenv(...),
# os.environ[...], $VAR / ${VAR}) are stripped before matching, so reading a
# secret from the environment is never flagged. A credential assignment only
# counts when the value itself is a 20+ character literal.
#
# Usage: printf '%s' "$text" | check-credential.sh
# Output shape: see core/schemas/credential-check-result.schema.json
set -uo pipefail
body="$(cat)"

scan_body="$(printf '%s' "$body" | sed -E \
  -e 's/process\.env\.[A-Za-z_][A-Za-z0-9_]*//g' \
  -e 's/System\.getenv\([^)]*\)//g' \
  -e 's/os\.environ\[[^]]*\]//g' \
  -e 's/\$\{?[A-Za-z_][A-Za-z0-9_]*\}?//g')"

hit=""
printf '%s' "$scan_body" | grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' && hit="private key"
printf '%s' "$scan_body" | grep -Eq -- '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}' && hit="${hit:+$hit, }JWT"
credential_re="(password|passwd|secret|api[_-]?token|access[_-]?token)[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_./+=-]{20,}"
printf '%s' "$scan_body" | grep -Eqi -- "$credential_re" && hit="${hit:+$hit, }credential literal"

if [ -z "$hit" ]; then
  jq -n '{hit: null}'
else
  jq -n --arg h "$hit" '{hit: $h}'
fi
