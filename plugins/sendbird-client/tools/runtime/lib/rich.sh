# shellcheck shell=bash
# Rich conversation checks (run.sh --rich), shared by hosts/ios.sh and hosts/android.sh.
# Sourced after the host driver defines step(), peer(), and $out. The UI test drives the screen
# (a reaction on B's first message, an edit and a delete of A's own messages, an image attachment,
# and a message search); these functions check from user B's side what each action left on the server.
#
#   rich_texts <tag>           sets RT_TEXT_A1_EDITED, RT_TEXT_A2, RT_SEARCH (digits only, see the tag note)
#   rich_image <file>          writes a small PNG for the attachment step
#   rich_wait_a2 <url>         waits until the server has A's message to delete (the UI test deletes it after)
#   rich_wait_file <url>       waits until A's image upload is a file message (the UI test searches after)
#   rich_server <url> <b1> <a1>  records one server-* step per feature

rich_texts() {
  export RT_TEXT_A1_EDITED="edited by A $1" RT_TEXT_A2="delete me $1" RT_SEARCH="$1"
}

rich_image() {
  python3 -I - "$1" <<'PY'
import struct, sys, zlib
w = h = 160
rows = b"".join(b"\x00" + b"".join(bytes((x * 255 // w, y * 255 // h, 160)) for x in range(w)) for y in range(h))
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
}

rich_wait_a2() {
  if peer expect "$RT_USER_B" "$1" "$RT_USER_A" "$RT_TEXT_A2" 420 >/dev/null; then
    step server-delete-sent true "the server has A's \"$RT_TEXT_A2\" before A deletes it"
    return 0
  fi
  step server-delete-sent false "the server never had A's \"$RT_TEXT_A2\""
  return 1
}

rich_wait_file() {
  local r
  if r="$(peer expect-file "$RT_USER_B" "$1" "$RT_USER_A" 420)"; then
    step server-file-sent true "the server has A's file message $(jq -r '.message | "\(.name) (\(.type), \(.size) bytes)"' <<<"$r") while A is still on the conversation"
    return 0
  fi
  step server-file-sent false "no file message from A reached the server while A was on the conversation"
  return 1
}

rich_server() {
  local url="$1" b1="$2" a1="$3" a2_sent="${4:-0}" msgs found
  msgs="$(peer inspect "$RT_USER_B" "$url" 50)"
  printf '%s\n' "$msgs" > "$out/server-messages.json"
  jq -e '.ok' <<<"$msgs" >/dev/null || { step server-messages false "peer could not read the channel: $(jq -r '.error // "?"' <<<"$msgs")"; return; }

  found="$(jq -c --arg t "$b1" --arg a "$RT_USER_A" '[.messages[] | select((.message // "") | contains($t)) | .reactions[] | select(.userIds | index($a))]' <<<"$msgs")"
  if [ "$(jq length <<<"$found")" -gt 0 ]; then
    step server-reaction true "B's \"$b1\" has A's reaction $(jq -r 'map(.key) | join(", ")' <<<"$found")"
  else
    step server-reaction false "B's \"$b1\" has no reaction from A (reactions: $(jq -c --arg t "$b1" '[.messages[] | select((.message // "") | contains($t)) | .reactions[]]' <<<"$msgs"))"
  fi

  found="$(jq -c --arg t "$RT_TEXT_A1_EDITED" --arg a "$RT_USER_A" '[.messages[] | select(.sender == $a and ((.message // "") | contains($t)))]' <<<"$msgs")"
  if [ "$(jq length <<<"$found")" -gt 0 ]; then
    step server-edit true "A's message now reads \"$(jq -r '.[0].message' <<<"$found")\" (message $(jq -r '.[0].messageId' <<<"$found"), updatedAt $(jq -r '.[0].updatedAt' <<<"$found"))"
  elif jq -e --arg t "$a1" --arg a "$RT_USER_A" '[.messages[] | select(.sender == $a and ((.message // "") | contains($t)))] | length > 0' <<<"$msgs" >/dev/null; then
    step server-edit false "A's \"$a1\" is unchanged on the server"
  else
    step server-edit false "the server has neither A's \"$a1\" nor \"$RT_TEXT_A1_EDITED\""
  fi

  if jq -e --arg t "$RT_TEXT_A2" '[.messages[] | select((.message // "") | contains($t))] | length == 0' <<<"$msgs" >/dev/null; then
    if [ "$a2_sent" = 1 ]; then step server-delete true "A's \"$RT_TEXT_A2\" was on the server and is gone now"
    else step server-delete false "the server never had \"$RT_TEXT_A2\", so a delete cannot be shown"; fi
  else
    step server-delete false "A's \"$RT_TEXT_A2\" is still on the server"
  fi

  found="$(jq -c --arg a "$RT_USER_A" '[.messages[] | select(.sender == $a and .kind == "file")]' <<<"$msgs")"
  if [ "$(jq length <<<"$found")" -gt 0 ]; then
    step server-file true "A sent a file message: $(jq -r '.[0] | "\(.name) (\(.type), \(.size) bytes)"' <<<"$found")"
  else
    step server-file false "the server has no file message from A"
  fi

  found="$(peer search "$RT_USER_B" "$url" "$RT_SEARCH" 60)"
  printf '%s\n' "$found" > "$out/server-search.json"
  if jq -e '.ok' <<<"$found" >/dev/null; then
    step server-search true "the server's message search for \"$RT_SEARCH\" in the channel returns $(jq '.hits | length' <<<"$found") message(s)"
  else
    step server-search false "the server's message search for \"$RT_SEARCH\" returns nothing$(jq -r 'if .error then " (" + .error + ")" else "" end' <<<"$found")"
  fi
}
