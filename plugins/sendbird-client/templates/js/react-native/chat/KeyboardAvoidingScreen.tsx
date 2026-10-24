// source: https://reactnative.dev/docs/keyboardavoidingview (behavior, keyboardVerticalOffset)
// source: https://reactnative.dev/blog/2026/06/11/react-native-0.86 ("KeyboardAvoidingView works correctly on Android 15+ with edgeToEdgeEnabled")
// source: templates/starters-bp/react-native/src/screens/ChannelsScreen.tsx (the same rule for the UIKit conversation)
// The root of a Chat SDK screen whose message input sits at the bottom (the conversation, a thread). React Native
// does not move the input above the keyboard by itself: on iOS a plain View leaves the input behind it (2026-10-24: a
// Chat SDK demo's conversation screen did, so its Send button could not be reached), and on Android 15 and later an
// edge-to-edge window no longer resizes for the keyboard. This is React Native code only, no Sendbird API.
// Type-checked by tools/templates/compile-check-js.sh.
import type { ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, StyleSheet, type StyleProp, type ViewStyle } from 'react-native';

const rnVersion = Platform.constants.reactNativeVersion;

/**
 * 'padding' on iOS, and on Android from React Native 0.86 on (edge-to-edge keyboards are reported there; the plugin's
 * starters use 0.87). Older React Native on Android resizes the window instead (adjustResize), and padding on top of
 * that would lift the input twice, so it gets no behavior.
 */
export const conversationKeyboardBehavior: 'padding' | undefined =
  Platform.OS === 'ios' || rnVersion.major > 0 || rnVersion.minor >= 86 ? 'padding' : undefined;

export interface KeyboardAvoidingScreenProps {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  /**
   * Height of what is drawn above this view by something outside it, such as a navigator header
   * (`useHeaderHeight()` in React Navigation). 0 when this view is the whole screen and draws its own header inside.
   */
  topOffset?: number;
}

/** Use in place of the screen's root View: `<KeyboardAvoidingScreen style={styles.screen}>…</KeyboardAvoidingScreen>`. */
export function KeyboardAvoidingScreen({ children, style, topOffset = 0 }: KeyboardAvoidingScreenProps) {
  return (
    <KeyboardAvoidingView
      style={[styles.fill, style]}
      behavior={conversationKeyboardBehavior}
      keyboardVerticalOffset={topOffset}
    >
      {children}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({ fill: { flex: 1 } });
