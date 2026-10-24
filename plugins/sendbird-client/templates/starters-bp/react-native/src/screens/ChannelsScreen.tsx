// source: knowledge/curated/js/products/uikit.md ("React Native", "Channel list: custom item, filter, loading state")
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/domain/groupChannel/types.ts#L26-L31
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/components/ChannelInput/index.tsx#L102
// source: https://reactnative.dev/blog/2026/06/11/react-native-0.86 ("KeyboardAvoidingView works correctly on Android 15+ with edgeToEdgeEnabled")
import { type ComponentProps, useState } from 'react';
import { Button, KeyboardAvoidingView, Platform, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { createGroupChannelFragment, createGroupChannelListFragment } from '@sendbird/uikit-react-native';

// Fragment factories run once, outside any component.
const GroupChannelListFragment = createGroupChannelListFragment();
const GroupChannelFragment = createGroupChannelFragment();

type Channel = ComponentProps<typeof GroupChannelFragment>['channel'];

// UIKit's message input avoids the keyboard itself on iOS only; on Android it relies on the window
// resizing (adjustResize), which edge-to-edge (Android 15 and later) no longer does. Without this,
// the keyboard covers the input there.
const KEYBOARD_BEHAVIOR = Platform.OS === 'android' ? 'padding' : undefined;

/** The UIKit channel list; tapping a row opens the UIKit conversation screen. */
export function ChannelsScreen({ onBack }: { onBack: () => void }) {
  const [channel, setChannel] = useState<Channel | null>(null);

  if (channel) {
    // Keep the fragment the first thing on this screen. A bar or banner above it shifts the fragment
    // down, and on iOS the input then stays behind the keyboard unless that height is passed as
    // keyboardAvoidOffset (knowledge/curated/js/products/uikit.md "Keyboard covering the input").
    return (
      <KeyboardAvoidingView style={styles.screen} behavior={KEYBOARD_BEHAVIOR}>
        <GroupChannelFragment
          channel={channel}
          onChannelDeleted={() => setChannel(null)}
          onPressHeaderLeft={() => setChannel(null)}
          onPressHeaderRight={() => {
            // Open a channel settings screen here (createGroupChannelSettingsFragment).
          }}
        />
      </KeyboardAvoidingView>
    );
  }

  return (
    <SafeAreaView style={styles.screen}>
      <Button title="Home" onPress={onBack} />
      {/* BP17: the stable identifier for the channel list container */}
      <View style={styles.screen} testID="sb_channel_list">
        <GroupChannelListFragment
          onPressChannel={setChannel}
          onPressCreateChannel={() => {
            // Open a create-channel screen here (createGroupChannelCreateFragment).
          }}
        />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({ screen: { flex: 1 } });
