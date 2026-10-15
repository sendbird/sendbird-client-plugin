# NOTICE

This plugin is licensed under the Apache License 2.0 (see `LICENSE`). That license covers the
plugin's own files only.

## Sendbird SDKs

The plugin explains Sendbird SDKs and adds them to your project through your package manager.
It does not include or redistribute SDK binaries or SDK source code. Each Sendbird SDK comes
with its own license, and that license governs your use of the SDK; the Apache License 2.0 of
this plugin does not apply to the SDKs.

When the plugin reads an SDK you installed, it reads it on your machine and keeps the result in
your project's cache folder; nothing is uploaded.

## Knowledge files and code templates

The knowledge files and code templates are based on public Sendbird documentation
(sendbird.com/docs) and public Sendbird repositories on GitHub. Each curated knowledge file
names the public sources it was verified against and the SDK version it matches.

Some code templates reproduce short code examples from the READMEs, quickstarts, and sample
apps in those public Sendbird repositories. Each of these templates names its source in a
comment or in the `_README.md` next to it.

Troubleshooting entries link to the public Sendbird community forum and GitHub discussions
where a problem was reported. The entries themselves are written for this plugin.

## Third-party files

- **Gradle Wrapper** — `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, and
  `gradle/wrapper/gradle-wrapper.properties` in the Android starter apps
  (`templates/starters/android-view`, `templates/starters/android-compose`,
  `templates/starters-bp/android-view`, `templates/starters-bp/android-compose`).
  From Gradle 8.10.2 (https://gradle.org). Copyright 2015 the original author or authors.
  Licensed under the Apache License 2.0.
