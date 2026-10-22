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
comment or in the `_README.md` next to it. Any reproduced material remains subject to the
license applicable to its source repository, as identified in the relevant file or
accompanying `_README.md`.

Troubleshooting entries link to the public Sendbird community forum and GitHub discussions
where a problem was reported. The entries themselves are written for this plugin.

## Code from MIT-licensed Sendbird repositories

Some code templates and knowledge files contain code from the following public Sendbird
repositories, which are licensed under the MIT License:

- `sendbird/sendbird-uikit-android` — Copyright (c) 2021 Sendbird
- `sendbird/sendbird-uikit-react` — Copyright (c) 2021 Sendbird
- `sendbird/sendbird-uikit-react-native` (packages `uikit-react-native`, `uikit-react-native-foundation`, `uikit-chat-hooks`, `uikit-utils`) — Copyright (c) 2021 Sendbird
- `sendbird/sendbird-uikit-sample-android-jetpack-compose` — Copyright (c) 2021 Sendbird
- `sendbird/quickstart-calls-directcall-android` — Copyright (c) 2019 SendBird
- `sendbird/quickstart-calls-directcall-ios` — Copyright (c) 2020 SendBird, Inc.

The MIT License for that code:

```text
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Third-party files

- **Gradle Wrapper** — `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, and
  `gradle/wrapper/gradle-wrapper.properties` in the Android starter apps
  (`templates/starters/android-view`, `templates/starters/android-compose`,
  `templates/starters-bp/android-view`, `templates/starters-bp/android-compose`).
  From Gradle 8.10.2 (https://gradle.org). Copyright 2015 the original author or authors.
  Licensed under the Apache License 2.0.
