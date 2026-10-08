// The app's own sign-in. Sendbird connects here after your sign-in succeeds,
// and disconnects in onLogout.
export async function onLoginSucceeded(userId: string): Promise<void> {
  void userId;
}

export async function onLogout(): Promise<void> {}
