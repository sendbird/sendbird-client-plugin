<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 / sendbird-uikit-android 3.26.3 (new names); public migration guides fetched 2026-10-16 -->
<!-- verified-at: 2026-10-16 -->
<!-- verification-method: docs-page + sdk-surface -->
<!-- status: populated -->
# android — major version migration

> Moving an app from Chat SDK v3 to v4 and from UIKit v2 to v3 (View). Every old and new name below is taken from Sendbird's public migration guides (cited per section), verified 2026-10-16. Each new name was also found in the `javap` dump of sendbird-chat 4.36.5 or uikit 3.26.3; rows of the guides whose new name is not there (for example a guide row that moves `banUser` to `SendbirdChat`, while 4.36.5 declares it on the channel) are left out. The guides hold the full lists; this page keeps the parts an agent needs first.

## Which guide applies

| Customer is on | Move to | Public guide |
|---|---|---|
| Chat SDK v3 (`com.sendbird.android.SendBird`) | Chat SDK v4 (`com.sendbird.android.SendbirdChat`) | https://sendbird.com/docs/chat/sdk/v4/android/getting-started/migration-guide |
| UIKit v2 (View) | UIKit v3 (View) | https://sendbird.com/docs/chat/uikit/v3/android-view/miscellaneous/migration-guide |
| v3 code built on low-level channel and message calls | group channel and message collections (optional, recommended by the guide) | https://sendbird.com/docs/chat/sdk/v4/android/getting-started/collection-migration-guide |

The docs index (`core/docs-index.json`) has no major-version migration guide for UIKit for Jetpack Compose, Calls, Desk, Live, or AI Agent on Android (checked 2026-10-16). For those, say that no public migration guide exists and work from the product's current docs.

## Order of work

1. Chat SDK first. The UIKit guide says UIKit v3 depends on Chat SDK v4 and that the Chat SDK must be updated before UIKit. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/miscellaneous/migration-guide)
2. Remove the v3 SDK and add the v4 artifact `com.sendbird.sdk:sendbird-chat` from the Sendbird Maven repository (coordinates and versions: knowledge/curated/android/setup.md "Packaging (Gradle)").
3. Run the migration script or do steps 1 to 3 by hand, then step 4 (below). The guide warns the app will likely not compile until every step is done and that the work can take a few hours to a week. (source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/migration-guide)
4. Then UIKit v2 to v3.

Requirements stated by the Chat guide: Android 5.0 (API level 21) or higher, Java 8 or higher, Android Gradle plugin 3.4.2 or higher, and Firebase Cloud Messaging 19.0.1 or higher. The UIKit guide adds `minSdkVersion 21` and `viewBinding true` in the app's `build.gradle`.

## Chat SDK v3 to v4

### Steps from the guide

(source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/migration-guide)

| Step | Change |
|---|---|
| Script (Mac) | The guide links a migration script (`migration_script_v3_to_v4.sh`). Make it executable, run it at the top of the project, and review its changes. It does not cover every change; with it you skip to step 4. Take the download link from the guide page; do not build the URL. |
| 1 | Remove every `import com.sendbird.android.*`; v4 moved classes into new packages. |
| 2 | Replace `SendBird` with `SendbirdChat` (the guide suggests the regular expression `[S]end[B]ird\.` to match only calls) and `SendBirdException` with `SendbirdException`. |
| 3 | Add the v4 imports the guide lists (`com.sendbird.android.channel.*`, `com.sendbird.android.SendbirdChat`, `com.sendbird.android.message.*`, `com.sendbird.android.user.*`, `com.sendbird.android.handler.*`, `com.sendbird.android.channel.query.*`, `com.sendbird.android.message.query.*`, `com.sendbird.android.exception.*`), then let the IDE optimize imports. |
| 4 | Fix the remaining errors with the tables below. |

### Structural changes

- The SDK is written in Kotlin. Getters and setters became properties (Kotlin `hasNext`, Java `getHasNext()`), builders became constructors, and setters no longer return the object.
- `ChannelHandler` is split into `BaseChannelHandler`, `GroupChannelHandler`, and `OpenChannelHandler`.
- `ConnectionHandler` gains `onConnected` and `onDisconnected`.
- Nested classes moved to the top level, for example the user list query result handler now lives in `com.sendbird.android.handler`.
- Callback handlers were unified, so many per-call handlers became `CompletionHandler`, `UserMessageHandler`, `FileMessageHandler`, `GroupChannelCallbackHandler`, and so on.
- Each params class is split into create and update params: `GroupChannelParams`, `OpenChannelParams`, `UserMessageParams`, and `FileMessageParams` become `GroupChannelCreateParams` and `GroupChannelUpdateParams`, and so on.
- You can no longer create your own Sendbird instance. `ConnectionManager` (deprecated in v3) is removed, and the guide recommends local caching over SyncManager.

(source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/migration-guide)

### Common calls, v3 to v4

(source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/migration-guide) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html)

| Task | v3 | v4 |
|---|---|---|
| Initialize | `SendBird.init(APP_ID, applicationContext)` | `SendbirdChat.init(InitParams(APP_ID, applicationContext, false), handler)`, where the handler implements `InitResultHandler` (`onMigrationStarted`, `onInitFailed`, `onInitSucceed`) |
| Connect, disconnect | `SendBird.connect`, `SendBird.disconnect` | `SendbirdChat.connect`, `SendbirdChat.disconnect`; `ConnectHandler` and `DisconnectHandler` are top-level classes |
| Create a channel | `OpenChannel.createChannelWithOperatorUserIds(...)`, `GroupChannel.createChannelWithUserIds(...)` | `OpenChannel.createChannel(OpenChannelCreateParams)`, `GroupChannel.createChannel(GroupChannelCreateParams)` |
| Channel events | `SendBird.addChannelHandler(id, ChannelHandler)` | `SendbirdChat.addChannelHandler(id, handler)` with a `GroupChannelHandler` or an `OpenChannelHandler` |
| Load messages | `getPreviousMessagesByTimestamp(ts, ...)` with separate arguments | `getMessagesByTimestamp(ts, MessageListParams)`; the result handler is `BaseMessagesHandler` |
| Send or update a user message | `UserMessageParams`, separate send and update handlers | `UserMessageCreateParams` or `UserMessageUpdateParams`; one `UserMessageHandler` for both |
| Send a file message | `FileMessageParams` with `setFile(...)` and similar setters | `FileMessageCreateParams` with properties; one `FileMessageHandler` for send and update |
| Push preference of a channel | `setPushPreference(on)`, `isPushEnabled` | `setMyPushTriggerOption(GroupChannel.PushTriggerOption.MENTION_ONLY)` (or `ALL`, `OFF`, `DEFAULT`), `myPushTriggerOption` |
| Mark as delivered from FCM | | `SendbirdChat.markAsDelivered(remoteMessage.data)` |
| Read and delivery counts | `getReadReceipt`, `getDeliveryReceipt` | `getUnreadMemberCount`, `getUndeliveredMemberCount` |

### Renamed names the script does not change

(source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/migration-guide)

| v3 | v4 |
|---|---|
| `ChannelHandler.onReadReceiptUpdated(GroupChannel)` | `GroupChannelHandler.onReadStatusUpdated(GroupChannel)` |
| `ChannelHandler.onDeliveryReceiptUpdated(GroupChannel)` | `GroupChannelHandler.onDeliveryStatusUpdated(GroupChannel)` |
| `GroupChannelCollection.Builder.build()` | `SendbirdChat.createGroupChannelCollection(GroupChannelCollectionCreateParams)` |
| `MessageCollection.Builder.build()` | `SendbirdChat.createMessageCollection(MessageCollectionCreateParams)` |
| `GroupChannelCreateParams.addUserIds` | `GroupChannelCreateParams.userIds` |
| `GroupChannelMemberListQuery.create()` | `createMemberListQuery` on the group channel (4.36.5 takes a `MemberListQueryParams`) |
| `PreviousMessageListQuery.create()` | `createPreviousMessageListQuery` on the channel (4.36.5 takes a `PreviousMessageListQueryParams`) |
| `GroupChannelListQuery.MemberStateFilter` | `MyMemberStateFilter` |
| `UserListQuery` | the specific queries `ApplicationUserListQuery`, `BannedUserListQuery`, `BlockedUserListQuery`, `MutedUserListQuery` |
| `MessagePayloadFilter.Builder` | removed; set `MessagePayloadFilter` properties |
| `enum.from(String)` helpers | removed (internal in v4) |

The script handles the package moves and many handler renames, including `SendBird.registerPushTokenForCurrentUser` to `SendbirdChat.registerPushToken` and `SendBird.ConnectionState` to `ConnectionState`. Read the guide's "Changes supported by the migration script" table to check what it changed.

## UIKit v2 to v3 (View)

UIKit v3 splits each screen into a fragment, a module made of components, and a ViewModel. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/miscellaneous/migration-guide)

### What changed for every fragment

- Builder setters now default to `true`. For example `setUseHeader` was `false` by default in v2; set it to `false` yourself where v2 showed no header.
- A custom fragment can no longer be passed through the builder's setters like `setCustomChannelListFragment`. Subclass the fragment and override `onConfigureParams` (view properties through each component's `params`), `onBeforeReady` (adapters), and the `onBind...Component` methods (event listeners). Since 3.2.1 the builder takes the subclass with `setCustomFragment(...)`.
- A custom theme for a customized fragment goes through `onCreateModule`, which builds the module with `Params(context, themeResId)`. Non-custom fragments still take the theme in the builder.
- To use custom fragments from the UIKit activities, subclass `UIKitFragmentFactory`, override the `new...Fragment` method (for example `newChannelFragment(channelUrl, args)`), and register it with `SendbirdUIKit.setUIKitFragmentFactory(...)` in `Application.onCreate`.

(source: https://sendbird.com/docs/chat/uikit/v3/android-view/miscellaneous/migration-guide)

### Builder renames

(source: https://sendbird.com/docs/chat/uikit/v3/android-view/miscellaneous/migration-guide)

| v2 | v3 |
|---|---|
| `setHeaderLeftButtonListener`, `setHeaderRightButtonListener` | `setOnHeaderLeftButtonClickListener`, `setOnHeaderRightButtonClickListener` |
| `setItemClickListener`, `setItemLongClickListener` | `setOnItemClickListener`, `setOnItemLongClickListener` |
| `setActionItemClickListener` | `setOnActionItemClickListener` |
| `setInputLeftButtonListener` | `setOnInputLeftButtonClickListener` |
| `ChannelFragment.Builder.setOnProfileClickListener` | `setOnMessageProfileClickListener` |
| `setListItemClickListener`, `setListItemLongClickListener` (channel fragments) | one listener per item: `setOnMessageClickListener`, `setOnMessageLongClickListener`, `setOnMessageProfileLongClickListener`, and on group channels `setOnQuoteReplyMessageClickListener` and `setOnQuoteReplyMessageLongClickListener` |
| `CreateableChannelType` | `CreatableChannelType` |
| `setCustomUserListQueryHandler` | `setCustomPagedQueryHandler` |
| `setMemberSettingClickListener`, `setOnSettingMenuClickListener` (settings fragments) | `setOnMenuClickListener` |
| `setUserListAdapter` and `setMemberListAdapter` | a setter named for the screen: `setInviteUserListAdapter`, `setRegisterOperatorListAdapter`, `setParticipantListAdapter`, `setMutedMemberListAdapter`, `setOperatorListAdapter` |

Current customization recipes: knowledge/curated/android/products/uikit.md.

## Related

- Paging duplicates after moving to `getMessagesByTimestamp`: knowledge/curated/android/cross-cutting/troubleshooting.md "Messages and channels"
- Packages and versions: knowledge/curated/android/setup.md
- Chat init and connect: knowledge/curated/android/products/chat.md
- UIKit init and customization: knowledge/curated/android/products/uikit.md
