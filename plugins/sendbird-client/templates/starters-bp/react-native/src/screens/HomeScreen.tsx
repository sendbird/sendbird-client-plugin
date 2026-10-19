import { Button, StyleSheet, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { onLogout } from '../auth/login';
import type { SessionState } from '../auth/session';

/** Home screen after sign-in: who is signed in, the connection status, the channel list, sign-out. */
export function HomeScreen({ session, onOpenChannels }: { session: SessionState; onOpenChannels: () => void }) {
  if (session.status === 'signed-out') return null;
  const status =
    session.status === 'connecting'
      ? 'Connecting…'
      : session.connection === 'connected'
        ? 'Connected'
        : session.connection === 'reconnecting'
          ? 'Reconnecting…'
          : 'Offline';
  return (
    <SafeAreaView style={styles.screen}>
      <Text style={styles.user}>Signed in as {session.userId}</Text>
      <Text style={styles.status} testID="sb_connection_status">
        {status}
      </Text>
      {/* BP06: nothing that calls the server before connect returns */}
      {session.status === 'signed-in' && <Button testID="sb_open_channels" title="Channels" onPress={onOpenChannels} />}
      <Button testID="sb_logout_button" title="Sign out" onPress={() => void onLogout()} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 24, gap: 12 },
  user: { fontSize: 18 },
  status: { color: '#555' },
});
