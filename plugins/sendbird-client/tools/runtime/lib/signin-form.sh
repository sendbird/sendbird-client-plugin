#!/usr/bin/env bash
# Prints 1 when an app has its own sign-in form, else 0. Usage: signin-form.sh ios|android|rn <source dir>
# (ios: the app's Sources/, android: app/src/main, rn: the React Native project root; its node_modules,
# ios/, and android/ are left out). The harness then signs in through that form, the way a user
# does, instead of calling onLoginSucceeded itself.
# A form is found by structure, not by its button's language: a source file with a text field that
# calls onLoginSucceeded, or the starters' sb_login_user_id. A text field with a "Sign in" / "Log in"
# label somewhere, then 로그인 / 시작, is the fallback. On screen the UI tests find the form the same
# way (hosts/ios/RTSignin.swift, hosts/android/RTSignin.kt; a React Native app runs on those too).
set -uo pipefail
opts=(-r)
case "${1:-}" in
  ios) field='UITextField|TextField\('; inc=(--include='*.swift'); labels='"(sign in|log in|login)"'; ko='"[^"]*(로그인|시작)[^"]*"' ;;
  android) field='EditText|TextField\('; inc=(--include='*.kt'); labels='"(sign in|log in|login)"|>(sign in|log in|login)<'; ko='"[^"]*(로그인|시작)[^"]*"|>[^<]*(로그인|시작)[^<]*<' ;;
  rn) field='<TextInput([[:space:]/>]|$)'; inc=(--include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js')
      opts=(-r --exclude-dir=node_modules --exclude-dir=ios --exclude-dir=android --exclude-dir=.git "${inc[@]}")
      labels='"(sign in|log in|login)"|>(sign in|log in|login)<'; ko='"[^"]*(로그인|시작)[^"]*"|>[^<]*(로그인|시작)[^<]*<' ;;
  *) echo "usage: signin-form.sh ios|android|rn <dir>" >&2; exit 64 ;;
esac
src="${2:-}"; [ -d "$src" ] || { echo 0; exit 0; }
if ! grep "${opts[@]}" -qE "$field" "$src"; then echo 0; exit 0; fi
# a call to onLoginSucceeded: a method call on iOS and Android (LoginService().onLoginSucceeded(...)),
# a function call in React Native (await onLoginSucceeded(userId)), never its own definition
calls() {
  if [ "$1" = rn ]; then xargs -0 grep -hE 'onLoginSucceeded\(' 2>/dev/null | grep -vE 'function[[:space:]]+onLoginSucceeded|onLoginSucceeded[[:space:]]*=' | grep -q .
  else xargs -0 grep -lE '[.]onLoginSucceeded\(' 2>/dev/null | grep -q .; fi
}
if grep "${opts[@]}" -lE --null "${inc[@]}" "$field" "$src" | calls "$1" \
  || grep "${opts[@]}" -qF 'sb_login_user_id' "$src" \
  || grep "${opts[@]}" -qiE "$labels" "$src" \
  || grep "${opts[@]}" -qE "$ko" "$src"; then echo 1; else echo 0; fi
