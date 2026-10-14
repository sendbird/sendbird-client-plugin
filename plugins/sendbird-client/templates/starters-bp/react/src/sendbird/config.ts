// source: knowledge/curated/js/setup.md ("App ID", vite row)
//
// BP02: the App ID comes from build configuration. Vite inlines VITE_* values at build time, so put
// VITE_SENDBIRD_APP_ID in .env.local (see .env.example) and rebuild after changing it. An empty value
// is reported on the sign-in screen instead of failing the build.
export const SENDBIRD_APP_ID: string = (import.meta.env.VITE_SENDBIRD_APP_ID ?? '').trim();
