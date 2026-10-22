<!-- last-verified-against: sendbird-uikit-android 3.26.3 -->
<!-- status: populated -->
# android uikit

> Verified against the public mirror `sendbird/sendbird-uikit-android` (uikit-samples BaseApplication, verified 2026-06-09). The templates compiled against 3.26.3 in GitHub Actions run 34187419379 on 2026-09-08. The "Present prebuilt screens" section below verified against the real `uikit-3.26.3.aar` (downloaded from `https://repo.sendbird.com/public/maven`, decompiled with `javap -public`, verified 2026-09-29). The customization sections (message views, message input, channel list, header) were read from the public `sendbird-uikit-android` source on `main`, whose `gradle.properties` is `UIKIT_VERSION = 3.26.3` (commit `07ffe8e`), and every example compiled against uikit 3.26.3 with `tools/curated/compile-snippets-android.sh` (verified 2026-10-11). The header notes on typing text color and long channel names were added on 2026-10-12 from the same commit. Cite each symbol; do not add API from memory. Compose-native equivalents live in knowledge/curated/android/hosts/compose.md.
> Primary source: https://github.com/sendbird/sendbird-uikit-android (docs: https://sendbird.com/docs/uikit/v3/android/overview)

## Overview
Sendbird UIKit gives prebuilt chat screens (channel list, channel, settings) on top of Chat. Initialize UIKit with an adapter that supplies the app ID + user info, then launch the provided fragments/activities.

## Install (Gradle)
- Repo in `settings.gradle`: `maven { setUrl("https://repo.sendbird.com/public/maven") }`.
- Dependency: `implementation("com.sendbird.sdk:uikit:3.26.3")` (or `3.+`).
- Subclassing a UIKit adapter or view holder (custom message views, custom channel items below): UIKit 3.26.3 declares `androidx.recyclerview:recyclerview:1.3.2` with `runtime` scope, so it is not on your compile classpath. Add `implementation("androidx.recyclerview:recyclerview:1.3.2")` to the app module, or the compiler reports "Cannot access 'ViewHolder' which is a supertype of ...". (source: https://repo.sendbird.com/public/maven/com/sendbird/sdk/uikit/3.26.3/uikit-3.26.3.pom)

## Initialize (Application class)
```kotlin
import com.sendbird.uikit.SendbirdUIKit
import com.sendbird.uikit.adapter.SendbirdUIKitAdapter
import com.sendbird.uikit.interfaces.UserInfo
import com.sendbird.android.handler.InitResultHandler
import com.sendbird.android.exception.SendbirdException

val adapter = object : SendbirdUIKitAdapter {
    override fun getAppId(): String = APP_ID
    override fun getAccessToken(): String? = null
    override fun getUserInfo(): UserInfo = object : UserInfo {
        override fun getUserId(): String = USER_ID
        override fun getNickname(): String = NICKNAME
        override fun getProfileUrl(): String = PROFILE_URL
    }
    override fun getInitResultHandler(): InitResultHandler = object : InitResultHandler {
        override fun onMigrationStarted() { }
        override fun onInitFailed(e: SendbirdException) { }
        override fun onInitSucceed() { }
    }
}
SendbirdUIKit.init(adapter, context)
```
(source: sendbird-uikit-android uikit-samples BaseApplication.kt)

## Present prebuilt screens
```kotlin
startActivity(ChannelListActivity.newIntent(this))

startActivity(ChannelActivity.newIntent(this, channelUrl))
```
`ChannelListActivity.newIntent(Context)` (and an overload taking a theme resource id) builds the channel-list screen's intent; `ChannelActivity.newIntent(Context, channelUrl: String)` opens a specific conversation. `ChannelListActivity.newRedirectToChannelIntent(Context, channelUrl)` opens the list and immediately redirects into that channel. (source: `sendbird-uikit-android` 3.26.3 AAR (`uikit-3.26.3.aar`), `javap` on `com.sendbird.uikit.activities.ChannelListActivity`, `com.sendbird.uikit.activities.ChannelActivity`)

## Customization model (View host)
UIKit screens are built in layers: an Activity hosts a Fragment, the Fragment owns a Module, the Module holds Components (header, message list, input, status), and list Components render through a RecyclerView adapter. Replace a layer through the global providers in `Application.onCreate()` — `AdapterProviders`, `ModuleProviders`, `FragmentProviders` — or per screen through the Fragment's `Builder`. The provider objects and their `lateinit var` properties are in `providers/AdapterProviders.kt` (`messageList` line 19, `channelList` line 37), `providers/ModuleProviders.kt` (`channel` line 34) and `providers/FragmentProviders.kt` (`channelList` line 21, `channel` line 30). (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/providers/AdapterProviders.kt#L19) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/global-customization/list-adapters)

## Custom message views, including file messages (View host)
The message list adapter is `MessageListAdapter`. It picks a view type per message with `MessageViewHolderFactory.getViewType(message)`; you return your own `MessageViewHolder` for the types you want to replace and call `super` for the rest. File messages map to these `MessageType` values (`MessageViewHolderFactory.getMessageType`, line 291): a voice message goes to `VIEW_TYPE_VOICE_MESSAGE_ME`/`_OTHER`; a MIME type starting with `image` (except SVG) goes to `VIEW_TYPE_FILE_MESSAGE_IMAGE_ME`/`_OTHER`; a MIME type starting with `video` goes to `VIEW_TYPE_FILE_MESSAGE_VIDEO_ME`/`_OTHER`; every other file (including SVG) goes to `VIEW_TYPE_FILE_MESSAGE_ME`/`_OTHER`. Values 0–1000 are reserved for UIKit; a type of your own (for a message whose `customType` you set) starts at 1001. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/message-item-ui) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/add-new-message-type) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/viewholder/MessageViewHolderFactory.java#L291)

```kotlin
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.message.BaseMessage
import com.sendbird.android.message.FileMessage
import com.sendbird.android.message.Reaction
import com.sendbird.uikit.activities.adapter.MessageListAdapter
import com.sendbird.uikit.activities.viewholder.GroupChannelMessageViewHolder
import com.sendbird.uikit.activities.viewholder.MessageType
import com.sendbird.uikit.activities.viewholder.MessageViewHolder
import com.sendbird.uikit.consts.ClickableViewIdentifier
import com.sendbird.uikit.interfaces.OnItemClickListener
import com.sendbird.uikit.interfaces.OnItemLongClickListener
import com.sendbird.uikit.interfaces.providers.MessageListAdapterProvider
import com.sendbird.uikit.model.MessageListUIParams
import com.sendbird.uikit.providers.AdapterProviders

class FileCardViewHolder(private val label: TextView) : GroupChannelMessageViewHolder(label) {
    override fun bind(channel: BaseChannel, message: BaseMessage, params: MessageListUIParams) {
        val file = message as? FileMessage ?: return
        label.text = "${file.name} (${file.size} bytes)"
    }
    override fun setEmojiReaction(
        reactionList: List<Reaction>,
        emojiReactionClickListener: OnItemClickListener<String>?,
        emojiReactionLongClickListener: OnItemLongClickListener<String>?,
        moreButtonClickListener: View.OnClickListener?
    ) {}
    override fun getClickableViewMap(): Map<String, View> = mapOf(ClickableViewIdentifier.Chat.name to label)
}

class MyMessageListAdapter(channel: GroupChannel?, uiParams: MessageListUIParams) : MessageListAdapter(channel, uiParams) {
    companion object {
        const val INVOICE_VIEW_TYPE = 1001 // 0–1000 are reserved for UIKit
    }

    override fun getItemViewType(position: Int): Int =
        if (getItem(position).customType == "invoice") INVOICE_VIEW_TYPE else super.getItemViewType(position)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
        // Check your own types first: MessageType.from() maps an unknown value to VIEW_TYPE_ADMIN_MESSAGE.
        if (viewType == INVOICE_VIEW_TYPE) return wireClicks(FileCardViewHolder(TextView(parent.context)))
        return when (MessageType.from(viewType)) {
            MessageType.VIEW_TYPE_FILE_MESSAGE_ME,
            MessageType.VIEW_TYPE_FILE_MESSAGE_OTHER -> wireClicks(FileCardViewHolder(TextView(parent.context)))
            else -> super.onCreateViewHolder(parent, viewType)
        }
    }

    // UIKit attaches the click / long-click listeners for getClickableViewMap() inside
    // BaseMessageListAdapter.onCreateViewHolder, which a holder created here skips — attach them yourself.
    private fun wireClicks(holder: MessageViewHolder): MessageViewHolder {
        for ((identifier, view) in holder.clickableViewMap) {
            view.setOnClickListener { v ->
                val position = holder.bindingAdapterPosition
                if (position != -1) onListItemClickListener?.onIdentifiableItemClick(v, identifier, position, getItem(position))
            }
            view.setOnLongClickListener { v ->
                val position = holder.bindingAdapterPosition
                if (position == -1) return@setOnLongClickListener false
                onListItemLongClickListener?.onIdentifiableItemLongClick(v, identifier, position, getItem(position))
                true
            }
        }
        return holder
    }
}

// Application.onCreate(), before any channel screen is created:
AdapterProviders.messageList = MessageListAdapterProvider { channel, uiParams ->
    MyMessageListAdapter(channel, uiParams)
}
```

- `GroupChannelMessageViewHolder` requires `setEmojiReaction(...)` and `getClickableViewMap()`; draw the message in `bind(channel, message, params)`. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/viewholder/GroupChannelMessageViewHolder.java#L38) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/viewholder/MessageViewHolder.java#L134)
- Click wiring: `BaseMessageListAdapter.onCreateViewHolder` reads `getClickableViewMap()` and sets the listeners at line 178. `MessageListAdapter.onCreateViewHolder` reaches it through `super`, so a holder you return without calling `super` gets no message click or long-click (the long-click opens the message menu). `getOnListItemClickListener()` and `getOnListItemLongClickListener()` are public (lines 461, 482). The public docs and the customization sample return custom holders without this step. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/adapter/BaseMessageListAdapter.java#L178) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/customization/channel/MessageUISample.kt#L91)
- `MessageType.from` returns `VIEW_TYPE_ADMIN_MESSAGE` for a value it does not know (line 146). (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/viewholder/MessageType.java#L140)
- To tag outgoing messages with a `customType`, set it in `SendbirdUIKit.setCustomParamsHandler(object : CustomParamsHandler { ... })`; `onBeforeSendUserMessage(params)` and `onBeforeSendFileMessage(params)` are default methods, so override only the ones you need. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/interfaces/CustomParamsHandler.java#L46)
- One screen only: pass the adapter to `ChannelFragment.Builder(channelUrl).setMessageListAdapter(adapter)` instead of the global provider. For text color, font, and bubble background without replacing the view, set a `MessageUIConfig` on the adapter or use the Builder's `setMessageTextUIConfig(...)` (see knowledge/curated/android/cross-cutting/theme.md). (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1477) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/global-customization/list-adapters)

## Message input: attachment menu, extra buttons, enabled state (View host)
The left button of the input opens `showMediaSelectDialog()` by default (`ChannelFragment.onBindMessageInputComponent`, line 503). That dialog lists Camera (photo), Camera (video), Gallery, and Document, each only when its `ChannelConfig.input` flag is on (`BaseMessageListFragment`, lines 637–651).

**Turn attachment options off** — globally through `UIKitConfig`, which takes priority over the dashboard UIKit settings:

```kotlin
import com.sendbird.uikit.model.configurations.UIKitConfig

UIKitConfig.groupChannelConfig.input.camera.enablePhoto = false
UIKitConfig.groupChannelConfig.input.camera.enableVideo = false
UIKitConfig.groupChannelConfig.input.gallery.enablePhoto = true
UIKitConfig.groupChannelConfig.input.gallery.enableVideo = false
UIKitConfig.groupChannelConfig.input.enableDocument = false
```

- The Gallery item appears when `gallery.enablePhoto` or `gallery.enableVideo` is true. Voice messages are a separate flag, `ChannelConfig.enableVoiceMessage` (default `false`). (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/BaseMessageListFragment.java#L637) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/model/configurations/ChannelConfig.kt#L310) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/model/configurations/UIKitConfig.kt#L5)
- **All options off:** the dialog's item list is empty and `showMediaSelectDialog()` returns without showing anything (line 652), but the left button stays on screen. Remove the button with `ChannelFragment.Builder(channelUrl).setUseInputLeftButton(false)`. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/BaseMessageListFragment.java#L652) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1363)
- One screen only: `ChannelFragment.Builder(channelUrl).setChannelConfig(UIKitConfig.groupChannelConfig.clone().apply { input.enableDocument = false })`. `ChannelConfig.clone()` copies the input settings too. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/model/configurations/ChannelConfig.kt#L583) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L2213)

**Replace the menu with your own actions** — override `showMediaSelectDialog()` in a `ChannelFragment` subclass and reuse the public `takeCamera()`, `takeVideo()`, `takePhoto()` (gallery), and `takeFile()`; or set `ChannelFragment.Builder.setOnInputLeftButtonClickListener { }`:

```kotlin
import com.sendbird.uikit.fragments.ChannelFragment
import com.sendbird.uikit.interfaces.providers.ChannelFragmentProvider
import com.sendbird.uikit.providers.FragmentProviders

class MyChannelFragment : ChannelFragment() {
    override fun showMediaSelectDialog() {
        AlertDialog.Builder(requireContext())
            .setItems(arrayOf("Gallery", "Document", "Share location")) { _, which ->
                when (which) {
                    0 -> takePhoto()
                    1 -> takeFile()
                    else -> { /* your own action */ }
                }
            }
            .show()
    }
}

FragmentProviders.channel = ChannelFragmentProvider { channelUrl, args ->
    ChannelFragment.Builder(channelUrl).withArguments(args)
        .setCustomFragment(MyChannelFragment())
        .build()
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/chat-input-menu) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/BaseMessageListFragment.java#L686) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/customization/channel/InputMenuSample.kt#L48)

**Add a button next to the input** — subclass `MessageInputComponent`, wrap the view that `super.onCreateView` returns, and register it on the module. The `onCreateView` Javadoc requires overriding `getRootView()` together with it (line 125).

```kotlin
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.LinearLayout
import com.sendbird.uikit.interfaces.providers.ChannelModuleProvider
import com.sendbird.uikit.modules.ChannelModule
import com.sendbird.uikit.modules.components.MessageInputComponent
import com.sendbird.uikit.providers.ModuleProviders

class InputWithExtraButton : MessageInputComponent() {
    private var root: View? = null

    override fun onCreateView(context: Context, inflater: LayoutInflater, parent: ViewGroup, args: Bundle?): View {
        val input = super.onCreateView(context, inflater, parent, args)
        val row = LinearLayout(context).apply { orientation = LinearLayout.HORIZONTAL }
        val extra = ImageButton(context).apply {
            setImageResource(android.R.drawable.ic_menu_mylocation)
            setOnClickListener { /* your action */ }
        }
        row.addView(extra, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        row.addView(input, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        root = row
        return row
    }

    override fun getRootView(): View? = root
}

ModuleProviders.channel = ChannelModuleProvider { context, _ ->
    ChannelModule(context).apply { setInputComponent(InputWithExtraButton()) }
}
```
This combines documented override points (`MessageInputComponent.onCreateView`/`getRootView`, `BaseMessageListModule.setInputComponent`). (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/MessageInputComponent.java#L125) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/BaseMessageListModule.java#L67)

**Turn the input off and on at runtime** — `MessageInputComponent.tryToChangeEnableStatus(channel, enabled, hintText)` (since 3.17.0) stores the requested state and hint, and they survive later channel updates. It returns `true` when the change was applied. While the user is muted, the channel is frozen (for non-operators), or the `ChannelConfig` disables input for the channel, UIKit keeps the input disabled whatever you pass.

```kotlin
import com.sendbird.android.channel.GroupChannel
import com.sendbird.uikit.fragments.ChannelFragment
import com.sendbird.uikit.modules.components.MessageInputComponent
import com.sendbird.uikit.vm.ChannelViewModel

class ReadOnlyWhenClosedFragment : ChannelFragment() {
    override fun onBindMessageInputComponent(
        inputComponent: MessageInputComponent, viewModel: ChannelViewModel, channel: GroupChannel?
    ) {
        super.onBindMessageInputComponent(inputComponent, viewModel, channel)
        if (channel != null && channel.customType == "closed") {
            inputComponent.tryToChangeEnableStatus(channel, false, "This conversation is closed")
        }
    }
}
```
Call it again later (for example from a channel event) through `module.messageInputComponent` with `enabled = true` to turn the input back on. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/MessageInputComponent.java#L534) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/MessageInputComponent.java#L572) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L500)

## Channel list: loading indicator, custom item, query filter (View host)
`ChannelListFragment` shows `StatusFrameView.Status.LOADING` from `onViewCreated` until the first channel list arrives, then `EMPTY` or `NONE` (lines 86, 153). The status view has theme attributes for background, text, and icons (`StatusComponent` styleable) but none for the spinner, so a different loading indicator means a custom `StatusComponent`:

```kotlin
import android.content.Context
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ProgressBar
import com.sendbird.uikit.interfaces.providers.ChannelListModuleProvider
import com.sendbird.uikit.modules.ChannelListModule
import com.sendbird.uikit.modules.components.StatusComponent
import com.sendbird.uikit.providers.ModuleProviders
import com.sendbird.uikit.widgets.StatusFrameView

class MyStatusComponent : StatusComponent() {
    private var root: FrameLayout? = null
    private var spinner: View? = null

    override fun onCreateView(context: Context, inflater: LayoutInflater, parent: ViewGroup, args: Bundle?): View {
        val defaultStatus = super.onCreateView(context, inflater, parent, args)
        val progress = ProgressBar(context)
        root = FrameLayout(context).apply {
            addView(defaultStatus)
            addView(progress, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        }
        spinner = progress
        return requireNotNull(root)
    }

    override fun getRootView(): View? = root

    override fun notifyStatusChanged(status: StatusFrameView.Status) {
        val loading = status == StatusFrameView.Status.LOADING
        spinner?.visibility = if (loading) View.VISIBLE else View.GONE
        // NONE makes the default status view GONE; the other states keep their error / empty UI.
        super.notifyStatusChanged(if (loading) StatusFrameView.Status.NONE else status)
        root?.visibility = if (loading || status != StatusFrameView.Status.NONE) View.VISIBLE else View.GONE
    }
}

ModuleProviders.channelList = ChannelListModuleProvider { context, _ ->
    ChannelListModule(context).apply { setStatusComponent(MyStatusComponent()) }
}
```
(source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelListFragment.java#L86) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/StatusComponent.java#L129) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/widgets/StatusFrameView.kt#L36) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/ChannelListModule.java#L132)

**Custom channel item** — subclass `ChannelListAdapter` and return a `BaseViewHolder<GroupChannel>`. The adapter's `onBindViewHolder` calls `holder.bind(channel)` and attaches the item click and long-click itself, so the default navigation keeps working. Keep the `ChannelListUIParams` the provider passes in, as the default provider does with `ChannelListAdapter(null, uiParams)`:

```kotlin
import android.view.ViewGroup
import android.widget.TextView
import com.sendbird.android.channel.GroupChannel
import com.sendbird.uikit.activities.adapter.ChannelListAdapter
import com.sendbird.uikit.activities.viewholder.BaseViewHolder
import com.sendbird.uikit.interfaces.providers.ChannelListAdapterProvider
import com.sendbird.uikit.model.ChannelListUIParams
import com.sendbird.uikit.providers.AdapterProviders

class MyChannelListAdapter(uiParams: ChannelListUIParams) : ChannelListAdapter(null, uiParams) {
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): BaseViewHolder<GroupChannel> =
        object : BaseViewHolder<GroupChannel>(TextView(parent.context)) {
            override fun bind(item: GroupChannel) {
                (itemView as TextView).text = "${item.name} (${item.unreadMessageCount})"
            }
        }
}

AdapterProviders.channelList = ChannelListAdapterProvider { uiParams -> MyChannelListAdapter(uiParams) }
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/channel-list-customization/channel-item-ui) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/adapter/ChannelListAdapter.java#L107) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/providers/AdapterProviders.kt#L177)

**Filter or sort the list** — pass a query built from `GroupChannelListQueryParams`:

```kotlin
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.channel.query.GroupChannelListQueryOrder
import com.sendbird.android.params.GroupChannelListQueryParams
import com.sendbird.uikit.fragments.ChannelListFragment
import com.sendbird.uikit.interfaces.providers.ChannelListFragmentProvider
import com.sendbird.uikit.providers.FragmentProviders

FragmentProviders.channelList = ChannelListFragmentProvider { args ->
    ChannelListFragment.Builder().withArguments(args)
        .setGroupChannelListQuery(
            GroupChannel.createMyGroupChannelListQuery(
                GroupChannelListQueryParams().apply {
                    includeEmpty = false
                    customTypesFilter = listOf("support")
                    order = GroupChannelListQueryOrder.LATEST_LAST_MESSAGE
                }
            )
        )
        .build()
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/channel-list-customization/filter-channel-list) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelListFragment.java#L572) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/customization/channellist/ChannelItemFilteringSample.kt#L24)

## Channel list: what a tap opens (View host)
By default a tap on a channel row starts UIKit's `ChannelActivity` for that channel. A listener set with `ChannelListFragment.Builder.setOnItemClickListener(...)` replaces that: `onItemClicked` calls your listener and returns without starting the default screen. Register it through `FragmentProviders.channelList` so every channel list uses it.

```kotlin
import com.sendbird.uikit.fragments.ChannelListFragment
import com.sendbird.uikit.interfaces.providers.ChannelListFragmentProvider
import com.sendbird.uikit.providers.FragmentProviders

// Once, in Application.onCreate():
fun openChannelsInMyScreen(openChat: (channelUrl: String) -> Unit) {
    FragmentProviders.channelList = ChannelListFragmentProvider { args ->
        ChannelListFragment.Builder().withArguments(args)
            .setUseHeader(true)
            .setOnItemClickListener { _, _, channel -> openChat(channel.url) }
            .build()
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelListFragment.java#L286-L292 — `onItemClicked`; the default `startChannelActivity` at lines 178-186; `Builder.setOnItemClickListener` at line 546) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/providers/FragmentProviders.kt#L255-L257 — the default `channelList` provider) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/global-customization/fragments)

## Header (View host)
- Simple changes go through `ChannelFragment.Builder`: `setUseHeader(false)` removes the header, `setHeaderTitle(...)` fixes the title, `setUseHeaderLeftButton` / `setUseHeaderRightButton` turn the buttons on or off, `setHeaderLeftButtonIcon(resId, tint)` changes the icon, and `setOnHeaderLeftButtonClickListener { }` replaces the default action (finishing the Activity). `ChannelListFragment.Builder` has the same set. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1241) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelListFragment.java#L389)
- A fully custom header is a `ChannelHeaderComponent` subclass set with `ChannelModule.setHeaderComponent(...)`. Fill it from `notifyChannelChanged(channel)` and `notifyHeaderDescriptionChanged(description)` (the description carries the typing indicator text). Call `onLeftButtonClicked(view)` from your back button to run the listener the fragment bound, which finishes the Activity by default.

```kotlin
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.sendbird.android.channel.GroupChannel
import com.sendbird.uikit.interfaces.providers.ChannelModuleProvider
import com.sendbird.uikit.modules.ChannelModule
import com.sendbird.uikit.modules.components.ChannelHeaderComponent
import com.sendbird.uikit.providers.ModuleProviders

class MyHeaderComponent : ChannelHeaderComponent() {
    private var root: View? = null
    private var title: TextView? = null
    private var subtitle: TextView? = null

    override fun onCreateView(context: Context, inflater: LayoutInflater, parent: ViewGroup, args: Bundle?): View {
        val back = TextView(context).apply { text = "Back"; setOnClickListener { onLeftButtonClicked(it) } }
        title = TextView(context)
        subtitle = TextView(context)
        root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            addView(back); addView(title); addView(subtitle)
        }
        return requireNotNull(root)
    }

    override fun getRootView(): View? = root

    override fun notifyChannelChanged(channel: GroupChannel) {
        title?.text = channel.name
    }

    override fun notifyHeaderDescriptionChanged(description: String?) {
        subtitle?.visibility = if (description.isNullOrEmpty()) View.GONE else View.VISIBLE
        subtitle?.text = description
    }
}

ModuleProviders.channel = ChannelModuleProvider { context, _ ->
    ChannelModule(context).apply { setHeaderComponent(MyHeaderComponent()) }
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/chat-header) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/ChannelHeaderComponent.java#L76) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/HeaderComponent.java#L136) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L242) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/customization/channel/ChannelHeaderSample.kt#L52)

**Typing text color in the default header.** The header's second line is where UIKit shows the typing text: when the typing indicator is on with the `TEXT` type, `ChannelFragment` passes the text built from the `sb_text_channel_typing_indicator_*` strings to `notifyHeaderDescriptionChanged(description)`. That line is styled by the `sb_appbar_description_appearance` item of the header style, which is `Component.Header.Channel` in Light mode and `Component.Dark.Header.Channel` in Dark mode. Declare a style with the same name in your app to replace it. Your style replaces UIKit's whole style, so copy UIKit's other items too:

```xml
<!-- app/src/main/res/values/styles.xml -->
<style name="Component.Header.Channel">
    <item name="sb_appbar_description_appearance">@style/MyTypingText</item>
    <item name="sb_appbar_right_button_icon">@drawable/icon_info</item>
    <item name="sb_appbar_right_button_tint">@color/primary_main</item>
    <item name="sb_appbar_right_button_background">@drawable/sb_button_uncontained_background_light</item>
</style>

<style name="MyTypingText">
    <item name="android:textColor">#FF742DDD</item>
</style>
```
The header applies the appearance and then sets a fixed text size (`HeaderView.kt` lines 118-119), so `android:textSize` in your appearance has no effect in 3.26.3. For another size or font, replace the header with a custom `ChannelHeaderComponent` as shown above. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/style-resources) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/values/styles.xml#L250-L255) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/values/styles_dark.xml#L362-L367) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/internal/ui/components/HeaderView.kt#L97-L119) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L248-L256) (community context: https://github.com/sendbird/sendbird-uikit-android/discussions/29)

**Long channel names are cut to one line.** This is the layout, not a bug: the channel list row title is `singleLine` with `ellipsize="end"` (`sb_view_channel_list_item.xml` line 32-40), and the channel header title is `maxLines="1"` with `ellipsize="end"` (`sb_view_header.xml` line 54-59). To show more of the name, render the row with a custom channel item (see "Channel list" above) or the header with a custom `ChannelHeaderComponent`. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/layout/sb_view_channel_list_item.xml#L32-L40) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/layout/sb_view_header.xml#L54-L59) (community context: https://github.com/sendbird/sendbird-uikit-android/discussions/28)

## Start a 1:1 chat from a button (no channel list)
For a "Chat with seller" button: create the channel with `isDistinct = true`, which returns the existing 1:1 channel when one already has the same members, and start `ChannelActivity` for its URL. Back returns to your screen. To open the same channel from a notification tap, wrap the same `ChannelActivity.newIntent(context, channelUrl)` in the notification's `PendingIntent`, so the tap opens the channel with no list in between. The public UIKit sample wraps `ChannelListActivity.newRedirectToChannelIntent(context, channelUrl)` instead, which opens the list and moves into the channel, so back lands on the list; use that only when the customer wants the list behind the channel.

```kotlin
import android.app.PendingIntent
import android.content.Context
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.params.GroupChannelCreateParams
import com.sendbird.uikit.activities.ChannelActivity

fun Activity.openChatWith(sellerUserId: String) {
    val params = GroupChannelCreateParams().apply {
        userIds = listOf(sellerUserId)
        isDistinct = true   // same members -> the existing channel comes back
    }
    GroupChannel.createChannel(params) { channel, e ->
        if (e != null || channel == null) return@createChannel
        startActivity(ChannelActivity.newIntent(this, channel.url))
    }
}

// In your push handler: data["sendbird"] is JSON whose channel object holds channel_url.
// The tap opens the channel screen itself, the same screen the button opens.
fun channelTapIntent(context: Context, channelUrl: String, requestCode: Int): PendingIntent {
    val intent = ChannelActivity.newIntent(context, channelUrl)
    return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_IMMUTABLE)
}
```
(source: knowledge/curated/android/products/chat.md — Create and list group channels) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/common/fcm/MyFirebaseMessagingService.kt#L54-L117 — reads `data["sendbird"]`, takes the channel URL, and builds the tap `PendingIntent`; the sample uses a redirect intent through the list with `FLAG_ACTIVITY_CLEAR_TOP`) (uikit 3.26.3 AAR `javap` on `com.sendbird.uikit.activities.ChannelActivity` and `com.sendbird.uikit.activities.ChannelListActivity`: `newIntent(Context, String)`, `newRedirectToChannelIntent(Context, String)`)

## Message menu and message taps (View host)
A long press on a message opens the message menu, which `makeMessageContextMenu(message)` builds as a list of `DialogListItem`s; each item is identified by its string resource key, such as `R.string.sb_text_channel_anchor_edit`. To change the menu, subclass `ChannelFragment`, filter or add items in `makeMessageContextMenu`, and handle your own items in `onMessageContextMenuItemClicked` (return `true` when you handled it). Install the subclass with `ChannelFragment.Builder(channelUrl).setCustomFragment(...)`, usually inside `FragmentProviders.channel`.

To replace a tap or long press completely, set `setOnMessageClickListener` or `setOnMessageLongClickListener` on the builder. When a long-click listener is set, UIKit calls it and does not open the menu; a click listener likewise replaces the default action, such as opening a photo. The builder also has listeners for profile, mention, quote-reply, thread-info, and reaction taps. Click events fire only for UIKit's default message views, not for views you replaced.

```kotlin
import android.view.View
import com.sendbird.android.message.BaseMessage
import com.sendbird.uikit.R
import com.sendbird.uikit.fragments.ChannelFragment
import com.sendbird.uikit.interfaces.providers.ChannelFragmentProvider
import com.sendbird.uikit.model.DialogListItem
import com.sendbird.uikit.providers.FragmentProviders

class NoEditChannelFragment : ChannelFragment() {
    override fun makeMessageContextMenu(message: BaseMessage): MutableList<DialogListItem> =
        super.makeMessageContextMenu(message).filterTo(mutableListOf()) {
            it.key != R.string.sb_text_channel_anchor_edit
        }

    override fun onMessageContextMenuItemClicked(message: BaseMessage, view: View, position: Int, item: DialogListItem): Boolean {
        return super.onMessageContextMenuItemClicked(message, view, position, item)
    }
}

// Once, in Application.onCreate():
fun useNoEditMenu() {
    FragmentProviders.channel = ChannelFragmentProvider { channelUrl, args ->
        ChannelFragment.Builder(channelUrl).withArguments(args)
            .setCustomFragment(NoEditChannelFragment())
            .setUseHeader(true)
            .build()
    }
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/message-context-menu) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/message-click-events) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/BaseMessageListFragment.java#L329-L337 — a long-click listener skips the menu; click listener at lines 238-242) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L778-L790 — the default items) (source: uikit 3.26.3 AAR, `javap` on `com.sendbird.uikit.fragments.ChannelFragment$Builder` — `setOnMessageClickListener`, `setOnMessageLongClickListener`; `com.sendbird.uikit.model.DialogListItem`)

## Message threads (View host)
Threads are off until you set the reply type. With `UIKitConfig.groupChannelConfig.replyType = ReplyType.THREAD`, the message menu shows "Reply in thread" and opens UIKit's thread screen (`MessageThreadActivity`). `threadReplySelectType` decides what a tap on a reply in the channel opens: `ThreadReplySelectType.THREAD` opens the thread, `PARENT` scrolls to the parent message. Threads are one level deep, and they work in group and supergroup channels only. To keep replies out of the main list, see "Thread replies show up in the main UIKit message list" in knowledge/curated/android/cross-cutting/troubleshooting.md.

```kotlin
import com.sendbird.uikit.consts.ReplyType
import com.sendbird.uikit.consts.ThreadReplySelectType
import com.sendbird.uikit.model.configurations.UIKitConfig

// Once, in Application.onCreate(), after SendbirdUIKit.init(...):
fun turnOnThreads() {
    UIKitConfig.groupChannelConfig.replyType = ReplyType.THREAD
    UIKitConfig.groupChannelConfig.threadReplySelectType = ThreadReplySelectType.THREAD
}
```
The thread screen's header and input are `MessageThreadHeaderComponent` and `MessageThreadInputComponent` of `MessageThreadModule`; replace them through `ModuleProviders.messageThread`. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/features/message-threading/threads) (source: uikit 3.26.3 AAR, `javap` on `com.sendbird.uikit.model.configurations.ChannelConfig` — `setReplyType`, `setThreadReplySelectType`) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/providers/ModuleProviders.kt#L205)

## Channel settings and member list (View host)
The settings screen lists `ChannelSettingsMenuComponent.Menu` items in the order of `ChannelSettingsMenuComponent.defaultMenuSet`: `MODERATIONS` (operators only), `NOTIFICATIONS`, `MEMBERS`, `SEARCH_IN_CHANNEL`, and `LEAVE_CHANNEL`. To remove, reorder, or add rows (since 3.16.0), give a new `ChannelSettingsMenuComponent` a list through `params.setMenuList(list, provider)` and set it on the module through `ModuleProviders.channelSettings`. A `CUSTOM` entry needs the provider, which returns the row's view; build it with `createMenuView(...)` and handle its clicks yourself. On the member list, `MemberListFragment.Builder.setUseHeaderRightButton(false)` hides the invite button.

```kotlin
import com.sendbird.uikit.fragments.MemberListFragment
import com.sendbird.uikit.interfaces.providers.ChannelSettingsModuleProvider
import com.sendbird.uikit.interfaces.providers.MemberListFragmentProvider
import com.sendbird.uikit.modules.ChannelSettingsModule
import com.sendbird.uikit.modules.components.ChannelSettingsMenuComponent
import com.sendbird.uikit.providers.FragmentProviders
import com.sendbird.uikit.providers.ModuleProviders

// Once, in Application.onCreate():
fun customizeSettingsScreens() {
    ModuleProviders.channelSettings = ChannelSettingsModuleProvider { context, _ ->
        ChannelSettingsModule(context).apply {
            val menus = ChannelSettingsMenuComponent.defaultMenuSet.toMutableList().apply {
                remove(ChannelSettingsMenuComponent.Menu.LEAVE_CHANNEL)
            }
            setChannelSettingsMenuComponent(ChannelSettingsMenuComponent().apply { params.setMenuList(menus, null) })
        }
    }
    FragmentProviders.memberList = MemberListFragmentProvider { channelUrl, args ->
        MemberListFragment.Builder(channelUrl).withArguments(args)
            .setUseHeaderRightButton(false)
            .build()
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/modules/components/ChannelSettingsMenuComponent.java#L42-L87 — `Menu` and `defaultMenuSet`; moderation shown only to operators at line 206; `setMenuList` at line 357) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/group-channel-screens/configure-group-channel-settings) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/customization/channelsettings/GroupChannelSettingSample.kt#L89-L103) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/tutorial/customize-channel-settings) (source: uikit 3.26.3 AAR, `javap` on `com.sendbird.uikit.modules.ChannelSettingsModule` — `setChannelSettingsMenuComponent`; `ChannelSettingsMenuComponent$Params` — `setMenuList`; `MemberListFragment$Builder` — `setUseHeaderRightButton`)

## Theme + push (optional)
- `SendbirdUIKit.setDefaultThemeMode(...)` for light/dark.
- Push via `SendbirdPushHelper` (FCM). (source: sendbird-uikit-android uikit-samples BaseApplication.kt)

## Right-to-left (RTL) languages
UIKit for Android supports right-to-left languages from 3.19.0 on. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/CHANGELOG.md, entry `v3.19.0 (Aug 1, 2024)`: "Support Right-to-Left (RTL) languages.")

The host app turns RTL on, not UIKit. The `<application>` element of the `uikit-3.26.3.aar` manifest has no `android:supportsRtl` attribute, and Android's default for that attribute is `false`, which keeps every layout left-to-right. Set it in the app manifest, with a `targetSdkVersion` of 17 or higher, then run the app with an RTL locale (for example Arabic or Hebrew). (source: `AndroidManifest.xml` inside https://repo.sendbird.com/public/maven/com/sendbird/sdk/uikit/3.26.3/uikit-3.26.3.aar, checked 2026-10-19; https://developer.android.com/guide/topics/manifest/application-element, entry `android:supportsRtl`)

```xml
<application
    android:supportsRtl="true"
    ... >
```
(source: the same attribute in the sample app manifest, https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit-samples/src/main/AndroidManifest.xml line 16)

- UIKit's own layouts are mostly written with start/end attributes: 62 of the 127 layout files in `uikit-3.26.3.aar` use `layout_marginStart`, `layout_marginEnd`, `paddingStart`, `paddingEnd`, `layout_alignParentStart`, `layout_alignParentEnd`, `layout_toStartOf`, or `layout_toEndOf`, so they mirror under an RTL locale. One layout, `res/layout/sb_view_channel_list_item.xml`, still sets `layout_marginLeft` and `layout_marginRight` (lines 18-19 and 35-36). (source: `res/layout` inside `uikit-3.26.3.aar`, counted 2026-10-19)
- The message input handles mixed-direction text when a mention is inserted. `MentionEditText` picks a right-to-left mark (RLM, `\u200F`) or a left-to-right mark (LRM, `\u200E`) from the text direction at the cursor, so that typing "input" and then selecting a mention gives "input userId@" instead of "userIdinput@" in an RTL language. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/widgets/MentionEditText.java lines 373-379; the `RLM` and `LRM` fields are present in `com.sendbird.uikit.widgets.MentionEditText` of `uikit-3.26.3.aar`, read with `javap`)
- In custom views you add to UIKit (custom message views, header views, channel list items), use `start` and `end` attributes instead of `left` and `right`, so they mirror with the rest of the screen. This is general Android practice, not a UIKit API, and the UIKit layouts above follow it.

Not verified: the public Sendbird docs (checked against `https://sendbird.com/llms-full.txt`, 2026-10-19) have no UIKit Android RTL page, and a code search of `sendbird/sendbird-uikit-android` for "rtl" (2026-10-19) returns only four files: the CHANGELOG, `MentionEditText`, the sample manifest, and `strings.xml` (where "rtl" is just part of the word "shortly"). No RTL-specific public API or setting turned up, so do not tell the customer to call an RTL option in `SendbirdUIKit`.

## Pitfalls
- Provide a non-null `getUserInfo().getUserId()`; UIKit needs the current user.
- App ID from BuildConfig/secret; access token is a secret — never hard-code.
- View-based — Compose apps host the fragments/activities via interop, or use the Compose-native UIKit (`uikit-compose`, knowledge/curated/android/hosts/compose.md), which has its own customization API.

## Related
- Repo: https://github.com/sendbird/sendbird-uikit-android
- Overview docs: https://sendbird.com/docs/uikit/v3/android/overview
- Underlying Chat: knowledge/curated/android/products/chat.md
