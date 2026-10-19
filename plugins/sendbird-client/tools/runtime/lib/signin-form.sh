#!/usr/bin/env bash
# Prints 1 when an app has its own sign-in form, else 0. Usage: signin-form.sh ios|android <source dir>
# (ios: the app's Sources/, android: app/src/main). The harness then signs in through that form, the
# way a user does, instead of calling onLoginSucceeded itself.
# A form is found by structure, not by its button's language: a source file with a text field that
# calls onLoginSucceeded, or the starters' sb_login_user_id. A text field with a "Sign in" / "Log in"
# label somewhere, then 로그인 / 시작, is the fallback. On screen the UI tests find the form the same
# way (hosts/ios/RTSignin.swift, hosts/android/RTSignin.kt).
set -uo pipefail
case "${1:-}" in
  ios) field='UITextField|TextField\('; ext='*.swift'; labels='"(sign in|log in|login)"'; ko='"[^"]*(로그인|시작)[^"]*"' ;;
  android) field='EditText|TextField\('; ext='*.kt'; labels='"(sign in|log in|login)"|>(sign in|log in|login)<'; ko='"[^"]*(로그인|시작)[^"]*"|>[^<]*(로그인|시작)[^<]*<' ;;
  *) echo "usage: signin-form.sh ios|android <dir>" >&2; exit 64 ;;
esac
src="${2:-}"; [ -d "$src" ] || { echo 0; exit 0; }
if ! grep -rqE "$field" "$src"; then echo 0; exit 0; fi
if grep -rlE --null --include="$ext" "$field" "$src" | xargs -0 grep -lE '[.]onLoginSucceeded\(' 2>/dev/null | grep -q . \
  || grep -rqF 'sb_login_user_id' "$src" \
  || grep -rqiE "$labels" "$src" \
  || grep -rqE "$ko" "$src"; then echo 1; else echo 0; fi
