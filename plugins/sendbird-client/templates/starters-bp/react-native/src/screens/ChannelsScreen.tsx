// source: knowledge/curated/js/products/uikit.md ("React Native", "Channel list: custom item, filter, loading state")
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/domain/groupChannel/types.ts#L26-L31
import { type ComponentProps, useState } from 'react';
import { Button, SafeAreaView, StyleSheet, View } from 'react-native';
import { createGroupChannelFragment, createGroupChannelListFragment } from '@sendbird/uikit-react-native';

// Fragment factories run once, outside any component.
const GroupChannelListFragment = createGroupChannelListFragment();
const GroupChannelFragment = createGroupChannelFragment();

type Channel = ComponentProps<typeof GroupChannelFragment>['channel'];

/** The UIKit channel list; tapping a row opens the UIKit conversation screen. */
export function ChannelsScreen({ onBack }: { onBack: () => void }) {
  const [channel, setChannel] = useState<Channel | null>(null);

  if (channel) {
    return (
      <GroupChannelFragment
        channel={channel}
        onChannelDeleted={() => setChannel(null)}
        onPressHeaderLeft={() => setChannel(null)}
        onPressHeaderRight={() => {
          // Open a channel settings screen here (createGroupChannelSettingsFragment).
        }}
      />
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
