import { useState } from 'react';
import { Button, SafeAreaView, StyleSheet, Text, TextInput } from 'react-native';
import { onLoginSucceeded } from '../auth/login';
import { SENDBIRD_APP_ID } from '../sendbird/config';

// Sign-in screen. Replace the user ID field with your own sign-in; call onLoginSucceeded(userId)
// once it succeeds.
export function LoginScreen({ notice }: { notice?: string }) {
  const [userId, setUserId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const appIdMissing = SENDBIRD_APP_ID === '';

  const submit = async () => {
    if (appIdMissing || userId.trim() === '') return;
    setError('');
    setBusy(true);
    try {
      await onLoginSucceeded(userId);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SafeAreaView style={styles.screen}>
      <Text style={styles.title}>Sign in</Text>
      {appIdMissing && (
        // BP02: a missing App ID is reported here instead of failing the build.
        <Text style={styles.alert} testID="sb_app_id_missing">
          No App ID configured. Set sendbirdAppId in app.json and rebuild.
        </Text>
      )}
      {notice ? <Text style={styles.alert}>{notice}</Text> : null}
      <TextInput
        testID="sb_login_user_id"
        style={styles.input}
        placeholder="User ID"
        autoCapitalize="none"
        autoCorrect={false}
        value={userId}
        onChangeText={setUserId}
        onSubmitEditing={submit}
      />
      <Button testID="sb_login_button" title="Sign in" onPress={submit} disabled={appIdMissing || busy || userId.trim() === ''} />
      {error ? <Text style={styles.alert}>{error}</Text> : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 24, gap: 12 },
  title: { fontSize: 24, fontWeight: '600' },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 6, padding: 10, fontSize: 16 },
  alert: { color: '#b42318' },
});
