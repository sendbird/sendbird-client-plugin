#!/usr/bin/env bash
# Render the public API surface of a customer-installed iOS SDK from its public
# `.swiftinterface`. Usage: read-swiftinterface.sh <file.swiftinterface> <title> [module]
#
# Plain bash + awk (no node, no Xcode) so it runs on any customer Mac. Rules:
#   - a declaration is kept only if it is `public`/`open`, or is a requirement of a public
#     protocol or a case of a public enum (those carry no access modifier);
#   - `internal`, `fileprivate`, `private`, `package`, `@usableFromInline`, `@_spi` and
#     `@available(*, unavailable)` declarations are dropped with everything inside them,
#     including when the attribute sits alone on the line above;
#   - function bodies (`@inlinable`) are dropped; accessor blocks become `{ get set }`;
#   - comments, imports and compiler-only attributes are removed;
#   - `#if` keeps its first branch only (an `#else` branch would duplicate declarations);
#   - members are grouped under their type, and extensions fold into the type they extend.
# A line grep for `public`/`open` at line start missed most of the interface
# (`@objc open func`, `final public class`): on SendbirdChatSDK 4.39.11 it kept 123 lines
# and no `GroupChannel` class.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/render.sh
source "$HERE/lib/render.sh"
f="${1:?usage: read-swiftinterface.sh <file.swiftinterface> <title> [module]}"; title="${2:?title}"
module="${3:-$(basename "$(dirname "$f")" .swiftmodule)}"
[ -f "$f" ] || { render_empty "$title" "no .swiftinterface at $f"; exit 0; }
case "$f" in
  *.private.swiftinterface|*.package.swiftinterface)
    render_empty "$title" "refusing a non-public interface ($f)"; exit 0 ;;
esac

err="$(mktemp)"; trap 'rm -f "$err"' EXIT
if ! body="$(awk -v MODULE="$module" -f "$HERE/lib/swiftinterface.awk" "$f" 2>"$err")"; then
  render_empty "$title" "could not parse $f ($(tail -1 "$err"))"
  exit 0
fi
render_header "$title" "$f"
echo "> Module: \`$module\`. Read from the public \`.swiftinterface\`; \`public\`/\`open\` declarations only, function bodies and compiler attributes removed."
echo
printf '%s\n' "$body"
