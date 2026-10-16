<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 / sendbird-uikit-ios 3.36.2 (new names); public migration guides fetched 2026-10-16 -->
<!-- verified-at: 2026-10-16 -->
<!-- verification-method: docs-page + sdk-surface -->
<!-- status: populated -->
# ios — major version migration

> Moving an app from Chat SDK v3 to v4 and from UIKit v2 to v3. Every old and new name below is taken from Sendbird's public migration guides (cited per section), verified 2026-10-16. Each new name was also found in the SendbirdChatSDK 4.39.11 or SendbirdUIKit 3.36.2 interface; rows of the guides whose new name is not in those interfaces are left out. The guides hold the full lists; this page keeps the parts an agent needs first.

## Which guide applies

| Customer is on | Move to | Public guide |
|---|---|---|
| Chat SDK v3 (`import SendBirdSDK`, `SBDMain`) | Chat SDK v4 (`import SendbirdChatSDK`) | https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/migration-guide |
| UIKit v2 (`SendBirdUIKit` module, `SBUMain`) | UIKit v3 (`SendbirdUIKit` module, `SendbirdUI`) | https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two |
| UIKit v3.5 or earlier, customizing through `SBUModuleSet` instances | UIKit v3.6 and later | https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-three-point-five |
| v3 code built on low-level channel and message calls | group channel and message collections (optional, recommended by the guide) | https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/collection-migration-guide |

The docs index (`core/docs-index.json`) has no major-version migration guide for SwiftUI, Calls, Desk, Live, or AI Agent on iOS (checked 2026-10-16). For those, say that no public migration guide exists and work from the product's current docs.

## Order of work

1. Chat SDK first. The UIKit guide says UIKit v3 depends on Chat SDK v4 and that the Chat SDK must be updated before UIKit. (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two)
2. Swap the package (next section).
3. Follow the Chat guide's steps 1 to 5 in order (below). The guide warns the app will likely not compile until every step is done and that the work can take a few hours to a week. (source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/migration-guide)
4. Then UIKit v2 to v3, and, if the app customizes modules, the v3.6 module-set change.

## Package change

- Swift Package Manager (default): remove the v3 package and add `https://github.com/sendbird/sendbird-chat-sdk-ios`, product `SendbirdChatSDK`, from 4.0.0. The `sendbird-chat-ios-spm` mirror is legacy v3 (`SendBirdSDK`); a project that keeps it never gets v4. UIKit v3 comes from `https://github.com/sendbird/sendbird-uikit-ios-spm` (product `SendbirdUIKit`). (source: knowledge/curated/ios/setup.md)
- A project that already has a `Podfile` keeps CocoaPods: the Chat v4 pod is `SendbirdChatSDK` (source: https://github.com/sendbird/sendbird-chat-sdk-ios/blob/master/README.md#L113). The UIKit pod keeps the name `SendBirdUIKit` with a capital B even though the Swift module is now `SendbirdUIKit` (source: https://github.com/sendbird/sendbird-uikit-ios/blob/main/README.md#L113-L129). Never add a `Podfile` to an SPM project.
- Requirements stated by the guide: Xcode 15 or later, iOS 12.0 or later, Swift 5.0 or later, or Objective-C. Raise any Sendbird package that has a minimum Chat SDK version together with it (see "Keep shared dependencies compatible" in knowledge/curated/ios/setup.md).

## Chat SDK v3 to v4

### Steps from the guide

(source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/migration-guide)

| Step | Change |
|---|---|
| 1 | Replace every `import SendBirdSDK` with `import SendbirdChatSDK` (the "b" is lowercase now). Remove calls that were already deprecated in v3 first. |
| 2 | Replace `SBDError` with `SBError`. |
| 3 | Replace `SBDMain` with `SendbirdChat`. Initialize `SendbirdChat` before calling any other SDK interface (init and connect: knowledge/curated/ios/products/chat.md). |
| 4 | Remove the `SBD` prefix from every constant, protocol, class, enum, and type name. |
| 5 | Fix the remaining compile errors with the table under "Errors you will see". |

### Renamed and split names

(source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/migration-guide)

| v3 | v4 |
|---|---|
| `SBDMain` | `SendbirdChat` |
| `SBDError` | `SBError` |
| `SBDOptions` | `SendbirdChatOptions` |
| `useMemberAsMessageSender` (option) | `useMemberInfoInMessage` |
| `getChannelCount` | `getGroupChannelCount` |
| `isUsingLocalCaching` | `isLocalCachingEnabled` |
| `memberStateFilter: MemberStateFilter` | `myMemberStateFilter: MyMemberStateFilter` |
| `channelDidUpdateReadReceipt` | `channelDidUpdateReadStatus` |
| `channelDidUpdateDeliveryReceipt` | `channelDidUpdateDeliveryStatus` |
| `SBDChannelDelegate` | `BaseChannelDelegate`, `GroupChannelDelegate`, `OpenChannelDelegate` |
| `SBDUserListQuery` | removed; use a specific query such as `ApplicationUserListQuery`, `BlockedUserListQuery`, `BannedUserListQuery`, `MutedUserListQuery`, or `ParticipantListQuery` |
| `SBDGroupChannelParams` | `GroupChannelCreateParams`, `GroupChannelUpdateParams` |
| `SBDOpenChannelParams` | `OpenChannelCreateParams`, `OpenChannelUpdateParams` |
| `SBDUserMessageParams` | `UserMessageCreateParams`, `UserMessageUpdateParams` |
| `SBDFileMessageParams` | `FileMessageCreateParams`, `FileMessageUpdateParams` |

Other changes the guide lists:

- `ConnectionDelegate` gains `didConnect(userId:)` and `didDisconnect(userId:)`.
- The file upload `onProgress` callback gains a `requestId` argument.
- You can no longer create your own Sendbird instance.
- Defaults changed: a group channel's `members` is `[]` instead of `nil`, and a user's `nickname` is `""` instead of `nil`. Code that checks for `nil` there no longer sees it.
- Query classes lost their setters; each has a matching params class instead.
- `SBDConnectionManager` (deprecated in v3) is removed. The guide recommends local caching over SyncManager.
- The `Mappable` protocol is gone in Swift; use `Codable` to serialize objects. Objective-C is unchanged.
- The guide advises against subclassing SDK classes in v4.

### Errors you will see

(source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/migration-guide)

| Xcode error | Fix from the guide |
|---|---|
| "Missing arguments for parameters params and completionHandler in call", "Extra arguments at positions …", "Extra argument in call" | The v3 method took separate arguments. Build the params object (for example `OpenChannelUpdateParams`), set its fields, and pass it as `params:`. |
| "Type of expression is ambiguous without more context", "nil requires a contextual type" | Delete lines that assign `nil` to params fields such as `data` or `customType`; v4 leaves them `nil` by default. |
| "Cannot find type ChannelDelegate in scope" | Pick the delegate the class needs: `BaseChannelDelegate`, `GroupChannelDelegate`, or `OpenChannelDelegate`. The guide's example is an app delegate that only needs `BaseChannelDelegate`. |
| "Cannot find type XXXParams in scope" | The params class was split into create and update params; use the table above. |
| A user list query stored as one shared `UserListQuery` | Declare each query with its own type (`BannedUserListQuery`, `MutedUserListQuery`, `ParticipantListQuery`); v4 no longer lets you cast them to one type. |

## UIKit v2 to v3

UIKit v3 splits each screen into a view controller, a module of components that draws the UI, and a view model that talks to the Chat SDK. Xcode reports most renames as warnings or errors at build time. (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two)

### Initialization and global names

(source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two)

| v2 | v3 |
|---|---|
| module `SendBirdUIKit` | module `SendbirdUIKit` |
| `SBUMain` | `SendbirdUI` |
| `initialize(applicationId:migrationStartHandler:completionHandler:)` | `initialize(applicationId:startHandler:migrationHandler:completionHandler:)` |
| enum `ChannelMemberListType` | `ChannelUserListType` (cases `members`, `muted`, `banned`) |
| `setupAutolayout()`, `updateAutolayout()` | `setupLayouts()`, `updateLayouts()` |
| `didReceiveError(_:_:)` | `errorHandler(_:_:)` |
| `shouldShowLoadingIndicator()`, `shouldDismissLoadingIndicator()` | `shouldUpdateLoadingState(_:)` |

The guide recommends showing a loading indicator from `startHandler` until `completionHandler` runs. Current init code is in knowledge/curated/ios/products/uikit.md.

### `SBUGlobals` properties

The v3 column is from the guide. UIKit 3.36.2 still declares the v2 names as deprecated with a `renamed:` fix-it, and has since moved two of the v3 names to `SendbirdUI.config` (last column). (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.2/Sources/Deprecated/SBUGlobals.Deprecated.swift#L13-L80) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.2/Sources/SBUGlobals.swift#L70-L79)

| v2 | v3 | UIKit 3.36.2 |
|---|---|---|
| `ApplicationId` | `applicationId` | same |
| `AccessToken` | `accessToken` | same |
| `CurrentUser` | `currentUser` | same |
| `UsingMessageGrouping` | `isMessageGroupingEnabled` | same |
| `ReplyTypeToUse` | `replyType` | deprecated (3.3.0), renamed to `SendbirdUI.config.groupChannel.channel.replyType` |
| `UsingPHPicker` | `isPHPickerEnabled` | same |
| `UsingUserProfile` | `isUserProfileEnabled` | deprecated (3.6.0), renamed to `SendbirdUI.config.common.isUsingDefaultUserProfileEnabled` |
| `UsingUserProfileInOpenChannel` | `isOpenChannelUserProfileEnabled` | deprecated (3.6.0), renamed to `SendbirdUI.config.common.isUsingDefaultUserProfileEnabled` |
| `UsingImageCompression` | `isImageCompressionEnabled` | same |

### Renamed view controllers

(source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two)

| v2 | v3 |
|---|---|
| `SBUChannelListViewController` | `SBUGroupChannelListViewController` |
| `SBUChannelViewController` | `SBUGroupChannelViewController` |
| `SBUMemberListViewController` | `SBUUserListViewController` (`init(channel:type:)` becomes `init(channel:userListType:)`) |
| `SBUInviteUserViewController` with a type | `SBUInviteUserViewController` for invites and `SBURegisterOperatorViewController` for operators; the `type:` argument is gone |
| `SBUBaseChannelSettingViewController` | `SBUBaseChannelSettingsViewController` |
| `SBUChannelSettingsViewController` | `SBUGroupChannelSettingsViewController` |

### Where view properties and data went

Views moved from the view controller into its components, and data and SDK calls moved into its view model. Examples from the guide: `titleView`, `leftBarButton`, and `rightBarButton` are now under `headerComponent`; `tableView`, `emptyView`, and the cells are under `listComponent`; `messageInputView` is `inputComponent.messageInputView`; `channelUrl` is `viewModel.channelURL`; `channelListQuery` is `viewModel.channelListQuery`. The guide lists every moved property and method per screen, including the old input delegate methods that became `baseChannelModule(...)` delegate methods. (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two)

To replace a screen across the app, set a subclass on `SBUViewControllerSet`, for example `SBUViewControllerSet.GroupChannelListViewController = CustomGroupChannelListViewController.self`. (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two)

## UIKit v3.5 to v3.6: module set takes types

In v3.6 the `SBUModuleSet` properties and each module's component properties take a type instead of an instance, and the lowercase instance properties are deprecated. The v2-to-v3 guide still shows the old instance form (`SBUModuleSet.channelListModule = CustomModule()`); write the type form for current UIKit. (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-three-point-five)

| v3.5 | v3.6 |
|---|---|
| `SBUModuleSet.groupChannelModule = MyAppChannelModule()` | `SBUModuleSet.GroupChannelModule = MyAppChannelModule.self` |
| `SBUModuleSet.groupChannelModule.headerComponent = MyAppChannelHeader()` | `SBUModuleSet.GroupChannelModule.HeaderComponent = MyAppChannelHeader.self` |

Customizations made to properties of a module or component instance are not carried over by the type form. Set them in a view controller subclass, or in the component's `configure` override before calling `super.configure(delegate:theme:)`, as the guide shows. Current customization recipes: knowledge/curated/ios/products/uikit.md.

## Related

- Build error after the upgrade: knowledge/curated/ios/cross-cutting/troubleshooting.md "Upgrading from v3"
- Packages and versions: knowledge/curated/ios/setup.md
- Chat init and connect: knowledge/curated/ios/products/chat.md
- UIKit init and customization: knowledge/curated/ios/products/uikit.md
