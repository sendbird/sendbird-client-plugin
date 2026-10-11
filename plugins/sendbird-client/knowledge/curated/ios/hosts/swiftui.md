<!-- last-verified-against: sendbird-swiftui-ios 1.2.2 / sendbird-calls-ios 1.12.3 / sendbird-live-sdk-ios 1.6.0 -->
<!-- status: populated -->
# ios host — SwiftUI

> Host guidance. The SendbirdSwiftUI sections are read from the public `sendbird-swiftui-ios` 1.2.2 package (swiftinterface and source) and their snippet is build-verified (xcodebuild). Verified 2026-09-30. The customization sections (message views, input, channel list, header, theme) were read from the 1.2.2 `.swiftinterface`, the public sample app at tag `1.2.2`, and the SwiftUI docs, and every example builds with `tools/curated/compile-snippets-ios.sh` (verified 2026-10-11).

## Detection signals
- `import SwiftUI`, `App` protocol with `@main`, `WindowGroup`, `some View`, `@UIApplicationDelegateAdaptor` for an AppDelegate bridge.

## Integration notes
- Sendbird UIKit (`SendbirdUIKit`) and AI Agent screens are UIViewController-based. Wrap them in `UIViewControllerRepresentable` (standard interop, not an SDK API).
- Calls and Live ship no prebuilt screens; their video views (`SendBirdVideoView` in SendBirdCalls, `SendbirdVideoView` in SendbirdLiveSDK) are UIViews, so wrap them in `UIViewRepresentable`. Desk is headless and needs no wrapper. (source: SendBirdCalls.swiftinterface (1.12.3) line 450; SendbirdLiveSDK.swiftinterface (1.6.0) line 606; build-verified SwiftUI templates in templates/ios/swiftui/calls, templates/ios/swiftui/live, templates/ios/swiftui/desk)
- Chat also ships SwiftUI-native views in the separate `SendbirdSwiftUI` package; see SwiftUI-native chat views (SendbirdSwiftUI) below. A build-verified template is in templates/ios/swiftui/uikit.
- The AI Agent floating launcher attaches to the window, so it works from a SwiftUI app run from an `@UIApplicationDelegateAdaptor` AppDelegate (see products/ai-agent.md + templates/ios/swiftui/ai-agent/_README.md).
- Init/connect/auth APIs are identical to the UIKit host.

## SwiftUI-native chat views (SendbirdSwiftUI)

Sendbird ships SwiftUI views for Chat in a separate package: add `https://github.com/sendbird/sendbird-swiftui-ios` and use the product `SendbirdSwiftUI` (iOS 15+). The docs state it currently supports iPhone only, not iPad. Views such as `GroupChannelListView` are SwiftUI `View`s, so they need no `UIViewControllerRepresentable` wrapper.

(source: sendbird/sendbird-swiftui-ios Package.swift (1.2.2); SendbirdSwiftUI.swiftinterface (1.2.2) line 897; https://sendbird.com/docs/chat/uikit/v3/swiftui/essentials/installation)

## Switching users and keeping custom views

When the signed-in user changes, bind the Sendbird root view's identity to the user ID with SwiftUI's `.id(_:)`; a new identity makes SwiftUI rebuild the view and reset its state, so the next user starts from a fresh `GroupChannelListView`. SendbirdSwiftUI resets customized view adaptors whenever a SendbirdSwiftUI view's `onDisappear` is called; to keep them, set `GlobalOptions.enableViewAdaptorAutoReset = false` before that view appears (for app-wide behavior, before `SendbirdUI.initialize`).

```swift
import SwiftUI
import SendbirdSwiftUI

// Call once at launch (e.g. from application(_:didFinishLaunchingWithOptions:)),
// before any SendbirdSwiftUI view appears.
func configureSendbird() {
    GlobalOptions.enableViewAdaptorAutoReset = false
    SendbirdUI.initialize(applicationId: "APP_ID") { error in }
}

struct ChatRoot: View {
    let userId: String
    var body: some View {
        GroupChannelListView()
            .id(userId)   // new user ID -> new view identity -> fresh state
    }
}
```

(source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 673–674, 897–898, 21358; sendbird/sendbird-swiftui-ios@1.2.2 Sources/SwiftUI/Common/GlobalOptions.swift lines 13–17; https://developer.apple.com/documentation/swiftui/view/id(_:))

## Customizing SendbirdSwiftUI views

SendbirdSwiftUI views take item builders: `headerItem`, `listItem`, and (on `GroupChannelView`) `inputItem`. Each builder method replaces one part of the screen with your SwiftUI view and hands you a `config` with the data for that part. If you customize a parent part, your customizations of its child parts are not applied. For example, a custom `titleView` ignores a custom `titleLabel`. The docs say neither screen supports replacing the whole screen yet. The public sample app has one file per builder.

| Screen | Builder | Parts you can replace |
| --- | --- | --- |
| `GroupChannelView` | `headerItem` | `leftView`, `rightView`, `titleView` (children `coverImage`, `titleLabel`, `typingStatusView`) |
| `GroupChannelView` | `listItem` | `rowView` (children `senderProfileImage`, `userMessageView`, `fileMessageView`, `multipleFilesMessageView`, `adminMessageView`, `quotedFileMessageView`, `quotedMultipleFilesMessageView`, `typingIndicatorView`), `newMessageInfoView`, `scrollBottomView`, `channelStateBanner` |
| `GroupChannelView` | `inputItem` | `topView`, `leftView` (child `addButton`), `rightView` (children `sendButton`, `voiceButton`) |
| `GroupChannelListView` | `headerItem` | `leftView`, `rightView`, `titleView` |
| `GroupChannelListView` | `listItem` | `rowView` (children `coverImage`, `channelName`, `channelPreview`, `unreadCount`) |

(source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 873–890 (channel list items), 1579–1617 (channel items), 907 and 1634 (view initializers); source: https://github.com/sendbird/sendbird-swiftui-ios/tree/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews (the sample app, one file per builder); source: https://sendbird.com/docs/chat/uikit/v3/swiftui/group-channel-views/chat-in-group-channel and https://sendbird.com/docs/chat/uikit/v3/swiftui/group-channel-views/list-channels)

### Custom message views, including file messages and reply thumbnails

`userMessageView` gets the `UserMessage` and a `maxWidth`. `fileMessageView` gets the `FileMessage`, its `fileType`, a `thumbnailSize`, and a `maxWidth`. `quotedFileMessageView` draws the file preview inside a reply (the quoted message above the reply text). It gets the quoted `FileMessage`, `fileType`, `thumbnailSize`, and `iconSize`.

```swift
import SwiftUI
import SendbirdSwiftUI

struct BrandedChannelScreen: View {
    @StateObject private var provider: GroupChannelViewProvider

    init(channelURL: String) {
        _provider = StateObject(wrappedValue: GroupChannelViewProvider(channelURL: channelURL))
    }

    var body: some View {
        GroupChannelView(
            provider: provider,
            listItem: {
                .init()
                .userMessageView { config in
                    Text(config.message.message)
                        .frame(maxWidth: config.maxWidth, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.indigo.opacity(0.15)))
                }
                .fileMessageView { config in
                    switch config.fileType {
                    case .image:
                        AsyncImage(url: URL(string: config.message.url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: config.thumbnailSize.width, height: config.thumbnailSize.height)
                        .clipped()
                    case .video:
                        ZStack {
                            AsyncImage(url: URL(string: config.message.thumbnails?.first?.url ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            Image(systemName: "play.circle.fill").font(.largeTitle)
                        }
                        .frame(width: config.thumbnailSize.width, height: config.thumbnailSize.height)
                        .clipped()
                    default:
                        Label(config.message.name, systemImage: "doc")
                            .frame(maxWidth: config.maxWidth, alignment: .leading)
                    }
                }
                .quotedFileMessageView { config in
                    if config.fileType == .image {
                        AsyncImage(url: URL(string: config.message.url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: config.thumbnailSize.width, height: config.thumbnailSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "doc")
                            .frame(width: config.iconSize.width, height: config.iconSize.height)
                    }
                }
            }
        )
    }
}
```
Loading `config.message.url` (the original file) instead of a server thumbnail is one way to avoid soft-looking images. The UIKit section on thumbnails explains why they can look soft (knowledge/curated/ios/products/uikit.md, "Media: thumbnails and video"). (source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 1596–1600 (builders), 1800–1832 (`UserMessage`, `FileMessage`, and `QuotedFileMessage` view configs), 9588 (`SBUMessageFileType`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Enums/SBUEnums.swift#L228-L235 (the same `SBUMessageFileType` cases in the UIKit core); source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/GroupChannel/ViewConverter/List/CustomGroupChannel.ViewConverter.List.fileMessageView.swift#L28-L53; source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/GroupChannel/ViewConverter/List/CustomGroupChannel.ViewConverter.List.quotedFileMessageView.swift#L28-L57)

### Message input: custom buttons and attachment options

`inputItem.leftView` replaces the whole area left of the text field, including the "+" button, so your buttons run only your actions. `inputItem.addButton` only restyles the "+" button. The public sample notes that the default attachment action still runs. The `config` tells you whether the channel is frozen or you are muted.

```swift
import SwiftUI
import SendbirdSwiftUI

struct ChannelWithStickerButton: View {
    @StateObject private var provider: GroupChannelViewProvider
    @State private var showsStickers = false

    init(channelURL: String) {
        _provider = StateObject(wrappedValue: GroupChannelViewProvider(channelURL: channelURL))
    }

    var body: some View {
        GroupChannelView(
            provider: provider,
            inputItem: {
                .init()
                .leftView { config in
                    HStack(spacing: 8) {
                        Button {
                            provider.showPhotosLibrary()   // photos only, instead of the full "+" sheet
                        } label: {
                            Image(systemName: "photo")
                                .resizable()
                                .frame(width: config.buttonSize.width, height: config.buttonSize.width)
                        }
                        Button {
                            showsStickers = true
                        } label: {
                            Image(systemName: "face.smiling")
                                .resizable()
                                .frame(width: config.buttonSize.width, height: config.buttonSize.width)
                        }
                    }
                    .frame(height: config.buttonSize.height)
                    .disabled(config.isFrozen || config.isMuted)
                }
            }
        )
        .sheet(isPresented: $showsStickers) {
            Text("Sticker picker")
        }
    }
}
```
`GroupChannelViewProvider` also exposes `showResourcePicker()`, `showCamera()`, `showPhotosLibrary()`, and `showDocumentsPicker()`, so a replaced left area can still offer only the attachment types you want. The attachment options in the default "+" sheet use the same settings as UIKit: `SendbirdUI.config.groupChannel.channel.input` (`camera`, `gallery`, `isDocumentEnabled`). Set them at launch, before the views appear. (source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 1607–1617 (input builders), 1698–1712 (`LeftView` and `RightView` view configs), 1158–1161 (provider picker methods), 8140–8147 (`SBUConfig.BaseInput`), 21356 (`SendbirdUI.config`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Configuration/SBUConfig.Base.swift#L13-L74 (the same input settings in the UIKit core); source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/GroupChannel/ViewConverter/Input/CustomGroupChannel.ViewConverter.Input.addButton.swift#L28-L30; source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/GroupChannel/ViewConverter/Input/CustomGroupChannel.ViewConverter.Input.leftView.swift#L27-L30)

### Channel list: search field, loading indicator, list item

`GroupChannelListView` has no search item of its own. Its header builders are `leftView`, `rightView`, and `titleView`. To search, put your own text field next to the list and rebuild the list with a channel-name filter when the user submits. `GroupChannelListViewProvider` is an `ObservableObject` with a published `isLoading`, so an overlay can show your own spinner while the list loads.

```swift
import SwiftUI
import SendbirdSwiftUI
import SendbirdChatSDK

struct SearchableChannelList: View {
    @State private var draft = ""
    @State private var keyword = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search channels", text: $draft)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { keyword = draft }
                .padding(.horizontal)
            FilteredChannelList(keyword: keyword)
                .id(keyword)   // new keyword -> new view identity -> new provider and query
        }
    }
}

struct FilteredChannelList: View {
    @StateObject private var provider: GroupChannelListViewProvider

    init(keyword: String) {
        let params = GroupChannelListQueryParams()
        params.channelNameContainsFilter = keyword.isEmpty ? nil : keyword
        let query = GroupChannel.createMyGroupChannelListQuery(params: params)
        _provider = StateObject(wrappedValue: GroupChannelListViewProvider(channelListQuery: query))
    }

    var body: some View {
        GroupChannelListView(
            provider: provider,
            listItem: {
                .init()
                .channelName { config in
                    Text(config.channelName).font(.headline)
                }
            }
        )
        .overlay {
            if provider.isLoading {
                ProgressView()
            }
        }
    }
}
```
`.id(_:)` gives the list a new identity for each keyword, so SwiftUI creates a new `FilteredChannelList` with a fresh provider. This is SwiftUI behavior, not an SDK API (see "Switching users and keeping custom views" above). The channel-name filter is the Chat SDK's `GroupChannelListQueryParams.channelNameContainsFilter` (SendbirdChatSDK 4.39.11 `.swiftinterface`). (source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 877–890 (channel list builders), 973–977 (`ChannelName` view config), 997–1027 (`GroupChannelListViewProvider`: `channels`, `isLoading`, `init(channelListQuery:)`), 21650 (`ObservableObject`); source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/GroupChannelList/ViewProvider/CustomGroupChannelList.SwiftUI.View.ViewProvider.swift#L15-L34; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/ChannelList/SBUGroupChannelListViewModel.swift#L125 (`GroupChannel.createMyGroupChannelListQuery(params:)`); source: https://sendbird.com/docs/chat/uikit/v3/swiftui/group-channel-views/list-channels)

### Header

```swift
import SwiftUI
import SendbirdSwiftUI

struct ChannelWithCustomHeader: View {
    @StateObject private var provider: GroupChannelViewProvider

    init(channelURL: String) {
        _provider = StateObject(wrappedValue: GroupChannelViewProvider(channelURL: channelURL))
    }

    var body: some View {
        GroupChannelView(
            provider: provider,
            headerItem: {
                .init()
                .titleLabel { config in
                    Text(config.channel.name).font(.headline)
                }
                .rightView { _ in
                    Button {
                        // Your action.
                    } label: {
                        Image(systemName: "phone")
                    }
                }
            }
        )
    }
}
```
(source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 1579–1589 (header builders), 1648–1683 (header view configs); source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/GroupChannel/ViewConverter/Header/CustomGroupChannel.ViewConverter.Header.titleLabel.swift#L27-L33)

### Theme, dark mode, strings

SendbirdSwiftUI is built on Sendbird UIKit, so it uses the same `SBUTheme`, `SBUColorSet`, `SBUFontSet`, and `SBUStringSet`. Their properties take `UIColor` and `UIFont`. The package adds `asUIColor()` on `Color` and `asUIFont()` on `Font` to convert. The docs say to set the theme before SendbirdSwiftUI is initialized, and to call `SBUTheme.set(theme:)` again when you change it at runtime. To restyle a screen that is already showing, set the theme first and then give the root view a new identity.

```swift
import SwiftUI
import SendbirdSwiftUI

func applyBrandTheme(isDark: Bool) {
    SBUTheme.set(colorScheme: isDark ? .dark : .light)   // resets the component themes
    SBUTheme.groupChannelCellTheme.titleFont = Font.headline.asUIFont()
    SBUTheme.groupChannelCellTheme.backgroundColor = Color(.systemBackground).asUIColor()
}

struct ThemedChatRoot: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var themeVersion = 0

    var body: some View {
        GroupChannelListView()
            .id(themeVersion)
            .onChange(of: colorScheme) { newValue in
                applyBrandTheme(isDark: newValue == .dark)
                themeVersion += 1   // rebuild only after the new theme is set
            }
    }
}
```
Call `applyBrandTheme(isDark:)` once at launch as well. For strings, fonts, and colors, the rules in knowledge/curated/ios/cross-cutting/theme.md apply unchanged. (source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 18900–18903 (`SBUTheme.set(theme:)`, `set(colorScheme:)`), 102 (`asUIColor()`), 21462 (`asUIFont()`), 7890 (`SBUColorSet`), 10123 (`SBUFontSet`), 18454 (`SBUStringSet`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUColorSet.swift#L14; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUFontSet.swift#L15; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Constant/SBUStringSet.swift#L17; source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sample/QuickStartSwiftUI/CustomSample/CustomViews/Theme/Theme/Custom/CustomTheme.Theme.Custom.Main.swift#L25-L29; source: https://sendbird.com/docs/chat/uikit/v3/swiftui/theme-and-style-resources/theme-resources)

Not covered here: a SwiftUI-level way to disable the message input from app logic. `SBUMessageInputView.setInputState(_:placeholder:)` exists in the package, but no `inputItem` builder or provider property hands you that input view. (source: SendbirdSwiftUI.swiftinterface (1.2.2) line 13999; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L1162)

## Related
- UIKit host: knowledge/curated/ios/hosts/uikit.md
- AI Agent: knowledge/curated/ios/products/ai-agent.md
