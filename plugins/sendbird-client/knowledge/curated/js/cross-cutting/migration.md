<!-- last-verified-against: @sendbird/chat 4.22.13 / @sendbird/uikit-react 3.19.1 / @sendbird/uikit-react-native 3.12.9 (new names); public migration guides fetched 2026-10-16 -->
<!-- verified-at: 2026-10-16 -->
<!-- verification-method: docs-page + sdk-surface -->
<!-- status: populated -->
# js — major version migration

> Moving an app from Chat SDK v3 to v4, and UIKit from v2 to v3 on React and React Native. Every old and new name below is taken from Sendbird's public migration guides (cited per section), verified 2026-10-16. Each new name was also found in the type declarations of @sendbird/chat 4.22.13, @sendbird/uikit-react 3.19.1, or @sendbird/uikit-react-native 3.12.9. Where a guide table contradicts itself, this page says so instead of copying it. The guides hold the full lists; this page keeps the parts an agent needs first.

## Which guide applies

| Customer is on | Move to | Public guide |
|---|---|---|
| Chat SDK v3 (npm `sendbird`, `new SendBird({ appId })`) | Chat SDK v4 (`@sendbird/chat`) | https://sendbird.com/docs/chat/sdk/v4/javascript/migration-guide/migration-guide |
| React UIKit v2 (npm `sendbird-uikit`) | React UIKit v3 (`@sendbird/uikit-react`) | https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/version-migration-guide |
| React UIKit v3 before 3.12.0 (`Channel`, `ChannelList`) | `GroupChannel`, `GroupChannelList` | https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/group-channel-migration-guide |
| React Native UIKit v2 | React Native UIKit v3 (`@sendbird/uikit-react-native`) | https://sendbird.com/docs/chat/uikit/v3/react-native/miscellaneous/migration-guide |
| v3 code built on low-level channel and message calls | group channel and message collections (optional, recommended by the guide) | https://sendbird.com/docs/chat/sdk/v4/javascript/migration-guide/collection-migration-guide |

React Native apps use the same Chat SDK package, `@sendbird/chat` (knowledge/curated/js/setup.md). The docs index (`core/docs-index.json`) has no separate React Native Chat SDK migration guide, so use the JavaScript one. It has no major-version migration guide for Calls, Desk, Live, or AI Agent on JavaScript (checked 2026-10-16); for those, say that no public migration guide exists and work from the product's current docs.

## Order of work

1. Chat SDK first. The React UIKit guide says UIKit v3 depends on Chat SDK v4 and that the Chat SDK must be updated before UIKit. (source: https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/version-migration-guide)
2. Replace the packages with the project's own package manager: `sendbird` becomes `@sendbird/chat`, and on the web `sendbird-uikit` becomes `@sendbird/uikit-react`. Keep the install free of `--legacy-peer-deps` and `--force` (docs/AGENT_CONTRACT.md section 3).
3. Follow the Chat guide's steps 1 to 5 (below). The guide warns the app will likely not compile until every step is done.
4. Then UIKit v2 to v3.

## Chat SDK v3 to v4

### Steps from the guide

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/migration-guide/migration-guide)

| Step | Change |
|---|---|
| 1 | Replace the v3 import with the v4 modules. `SendbirdChat` and shared classes come from `@sendbird/chat`; group channels from `@sendbird/chat/groupChannel` (`GroupChannelModule`); open channels from `@sendbird/chat/openChannel` (`OpenChannelModule`). The guide also names a message module; @sendbird/chat 4.22.13 exports it as `@sendbird/chat/message` (package.json `exports`). |
| 2 | Replace `new SendBird({ appId: APP_ID })` with `SendbirdChat.init({ appId: APP_ID, modules: [new GroupChannelModule(), new OpenChannelModule()] })`. Include only the modules the app uses; the guide suggests both while migrating and removing the unused one before production. Use a lowercase "b" in every Sendbird name. Initialize before any other SDK call. |
| 3 | Replace callbacks with promises (`async`/`await` or `.then`/`.catch`). Sending a message returns a handler with `onPending`, `onSucceeded`, and `onFailed`. Versions before v3.1.0 used raw arguments and older callback patterns, so expect more work there. |
| 4 | Pass query and message params as plain objects instead of building `new sb.UserMessageParams()` and setting fields, for example `createMyGroupChannelListQuery({ limit: 50, ... })` and `channel.sendUserMessage({ message })`. |
| 5 | Split the single `ChannelHandler` into `GroupChannelHandler` (register with `sb.groupChannel.addGroupChannelHandler`) and `OpenChannelHandler` (`sb.openChannel.addOpenChannelHandler`). |

Current init, connect, and send code: knowledge/curated/js/products/chat.md.

### Renamed and changed names

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/migration-guide/migration-guide) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

| v3 | v4 |
|---|---|
| `SendBird` | `SendbirdChat` |
| `SendbirdException` | `SendbirdError` |
| `UserMessageParams`, `FileMessageParams`, `GroupChannelParams`, `OpenChannelParams` | create and update params, for example `UserMessageCreateParams` and `UserMessageUpdateParams`; every `...Params` is now an interface (a plain object) |
| `isUserMessage`, `isFileMessage`, `isAdminMessage` (getters) | `isUserMessage()`, `isFileMessage()`, `isAdminMessage()` |
| `isGroupChannel`, `isOpenChannel` (getters) | `isGroupChannel()`, `isOpenChannel()` (the guide's table prints `isGroupChannel()` twice) |
| `getUnreadItemCount()`, `getTotalUnreadChannelCount()`, `getTotalUnreadMessageCount()` on the main object | the same methods on `sb.groupChannel`; `getUnreadItemCount` takes `UnreadItemCountParams` and `getTotalUnreadMessageCount` takes `TotalUnreadMessageCountParams` |
| `updateCurrentUserInfoWithProfileImage(...)`, `updateCurrentUserInfo(nickname, profileUrl)` | `updateCurrentUserInfo(UserUpdateParams)` |
| `onReadReceiptUpdated` | `onUnreadMemberStatusUpdated` |
| `onDeliveryReceiptUpdated` | `onUndeliveredMemberStatusUpdated` |
| `useMemberAsMessageSender` | `useMemberInfoInMessage` |
| `clearCache()` | `clearCachedData()` |
| `requestedMentionUserIds` | `mentionedUserIds` |
| `MemberStateFilter` in group channel list, count, and filter params | `MyMemberStateFilter` |
| `groupChannel.cachedReadReceiptStatus` | `groupChannel.cachedUnreadMemberState` |
| `groupChannel.cachedDeliveryReceiptStatus` | `groupChannel.cachedUndeliveredMemberState` |
| `userIdsExactFilter`, `userIdsIncludeFilter`, `userIdsIncludeFilterQueryType` on the channel list params | one `userIdsFilter` object with `userIds`, `includeMode` (`false` for exact, `true` for include), and `queryType` |

Other changes the guide lists:

- `ConnectionHandler` gains `onConnected` and `onDisconnected`.
- You can no longer create your own Sendbird instance.
- `SendbirdChat.instance`, `sb.appId`, `sb.connectionState`, `sb.lastConnectedAt`, `sb.options.useMemberInfoInMessage`, `channel.cachedMetaData`, and `message.isResendable` are read-only.
- Removed: `MessageCollectionInitPolicy.API_ONLY`, `ConnectionManager` (deprecated in v3), and `channel.getMessageByID()`. Internet Explorer is no longer supported.
- The guide recommends local caching over SyncManager.

## React UIKit v2 to v3

v2's smart components became modules, each with a provider, UI components, and a context hook. (source: https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/version-migration-guide)

### Package and top-level names

(source: https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/version-migration-guide)

| v2 | v3 |
|---|---|
| package `sendbird-uikit` | `@sendbird/uikit-react` |
| `sendbird-uikit/dist/index.css` | `@sendbird/uikit-react/dist/index.css` |
| `SendBirdProvider` | `SendbirdProvider` |
| `sendBirdSelectors` from `sendbird-uikit` | default import `sendbirdSelectors` from `@sendbird/uikit-react/sendbirdSelectors` |
| `withSendBird()` | `withSendbird()` |
| `import { ChannelList } from 'sendbird-uikit'` and the other smart components | import each module from its own path, for example `@sendbird/uikit-react/GroupChannelList`, `@sendbird/uikit-react/ChannelSettings`, or `@sendbird/uikit-react/OpenChannel` |

### Selectors

The selectors now take a channel object instead of a channel URL, and each group and open channel pair is merged into one selector. `getSendUserMessage` and `getSendFileMessage` return a handler with `onPending`, `onFailed`, and `onSucceeded` instead of a promise. Renamed: `getCreateChannel` to `getCreateGroupChannel`, `getEnterChannel` to `getEnterOpenChannel`, `getExitChannel` to `getExitOpenChannel`. Added: `getGetGroupChannel` and `getGetOpenChannel`. (source: https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/version-migration-guide)

### Props

(source: https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/version-migration-guide)

| v2 | v3 |
|---|---|
| `useReaction` | `isReactionEnabled` |
| `useMessageGrouping` | `isMessageGroupingEnabled` |
| `renderChatItem`, `renderCustomMessage` | removed; use `renderMessage`, and get channel actions from the context hook and `sendbirdSelectors` |
| `renderChatHeader({ channel, user })` | `renderChannelHeader()` with no arguments; read the channel from the context hook |
| `renderMessageInput({ channel, user, disabled, quoteMessage })` | `renderMessageInput()` with no arguments |
| `experimentalMessageLimit` (open channel) | `messageLimit` |
| `renderChannelProfile` (open channel settings) | `renderOperatorUI`, `renderParticipantList` |

### 3.12.0: `GroupChannel` and `GroupChannelList`

Since 3.12.0, `GroupChannel` and `GroupChannelList` replace `Channel` and `ChannelList` and use local caching. The `App` component keeps the old modules when you pass `enableLegacyChannelModules`. On `GroupChannelList`: `activeChannelUrl` becomes `selectedChannelUrl`, `onProfileEditSuccess` becomes `onUserProfileUpdated`, `overrideInviteUser` becomes `onCreateChannelClick`, `queries.channelListQuery` becomes `channelListQueryParams`, and the new `onChannelCreated` fires when a channel is created (`ChannelList` used `onChannelSelect` for both). Current props: knowledge/curated/js/products/uikit.md. (source: https://sendbird.com/docs/chat/uikit/v3/react/miscellaneous/group-channel-migration-guide)

## React Native UIKit v2 to v3

(source: https://sendbird.com/docs/chat/uikit/v3/react-native/miscellaneous/migration-guide)

- The minimum React Native version is 0.65.0 (was 0.63.3), and the minimum iOS deployment target is 11.0.
- Local caching is required: pass a `localCacheStorage` (the guide's example uses MMKV from `react-native-mmkv`) in `chatOptions` of `SendbirdUIKitContainer`. Container setup: knowledge/curated/js/hosts/react-native.md.
- The `queryCreator` prop is removed from the group channel and group channel list fragments. In 3.12.9 these fragments take `collectionCreator` instead (source: https://unpkg.com/@sendbird/uikit-react-native@3.12.9/lib/typescript/src/domain/groupChannel/types.d.ts).
- The theme color group `colors.ui.message` is renamed `colors.ui.groupChannelMessage`.
- String resources moved from per-screen keys to `LABELS`, for example `GROUP_CHANNEL.LIST_BANNER_FROZEN` becomes `LABELS.CHANNEL_MESSAGE_LIST_FROZEN`. The guide lists every key.
- `useGroupChannelMessages` and `useOpenChannelMessages` return `newMessages` instead of `nextMessages` and `newMessagesFromMembers`.

Feature options moved from `chatOptions` to `uikitOptions` on `SendbirdUIKitContainer`:

| v2 `chatOptions` | v3 `uikitOptions` |
|---|---|
| `enableUserMention` | `groupChannel.enableMention` |
| `enableGroupChannelOGTag` | `groupChannel.enableOgtag` |
| `enableChannelListTypingIndicator` | `groupChannelList.enableTypingIndicator` |
| `enableChannelListMessageReceiptStatus` | `groupChannelList.enableMessageReceiptStatus` |
| `enableMessageSearch` | `groupChannelSettings.enableMessageSearch` |
| `enableOpenChannelOGTag` | `openChannel.enableOgtag` |
| `enableUsingDefaultUserProfile` | `common.enableUsingDefaultUserProfile` |

Renamed props on the group and open channel fragments: `onPressImageMessage` becomes `onPressMediaMessage`, `onLeaveScrollBottom` becomes `onScrolledAwayFromBottom`, and `onPressAvatar` becomes `onShowUserProfile`. The input props `onSendUserMessage`, `onSendFileMessage`, `onUpdateUserMessage`, and `onUpdateFileMessage` were renamed to `onPressSendUserMessage`, `onPressSendFileMessage`, `onPressUpdateUserMessage`, and `onPressUpdateFileMessage`; the guide's table pairs some of these crosswise, so match each by its parameter types in the installed package. `renderGroupChannelPreview` now receives one props object `{ channel, onPress, onLongPress }`.

## Related

- Build and install errors: knowledge/curated/js/cross-cutting/troubleshooting.md "Build and setup"
- Packages: knowledge/curated/js/setup.md
- Chat init, connect, and send: knowledge/curated/js/products/chat.md
- UIKit props and customization: knowledge/curated/js/products/uikit.md
