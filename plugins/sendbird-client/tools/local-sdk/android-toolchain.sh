#!/usr/bin/env bash
# Find a JDK and an Android SDK for building the customer's Android project, so the agent can
# compile its changes instead of handing "build it yourself" to the customer.
#
# Usage: eval "$(bash android-toolchain.sh [project-dir])"
# Prints `export JAVA_HOME=...` and `export ANDROID_HOME=...` for what it finds (only for the
# build command; never write them into the project). Prints a `# missing:` comment for what it
# cannot find, so the hand-off can name exactly what is missing.
#
# Order, first match wins:
#   JDK  — $JAVA_HOME, `/usr/libexec/java_home -v 17` (macOS), Android Studio's bundled `jbr`,
#          Homebrew openjdk@17, then /usr/lib/jvm. AGP 8.x requires JDK 17, and Gradle run from a
#          terminal uses JAVA_HOME (https://developer.android.com/build/jdks).
#   SDK  — $ANDROID_HOME, $ANDROID_SDK_ROOT, `sdk.dir` in <project>/local.properties,
#          ~/Library/Android/sdk (https://developer.android.com/tools/variables), ~/Android/Sdk,
#          the Homebrew android-commandlinetools share folder, then /usr/lib/android-sdk.
set -uo pipefail
dir="${1:-.}"
# ANDROID_TOOLCHAIN_DEFAULTS=0 checks only the environment and local.properties (used by tests).
defaults="${ANDROID_TOOLCHAIN_DEFAULTS:-1}"

# A full JDK: Gradle needs javac, and read-aar.sh needs javap and jar.
jdk_ok() { [ -n "$1" ] && [ -x "$1/bin/javac" ] && [ -x "$1/bin/javap" ] && "$1/bin/java" -version >/dev/null 2>&1; }
sdk_ok() { [ -n "$1" ] && ls -d "$1"/platforms/android-* >/dev/null 2>&1; }

brew_prefix=""; [ "$defaults" = 1 ] && command -v brew >/dev/null && brew_prefix="$(brew --prefix 2>/dev/null)"

java_home=""
jdk_candidates=("${JAVA_HOME:-}")
[ "$defaults" = 1 ] && jdk_candidates+=(
         "$( [ -x /usr/libexec/java_home ] && /usr/libexec/java_home -v 17 2>/dev/null )" \
         "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
         "$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
         "${brew_prefix:+$brew_prefix/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}" \
         "${brew_prefix:+$brew_prefix/opt/openjdk@17}" \
         /opt/android-studio/jbr \
         /usr/lib/jvm/java-17-openjdk* /usr/lib/jvm/temurin-17* )
for c in "${jdk_candidates[@]}"; do
  if jdk_ok "$c"; then java_home="$c"; break; fi
done

sdk_dir=""
local_sdk=""
[ -f "$dir/local.properties" ] && local_sdk="$(sed -n 's/^sdk\.dir=//p' "$dir/local.properties" | tail -1)"
sdk_candidates=("${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$local_sdk")
[ "$defaults" = 1 ] && sdk_candidates+=(
         "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" \
         "${brew_prefix:+$brew_prefix/share/android-commandlinetools}" \
         /opt/homebrew/share/android-commandlinetools /usr/local/share/android-commandlinetools \
         /usr/lib/android-sdk )
for c in "${sdk_candidates[@]}"; do
  if sdk_ok "$c"; then sdk_dir="$c"; break; fi
done

q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
if [ -n "$java_home" ]; then echo "export JAVA_HOME=$(q "$java_home")"; echo 'export PATH="$JAVA_HOME/bin:$PATH"'
else echo "# missing: JDK 17 or newer (looked in JAVA_HOME, java_home -v 17, Android Studio jbr, Homebrew openjdk@17, /usr/lib/jvm)"; fi
if [ -n "$sdk_dir" ]; then echo "export ANDROID_HOME=$(q "$sdk_dir")"; echo 'export ANDROID_SDK_ROOT="$ANDROID_HOME"'
else echo "# missing: Android SDK (looked in ANDROID_HOME, ANDROID_SDK_ROOT, local.properties sdk.dir, ~/Library/Android/sdk, ~/Android/Sdk, Homebrew android-commandlinetools, /usr/lib/android-sdk)"; fi
