<!-- last-verified-against: uikit-compose 1.3.6 (UIKit for Jetpack Compose sections); other notes are conceptual host guidance -->
<!-- status: populated -->
# android host — Compose

> Host guidance. The "UIKit for Jetpack Compose" section was checked with `javap` against the uikit-compose 1.3.6 AAR and compiled against it with chat 4.36.5; the other notes are conceptual. Verified 2026-09-30. The customization sections (message items, input, channel list, top bar, push flag) were added and verified 2026-10-11.

## Detection signals
- `androidx.compose.*` imports, `@Composable`, `setContent { }`, Compose BOM in Gradle.

## Integration notes
- The classic UIKit (`com.sendbird.sdk:uikit`) and AI Agent for Android are View/Fragment-based (see templates/android/compose/*/_README.md). UIKit also ships a Compose-native variant — see "UIKit for Jetpack Compose — init, then push" below.
- Host the View/Fragment screens via interop (`AndroidView`, `AndroidFragment`, `FragmentContainerView`), or start the provided activities (e.g. `MessengerActivity`).
- When you host those View/Fragment screens, init + session + connect are identical to the View host; the host only changes how UI is embedded. The Compose-native UIKit has its own init (below).

## UIKit for Jetpack Compose — init, then push

Sendbird ships a Compose-native UIKit: `implementation("com.sendbird.sdk:uikit-compose:1.3.6")` (same `https://repo.sendbird.com/public/maven` repository). Initialize it once in `Application.onCreate()` with `SendbirdUikitCompose.init(UikitInitParams(...))` — it returns a `Flow`, so collect it — and register the push handler after that call. When a user logs in, call `SendbirdUikitCompose.connect()` and register the handler again.

```kotlin
class BaseApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SendbirdUikitCompose.init(
            UikitInitParams(appId = APP_ID, context = this, isForeground = true)
        ).launchIn(MainScope())
        // Must be called after SendbirdUikitCompose.init
        SendbirdPushHelper.registerHandler(MyFirebaseMessagingService())
    }
}
```

(source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.SendbirdUikitCompose; https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/essentials/push-notifications; public sample sendbird-uikit-sample-android-jetpack-compose BaseApplication.kt)

## UIKit for Jetpack Compose — customization (uikit-compose 1.3.6)

Checked on 2026-10-11 against the `uikit-compose-1.3.6.aar` and `uikit-data-1.3.6.aar` with `javap` (parameter names from the class files' local variable tables), and every example here compiled with `tools/curated/compile-snippets-android.sh` (verified 2026-10-11). The library ships no sources; behavior notes below come from the compiled code and are marked as such.

Each screen composable (`ChannelsScreen`, `ChannelScreen`, ...) takes slot parameters (`topBar`, `loading`, `channelItem`, `messageItem`, `messageInput`, `messageInputBottomSheet`, ...). Pass your own composable for a slot, and register the customized screen with `sendbirdGroupChannelNavGraph(channelsScreen = { ... }, channelScreen = { channelUrl -> ... })`. Parameter names differ from the docs in places: the docs table lists `dialogState` for `ChannelsScreen`, but the 1.3.6 parameter is `channelDialogState`. (source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/customization) (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.channels.group.list.ChannelsScreenKt, com.sendbird.uikit.compose.navigation.NavigationKt)

### Custom message items, including file messages
`ChannelScreen(messageItem = { prev, message, next, onClick, onLongClick -> ... })` replaces every row. Inside it, `MessageItemFactory(...)` draws the defaults and has one slot per kind: `myTextMessageItem`, `myFileMessageItem`, `myMediaMessageItem`, `myUnknownMessageItem`, the matching `other*` slots, `adminMessageItem`, and `timelineMessageItem`. A file message whose MIME type is an image or a video goes to the `*MediaMessageItem` slot; any other file goes to `*FileMessageItem` (`MessageExtensionsKt.uiType` checks `isImage`/`isVideo`). A slot you pass replaces the whole default item for that kind, so wire the click and long-click (the long-click opens the message menu) yourself.

```kotlin
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.sendbird.uikit.compose.channels.group.detail.ChannelScreen
import com.sendbird.uikit.compose.channels.group.detail.MessageItemFactory
import com.sendbird.uikit.compose.extension.fileName
import com.sendbird.uikit.core.data.model.message.UikitBaseMessage
import com.sendbird.uikit.core.data.model.message.UikitFileMessage

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun FileCard(file: UikitFileMessage, onClick: (UikitBaseMessage) -> Unit, onLongClick: (UikitBaseMessage) -> Unit) {
    Text(
        text = "${file.fileName()} (${file.type})",
        modifier = Modifier
            .combinedClickable(onClick = { onClick(file) }, onLongClick = { onLongClick(file) })
            .padding(12.dp)
    )
}

@Composable
fun MyChannelScreen(navController: NavController, channelUrl: String) {
    ChannelScreen(
        navController = navController,
        channelUrl = channelUrl,
        messageItem = { prevMessage, message, nextMessage, onMessageClick, onMessageLongClick ->
            MessageItemFactory(
                prevMessage = prevMessage,
                message = message,
                nextMessage = nextMessage,
                onMessageClick = onMessageClick,
                onMessageLongClick = onMessageLongClick,
                myFileMessageItem = { file -> FileCard(file, onMessageClick, onMessageLongClick) },
                otherFileMessageItem = { file -> FileCard(file, onMessageClick, onMessageLongClick) },
            )
        }
    )
}
```

- `UikitFileMessage` exposes `url`, `plainUrl`, `type`, `thumbnail`, and `params`; `fileName()`, `fileIcon()`, `isImage()`, `isVideo()`, and `isFile()` are extensions in `com.sendbird.uikit.compose.extension`. (source: uikit-data-1.3.6.aar javap com.sendbird.uikit.core.data.model.message.UikitFileMessage) (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.extension.MessageExtensionsKt, com.sendbird.uikit.compose.channels.group.detail.MessageItemKt)
- A message type of your own: `UikitBaseMessage` has no `customType` or `data` property. The default message repository builds `ChatBaseMessage` objects (`toChatBaseMessages` in `DefaultMessageListRepository`), and `ChatBaseMessage` exposes the Chat SDK message as its `baseMessage` property, so `(message as? ChatBaseMessage)?.baseMessage?.customType` reads it; other message classes give `null` from that cast. (source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/customization) (source: uikit-data-1.3.6.aar javap com.sendbird.uikit.core.data.model.message.UikitBaseMessage, com.sendbird.uikit.core.data.model.message.ChatBaseMessage)

### Message input: attachment menu and enabled state
The menu button of the default input opens the `messageInputBottomSheet` slot while `MessageInputState.isBottomSheetVisible` is true. The default slot is `MessageInputBottomSheet(contract, onItemClick = { it.onClick() }, onDismissRequest = { messageInputState.clear() })`, and its default `menus` is `SendbirdDialogDefaults.messageInputMenuItems(contract)`: take photo, capture video, gallery, document (in that order). Pass your own `menus` list to keep only some of them; each `SendbirdDialogDefaults.messageInput*Menu(contract)` item calls the matching `contract.onClick*()` by default.

```kotlin
import androidx.compose.runtime.Composable
import androidx.navigation.NavController
import com.sendbird.uikit.compose.channels.group.detail.ChannelScreen
import com.sendbird.uikit.compose.channels.group.detail.MessageInputBottomSheet
import com.sendbird.uikit.compose.channels.group.detail.rememberMessageInputState
import com.sendbird.uikit.compose.component.defaults.SendbirdDialogDefaults

@Composable
fun GalleryAndDocumentOnly(navController: NavController, channelUrl: String) {
    val inputState = rememberMessageInputState()
    ChannelScreen(
        navController = navController,
        channelUrl = channelUrl,
        messageInputState = inputState,
        messageInputBottomSheet = { contract ->
            MessageInputBottomSheet(
                messageInputBottomSheetContract = contract,
                menus = { c ->
                    listOf(
                        SendbirdDialogDefaults.messageInputGalleryMenu(c),
                        SendbirdDialogDefaults.messageInputDocumentMenu(c),
                    )
                },
                onItemClick = { it.onClick() },
                onDismissRequest = { inputState.clear() },
            )
        }
    )
}
```

- The public `ChannelMessageInput(modifier, state, viewModelContract)` and `MessageInput(...)` signatures in 1.3.6 have no parameter for the menu button's visibility. (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.channels.group.detail.MessageInputKt, com.sendbird.uikit.compose.component.defaults.SendbirdDialogDefaults, com.sendbird.uikit.compose.channels.group.detail.ChannelScreenKt)
- To turn the input off at runtime, replace the `messageInput` slot: keep `ChannelMessageInput` while sending is allowed and show `MessageInput(enabled = false)` otherwise. `ChannelMessageInput` needs the screen's view model, so create it the way `ChannelScreen` does by default — `viewModel(factory = ChannelViewModel.factory(ChannelViewModelParams(channelUrl)))` — and pass the same object as `viewModelContract`:

```kotlin
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.sendbird.uikit.compose.channels.group.detail.ChannelMessageInput
import com.sendbird.uikit.compose.channels.group.detail.ChannelScreen
import com.sendbird.uikit.compose.channels.group.detail.ChannelViewModel
import com.sendbird.uikit.compose.channels.group.detail.ChannelViewModelParams
import com.sendbird.uikit.compose.channels.group.detail.MessageInput

@Composable
fun ChannelWithLockableInput(navController: NavController, channelUrl: String, canSend: Boolean) {
    val channelViewModel: ChannelViewModel = viewModel(
        factory = ChannelViewModel.factory(ChannelViewModelParams(channelUrl))
    )
    ChannelScreen(
        navController = navController,
        channelUrl = channelUrl,
        viewModelContract = channelViewModel,
        messageInput = { state ->
            if (canSend) {
                ChannelMessageInput(state = state, viewModelContract = channelViewModel)
            } else {
                MessageInput(inputValue = "", onInputValueChange = {}, enabled = false)
            }
        }
    )
}
```
(source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.channels.group.detail.ChannelViewModel$Companion, com.sendbird.uikit.compose.channels.group.detail.ChannelViewModelParams, com.sendbird.uikit.compose.channels.group.detail.ChannelScreenKt) (source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/screens/messages-in-a-channel)

### Channel list: loading, item, query filter
`ChannelsScreen` has `loading`, `failure`, `empty`, `topBar`, and `channelItem` slots. `LoadingScreen(modifier)`, `FailurePlaceholder(modifier, onRetryClick)`, and `ChannelItem(channel, modifier, onClick, onLongClick)` are the public defaults to fall back on. The query is set through the view model: `ChannelsViewModel.factory(ChannelsViewModelParams(queryParams))`, which is what `ChannelsScreen` calls by default with an empty `ChannelsViewModelParams()`.

```kotlin
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.sendbird.android.channel.query.GroupChannelListQueryOrder
import com.sendbird.android.params.GroupChannelListQueryParams
import com.sendbird.uikit.compose.channels.group.list.ChannelItem
import com.sendbird.uikit.compose.channels.group.list.ChannelsScreen
import com.sendbird.uikit.compose.channels.group.list.ChannelsViewModel
import com.sendbird.uikit.compose.channels.group.list.ChannelsViewModelParams

@Composable
fun SupportChannels(navController: NavController) {
    val queryParams = GroupChannelListQueryParams().apply {
        includeEmpty = false
        customTypesFilter = listOf("support")
        order = GroupChannelListQueryOrder.LATEST_LAST_MESSAGE
    }
    ChannelsScreen(
        navController = navController,
        viewModelContract = viewModel<ChannelsViewModel>(
            factory = ChannelsViewModel.factory(ChannelsViewModelParams(queryParams))
        ),
        loading = {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        },
        channelItem = { channel, onClick, onLongClick ->
            ChannelItem(channel = channel, onClick = onClick, onLongClick = onLongClick)
        }
    )
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/screens/channel-list) (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.channels.group.list.ChannelsScreenKt, com.sendbird.uikit.compose.channels.group.list.ChannelsViewModel$Companion, com.sendbird.uikit.compose.channels.group.list.ChannelsViewModelParams, com.sendbird.uikit.compose.component.ProgressKt)

### Header (top bar)
`ChannelsScreen(topBar = { onNavigationIconClick, onActionClick -> ... })` and `ChannelScreen(topBar = { state -> ... })` replace the top bars. `ChannelsTopBar` and `ChannelTopBar` take `title`, `navigationIcon`, and `action` slots; `ChannelTopBarState` carries `coverModels`, `title`, `channelDescription`, `onNavigationIconClick`, and `onActionClick`. Passing `navigationIcon = {}` leaves the navigation icon out, as in the docs example.

```kotlin
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.navigation.NavController
import com.sendbird.uikit.compose.channels.group.detail.ChannelScreen
import com.sendbird.uikit.compose.channels.group.detail.ChannelTopBar

@Composable
fun ChannelWithPlainTitle(navController: NavController, channelUrl: String) {
    ChannelScreen(
        navController = navController,
        channelUrl = channelUrl,
        topBar = { state ->
            ChannelTopBar(
                channelCoverModels = state.coverModels,
                channelTitle = state.title,
                channelDescription = state.channelDescription,
                onNavigationIconClick = state.onNavigationIconClick,
                onActionClick = state.onActionClick,
                title = { Text(state.title) },
            )
        }
    )
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/screens/messages-in-a-channel) (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.channels.group.detail.ChannelTopBarKt, com.sendbird.uikit.compose.channels.group.detail.ChannelTopBarState, com.sendbird.uikit.compose.channels.group.list.ChannelsTopBarKt)

### Theme, fonts, and strings
See knowledge/curated/android/cross-cutting/theme.md — "Jetpack Compose host".

### Push: the unique-token flag
The Compose UIKit registers push through the Chat SDK's `SendbirdPushHandler` / `SendbirdPushHelper` (Step 4 of the Compose push guide). The unique flag is the handler's `isUniquePushToken` property: when the handler receives a new FCM token, the SDK registers it and passes along the handler's `isUniquePushToken()` value. That registration call is internal to the SDK (a Kotlin `internal` method in the 4.36.5 AAR), so the app does not call it. (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.push/-sendbird-push-handler/index.html ; sendbird-chat 4.36.5 `javap -public` of the push helper and handler classes, where the token registration methods carry the `$sendbird_release` suffix of Kotlin `internal`) Override it in your handler; the handler shape and registration order are in knowledge/curated/android/cross-cutting/push.md.

```kotlin
import com.google.firebase.messaging.RemoteMessage

class UniqueTokenMessagingService : SendbirdPushHandler() {
    override val isUniquePushToken: Boolean
        get() = true
    override fun onMessageReceived(context: Context, remoteMessage: RemoteMessage) { }
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/essentials/push-notifications) (source: sendbird-chat-4.36.4.aar javap -c com.sendbird.android.push.SendbirdPushHandler — `onTokenUpdated` calls `isUniquePushToken()` and passes it to `SendbirdPushHelper.registerPushToken`) (source: knowledge/curated/android/cross-cutting/push.md)

## Start a 1:1 chat from a button (Compose UIKit)
Create the channel with the Chat SDK and `isDistinct = true` (knowledge/curated/android/products/chat.md, "Create and list group channels"), then call `navController.navigateToChannel(url)` on the `NavController` whose `NavHost` contains `sendbirdGroupChannelNavGraph(navController)`. The same call opens a channel from a push tap once you have its channel URL (the payload is in knowledge/curated/android/cross-cutting/push.md). The template `templates/android/compose/uikit/UikitComposeApp.kt` builds that `NavHost`.

```kotlin
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.navigation.NavController
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.params.GroupChannelCreateParams
import com.sendbird.uikit.compose.navigation.navigateToChannel

@Composable
fun ChatWithSellerButton(navController: NavController, sellerUserId: String) {
    Button(onClick = {
        val params = GroupChannelCreateParams().apply {
            userIds = listOf(sellerUserId)
            isDistinct = true   // same members -> the existing channel comes back
        }
        GroupChannel.createChannel(params) { channel, e ->
            if (e == null && channel != null) navController.navigateToChannel(channel.url)
        }
    }) {
        Text("Chat with seller")
    }
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/navigation) (source: knowledge/curated/android/products/chat.md — Create and list group channels) (uikit-compose 1.3.6 AAR `javap` on `com.sendbird.uikit.compose.navigation.NavigationKt`: `navigateToChannel(NavController, String)`, `sendbirdGroupChannelNavGraph`; also templates/android/compose/uikit/UikitComposeApp.kt, compile-checked)

## Related
- View host: knowledge/curated/android/hosts/view.md
- AI Agent: knowledge/curated/android/products/ai-agent.md
