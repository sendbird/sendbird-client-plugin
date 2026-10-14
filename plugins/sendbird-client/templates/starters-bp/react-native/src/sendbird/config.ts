// source: knowledge/curated/js/setup.md ("App ID": the `config` row, no env loader)
//
// BP02: the App ID comes from the app's configuration file (app.json `sendbirdAppId`), not from a
// literal in code and not from an env loader the project does not have. Metro bundles it at build
// time. An empty value is reported on the sign-in screen instead of failing the build.
import appConfig from '../../app.json';

export const SENDBIRD_APP_ID: string = (appConfig.sendbirdAppId ?? '').trim();
