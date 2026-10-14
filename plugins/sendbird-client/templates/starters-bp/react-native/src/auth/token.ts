// source: knowledge/curated/js/products/auth.md ("Connect (session token)", "Pitfalls")
//
// BP03 / BP04: the one place that asks your server for a Sendbird session token. It returns no
// token, which works only with an application that allows connecting with a user ID alone.
// Replace the body with a call to your server. Tokens are secrets: never hard-code, log, or commit them.
export async function fetchSessionToken(userId: string): Promise<string | undefined> {
  void userId;
  return undefined;
}
