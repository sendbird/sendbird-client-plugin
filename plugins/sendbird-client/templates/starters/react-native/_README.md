<!-- status: populated -->
# React Native starter

A blank React Native 0.87.1 app (TypeScript) with its `ios/` and `android/` native projects, so a
new app made from it runs on the iOS Simulator and the Android Emulator. It has no Sendbird code:
the setup skill adds the SDK and connects in `src/auth/login.ts` (`onLoginSucceeded`, `onLogout`).

## Where the native projects come from

`ios/` and `android/` are the React Native Community CLI template, made with the command from the
React Native docs ("Get Started Without a Framework", https://reactnative.dev/docs/getting-started-without-a-framework):

```bash
npx @react-native-community/cli@20.2.0 init StarterReactNative --version 0.87.1
```

Changes to the generated files:

- `android/app/debug.keystore` is not shipped. `android/app/build.gradle` has no `signingConfigs`
  block, so debug builds use the Android Gradle plugin's default debug key
  (`~/.android/debug.keystore`). Make your own release key before you publish
  (https://reactnative.dev/docs/signed-apk-android).
- iOS uses the scene life cycle: an app built with the iOS 27 SDK and no scene delegate stops at
  launch on an iOS 27 simulator. `ios/StarterReactNative/SceneDelegate.swift` starts React Native
  in the scene's window, `AppDelegate.swift` only returns `true`, and `Info.plist` names the scene
  delegate under `UIApplicationSceneManifest`. The React Native 0.88 template is laid out the same
  way; this file uses only calls that 0.87.1 has. `AppDelegate.swift` still declares a `window`
  property (left nil): some native modules read the app delegate's window at launch, and React
  Native Firebase Messaging 19.3.0 stops the app there without it.
- One comment in `android/gradle.properties` is reworded.

The JavaScript side (`App.tsx`, `index.js`, `package.json`) is this starter's own. The app is
registered as `StarterReactNative`, the name both native projects start. The entry stays
`index.js`: release builds bundle `index.js` unless told otherwise (the iOS bundle script and the
React Native Gradle plugin both default to it).

To move to another React Native version, make the native projects again with that version's
command and keep these changes.

## Run

Needs Node 22.11 or later, the latest Xcode with an iOS Simulator runtime and CocoaPods for iOS,
and JDK 17 (the version the React Native docs recommend) with the Android SDK for Android
(https://reactnative.dev/docs/set-up-your-environment).

```bash
npm install
cd ios && pod install && cd ..   # iOS only; again after adding a package with native code
npm start                        # Metro, in its own terminal
npm run ios                      # or: npm run android
```

`ios/Podfile` is React Native's own CocoaPods setup for its iOS dependencies.
