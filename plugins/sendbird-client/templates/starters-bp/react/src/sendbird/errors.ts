// source: knowledge/curated/js/cross-cutting/errors.md ("Handling tips", "Connection failures")
// source: knowledge/curated/js/products/chat.md ("Call APIs only after connect completes")
//
// BP13: show the error code and choose the next step from the verified error table.
import { SendbirdErrorCode } from '@sendbird/chat';

export interface ErrorView {
  code?: number;
  text: string;
  /** true when the user has to sign in again (the token or the user is no longer valid) */
  signInAgain: boolean;
}

const SIGN_IN_AGAIN = new Set<number>([
  SendbirdErrorCode.USER_AUTH_DEACTIVATED, // 400300
  SendbirdErrorCode.USER_AUTH_DELETED_OR_NOT_FOUND, // 400301
  SendbirdErrorCode.SESSION_TOKEN_EXPIRED, // 400302
  SendbirdErrorCode.SESSION_REVOKED, // 400310
]);

export function describeError(error: unknown): ErrorView {
  const code = typeof (error as { code?: unknown })?.code === 'number' ? (error as { code: number }).code : undefined;
  const message = error instanceof Error ? error.message : String(error);
  if (code !== undefined && SIGN_IN_AGAIN.has(code)) {
    return { code, text: `Sign in again (${code}).`, signInAgain: true };
  }
  if (code === SendbirdErrorCode.CONNECTION_REQUIRED) {
    return { code, text: `Not connected yet (${code}). Try again once the status shows Connected.`, signInAgain: false };
  }
  if (code === SendbirdErrorCode.NETWORK_ERROR) {
    return { code, text: `Network problem (${code}). The SDK reconnects by itself.`, signInAgain: false };
  }
  return { code, text: code !== undefined ? `Error ${code}: ${message}` : message, signInAgain: false };
}
