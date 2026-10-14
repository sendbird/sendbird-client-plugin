<!-- last-verified-against: sendbird-uikit-ios 3.36.1 -->
<!-- status: populated -->
# ios uikit

> Verified against the public mirror `sendbird/sendbird-uikit-ios` (README quickstart + QuickStart sample, verified 2026-06-09). init + currentUser + channel list build-verified locally (xcodebuild). The customization sections (message cells, input bar, channel list, header, media) were read from the public source at tag `3.36.1` and the UIKit v3 iOS docs, and every example builds with `tools/curated/compile-snippets-ios.sh` (verified 2026-10-11). The sections that cite a GitHub discussion as community context were added on 2026-10-12: each was re-read from the public source at tag `3.36.1` (identical to `3.36.2` under `Sources/`) and the 3.36.2 public `.swiftinterface`, and builds the same way. Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-uikit-ios

## Overview
Sendbird UIKit gives prebuilt chat screens (channel list, conversation, settings) on top of Chat. Initialize UIKit, set the current user, then present the provided view controllers.

The installation guide states that UIKit for iOS currently supports iPhone only, not iPad, so problems that appear only on iPad are outside what UIKit supports. The SwiftUI package has the same limit (knowledge/curated/ios/hosts/swiftui.md). (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/essentials/installation)

## Install (SPM — prefer over CocoaPods)
- SPM package `https://github.com/sendbird/sendbird-uikit-ios-spm`, products `SendbirdUIKit` (+ `SendbirdUIMessageTemplate`). `import SendbirdUIKit`.

## Initialize (once, at launch)
```swift
import SendbirdUIKit

SendbirdUI.initialize(applicationId: APP_ID) {
    // initialization started
} migrationHandler: {
    // DB migration progress
} completionHandler: { error in
    // ready when error == nil
}
```
(source: sendbird-uikit-ios README §getting-started; build-verified)

**Init parameters and code that runs before init finishes.** UIKit builds the Chat SDK `InitParams` itself, with local caching on and `needsSynchronous` set to `true`. To change a parameter, use the variant with `initParamsBuilder`. Since 3.33.1, UIKit turns local caching back on even if the builder sets `isLocalCachingEnabled` to `false`. The Chat docs say that `needsSynchronous = true` makes the local cache migration finish before the app is fully launched, and that `false` lets the migration run asynchronously so initialization takes less time.

```swift
import SendbirdUIKit
import SendbirdChatSDK

SendbirdUI.initialize(applicationId: APP_ID) { params in
    params?.needsSynchronous = false
} startHandler: {
    // initialization started, for example show a loading view
} migrationHandler: {
    // local database migration started
} completionHandler: { error in
    // ready when error == nil
}

// Code that can run before initialization finishes, for example in another class:
SendbirdChat.executeOrWaitForInitialization {
    // runs right away when the SDK is initialized, otherwise after initialization completes
}
```
`SendbirdChat.executeOrWaitForInitialization(executeHandler:)` runs the handler immediately if the SDK is already initialized, and otherwise waits until initialization completes. `SendbirdUI.connectIfNeeded(completionHandler:)` already wraps its work in this call. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L95-L127 (default `InitParams` at lines 112–117, caching forced on at lines 123–127; `connectIfNeeded` at lines 212–216); source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message (sections "Synchronous initialization" and "Initialization dependency management"); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/86)

## Set the current user (required)
```swift
SBUGlobals.currentUser = SBUUser(userId: USER_ID)
// or: SBUUser(userId: USER_ID, nickname: NICKNAME, profileURL: PROFILE_URL)
```
Without `currentUser` set, UIKit usage is restricted. For authenticated apps set `SBUGlobals.accessToken`. (source: sendbird-uikit-ios README; build-verified)

## Present prebuilt screens
```swift
let groupChannelListVC = SBUGroupChannelListViewController()
let naviVC = UINavigationController(rootViewController: groupChannelListVC)
present(naviVC, animated: true)            // or navigationController?.pushViewController

let channelVC = SBUGroupChannelViewController(channelURL: CHANNEL_URL)
```
(source: sendbird-uikit-ios README §"Channel list" + §"Channel")

## Config (optional, before presenting)
`SendbirdUI.config.groupChannel.channel.*` and `.channelList.*` toggle features (reply type, typing indicator, reactions, mention, voice/file messages, etc.). See the QuickStart sample. (source: sendbird-uikit-ios QuickStart AppDelegate)

## Customize channel selection
Subclass and override the module delegate method to customize what happens when a channel row is tapped (e.g. push a custom detail screen instead of the default conversation screen):
```swift
final class MyChannelListViewController: SBUGroupChannelListViewController {
    override func baseChannelListModule(_ listComponent: SBUBaseChannelListModule.List, didSelectRowAt indexPath: IndexPath) {
        // Call super to keep the built-in navigation, or handle it yourself to replace it —
        // verify the exact default behavior against your installed version before relying on it.
    }
}
```
`SBUGroupChannelListViewController` is declared `open`, and `baseChannelListModule(_:didSelectRowAt:)` is an `open` override point on it (inherited from `SBUBaseChannelListViewController`); both are confirmed in the shipped interface. The method's default implementation isn't visible in a `.swiftinterface` (signatures only) — do not assume its exact behavior without checking the sample or your installed version. (source: `SendbirdUIKit.swiftinterface` (3.36.0) line 6132 `SBUGroupChannelListViewController`, line 6220 `baseChannelListModule(_:didSelectRowAt:)`)

## How customization is wired
Each screen is built from module components (header, list, input), and each component reads the view types it creates from static properties. Assign your subclass to the static property once at launch, before the first screen that uses it is created. A component reads these types in its `setupViews()`, so a change made after the screen loaded does not apply to that screen.
- Components of the channel screen: `SBUModuleSet.GroupChannelModule.HeaderComponent`, `.ListComponent`, `.InputComponent`.
- View types inside them: `SBUGroupChannelModule.List.UserMessageCell`, `.FileMessageCell`, `.CustomMessageCell` (and the admin, multiple-files, typing-indicator, and unknown cells), `SBUGroupChannelModule.Input.MessageInputView`, `SBUGroupChannelListModule.List.ChannelCell`.

The docs page still shows `listComponent.register(userMessageCell:)`. The per-type `register(adminMessageCell:nib:)`, `register(userMessageCell:nib:)`, `register(fileMessageCell:nib:)`, `register(multipleFilesMessageCell:nib:)`, `register(typingIndicatorMessageCell:nib:)` (all since 3.31.0), `register(unknownMessageCell:nib:)`, and `register(customMessageCell:nib:)` are deprecated, and each deprecation message points to the matching static type. Use the static types.

(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.swift#L17-L100 (component types lines 17–23, cell types 49–73, input view type 100); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.List.swift#L385-L415 (types registered in `setupViews()`; deprecated `register` methods at lines 760–895); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/SBUModuleSet.swift#L44; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelList/GroupChannel/SBUGroupChannelListModule.swift#L49; source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/modules/basics-of-module)

## Custom message cells
**Restyle or extend a built-in cell.** Subclass the built-in cell, call `super`, add your views, and assign the subclass type. This keeps the default behavior, including reactions, replies, and tap handling. The example below adds a caption that shows the file name under non-media file messages.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class MyFileMessageCell: SBUFileMessageCell {
    let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 2
        return label
    }()

    override func setupViews() {
        super.setupViews()
        mainContainerView.addArrangedSubview(captionLabel)
    }

    override func configure(with configuration: SBUBaseMessageCellParams) {
        super.configure(with: configuration)
        guard let fileMessage = (configuration as? SBUFileMessageCellParams)?.fileMessage else { return }
        switch SBUUtils.getFileType(by: fileMessage) {
        case .image, .video:
            captionLabel.isHidden = true
        default:
            captionLabel.isHidden = false
            captionLabel.text = fileMessage.name
        }
    }
}

// Once at launch, before the first channel screen is created:
SBUGroupChannelModule.List.FileMessageCell = MyFileMessageCell.self
```
`SBUUserMessageCell` works the same way with `SBUUserMessageCellParams.userMessage` and `SBUGroupChannelModule.List.UserMessageCell`. The list configures a cell through the default path as long as the cell is a subclass of the matching built-in cell. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUFileMessageCell.swift#L13-L41 (`configure(with:)` at line 69); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUContentBaseMessageCell.swift#L177 (`mainContainerView`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUSelectableStackView.swift#L85 (`addArrangedSubview`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/MessageCellParams/SBUFileMessageCellParams.swift#L12; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Util/SBUUtils.swift#L22; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.List.swift#L901-L1030 (`configureCell` matches each message to its cell class); source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/group-channel-views/chat-in-group-channel)

**A cell for a message type UIKit does not draw specially** (for example, messages your server sends with a `customType`). Subclass `SBUBaseMessageCell`, assign it to `CustomMessageCell` so the list registers it, and override `generateCellIdentifier(by:)` in a list subclass so matching messages use it.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class PollMessageCell: SBUBaseMessageCell {
    let titleLabel = UILabel()

    override func setupViews() {
        super.setupViews()
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageContentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: messageContentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: messageContentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: messageContentView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: messageContentView.bottomAnchor, constant: -8),
        ])
    }

    override func configure(with configuration: SBUBaseMessageCellParams) {
        super.configure(with: configuration)
        titleLabel.text = (configuration.message as? UserMessage)?.message
    }
}

final class PollAwareMessageList: SBUGroupChannelModule.List {
    override func generateCellIdentifier(by message: BaseMessage) -> String {
        if message.customType == "poll" {
            return PollMessageCell.sbu_className
        }
        return super.generateCellIdentifier(by: message)
    }
}

// Once at launch:
SBUGroupChannelModule.List.CustomMessageCell = PollMessageCell.self
SBUModuleSet.GroupChannelModule.ListComponent = PollAwareMessageList.self
```
A cell that is not a subclass of a built-in cell goes through the list's `default:` branch, which calls `configure(with:)` with a plain `SBUBaseMessageCellParams` whose position is `.center`. Read everything else you need from `configuration.message`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.List.swift#L1196-L1221 (`generateCellIdentifier(by:)`; `CustomMessageCell` registered at lines 413–415; `default:` branch at lines 1072–1082); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUBaseMessageCell.swift#L109-L127 (`messageContentView` at line 22, `configure(with:)` at line 173); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/NSObject+SBUIKit.swift#L13 (`sbu_className`))

**Taps on such a cell.** The `default:` branch does not install tap or long-press handlers; the built-in cells get them from the list's `setMessageCellGestures(_:message:indexPath:)`, which sets the cell's `tapHandlerToContent` and `longPressHandlerToContent`. To make your cell respond, call `setMessageCellGestures` after `super` in a `configureCell(_:message:forRowAt:)` override. Do not call `setTapGesture(_:message:indexPath:)` there: it is the tap action itself (it calls the delegate's `didTapMessage`, or `didTapVoiceMessage` for a voice message), so calling it while configuring runs that action as soon as the row is drawn, for example opening an image without a tap.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class TappableCustomMessageList: SBUGroupChannelModule.List {
    override func configureCell(_ messageCell: SBUBaseMessageCell, message: BaseMessage, forRowAt indexPath: IndexPath) {
        super.configureCell(messageCell, message: message, forRowAt: indexPath)
        if message.customType == "poll" {
            // Installs the handlers; the delegate runs only when the user taps or long-presses.
            setMessageCellGestures(messageCell, message: message, indexPath: indexPath)
        }
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.List.swift#L707-L728 (`setMessageCellGestures`; built-in cells call it at lines 948–1045, the `default:` branch at lines 1072–1082 does not); https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/SBUBaseChannelModule.List.swift#L914-L930 (`setTapGesture` calls the delegate); also the 3.36.2 release `.swiftinterface` lines 6583, 6617, and 986)

**Change the text a user message shows.** `SBUUserMessageCell.configure(with:)` builds an `SBUUserMessageTextViewModel` from the message. The model uses `message.message` whenever `message` is not `nil`, and falls back to its `text` argument only when `message` is `nil`. To show other text, configure `messageTextView` again after `super`, with `message: nil` and your text. With `message: nil` the model has no mention data, so mentions in that message are not highlighted. `isEdited: false` drops the "(edited)" mark.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class PrefixedUserMessageCell: SBUUserMessageCell {
    override func configure(with configuration: SBUBaseMessageCellParams) {
        super.configure(with: configuration)
        guard let params = configuration as? SBUUserMessageCellParams,
              params.withTextView,
              let userMessage = params.userMessage,
              let textView = messageTextView as? SBUUserMessageTextView else { return }
        textView.configure(model: SBUUserMessageTextViewModel(
            message: nil,
            position: params.messagePosition,
            text: displayText(for: userMessage),
            isEdited: false,
            isMarkdownEnabled: SendbirdUI.config.groupChannel.channel.isMarkdownForUserMessageEnabled
        ))
    }

    func displayText(for message: UserMessage) -> String {
        guard let type = message.customType, !type.isEmpty else { return message.message }
        return "[\(type)] \(message.message)"
    }
}

// Once at launch:
SBUGroupChannelModule.List.UserMessageCell = PrefixedUserMessageCell.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUUserMessageCell.swift#L199-L245 (`messageTextView` at line 15); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/ViewModel/SBUUserMessageTextViewModel.swift#L67-L84 (`let text = message?.message ?? text ?? ""` at line 78); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/145, https://github.com/sendbird/sendbird-uikit-ios/discussions/67)

**Leave out the sender name or the read-receipt icon.** `SBUContentBaseMessageCell.configure(with:)` sets the visibility of `userNameView`, the profile image, and the time label on every call, and `SBUMessageStateView` shows `stateImageView` for messages on the right. Change them after `super.configure(with:)` so your value is the last one written. `SBUBaseMessageCellParams.receiptState` is `.none` (sent), `.delivered`, `.read`, or `.notUsed`.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class QuietUserMessageCell: SBUUserMessageCell {
    override func configure(with configuration: SBUBaseMessageCellParams) {
        super.configure(with: configuration)
        userNameView.isHidden = true
        if configuration.message.sendingStatus == .succeeded,
           [.none, .delivered, .read].contains(configuration.receiptState) {
            (stateView as? SBUMessageStateView)?.stateImageView.isHidden = true
        }
    }
}

// Once at launch (file messages work the same way with SBUFileMessageCell and FileMessageCell):
SBUGroupChannelModule.List.UserMessageCell = QuietUserMessageCell.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUContentBaseMessageCell.swift#L509-L540 (`setMessageGrouping()`, called from `configure(with:)` at line 435; `userNameView` at line 27, `stateView` at line 38); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUMessageStateView.swift#L195-L216 (`stateImageView` at line 67); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUBaseMessageCell.swift#L18 (`receiptState`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Enums/SBUEnums.swift#L239-L248; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/61, https://github.com/sendbird/sendbird-uikit-ios/discussions/79)

**Change the spacing between messages.** `SBUBaseMessageCell.updateTopAnchorConstraint()` sets the space above each message: 4 pt inside a group of messages from the same sender (when message grouping is on) and 16 pt otherwise. Override it in your cell subclass to use other values, and keep the `stackView.superview` check the default has.

```swift
import UIKit
import SendbirdUIKit

final class RoomyUserMessageCell: SBUUserMessageCell {
    override func updateTopAnchorConstraint() {
        let isGrouped = SBUGlobals.isMessageGroupingEnabled
            && groupPosition != .none
            && groupPosition != .top
        guard stackView.superview != nil else { return }
        stackViewTopConstraint?.isActive = false
        stackViewTopConstraint = stackView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: isGrouped ? 4 : 32
        )
        stackViewTopConstraint?.priority = .defaultHigh
        stackViewTopConstraint?.isActive = true
    }
}

// Once at launch:
SBUGroupChannelModule.List.UserMessageCell = RoomyUserMessageCell.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUBaseMessageCell.swift#L149-L164 (`stackView` at line 52, `stackViewTopConstraint` at line 56); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/70)

**Open channels and message threads.** They have their own static cell types: `SBUOpenChannelModule.List.UserMessageCell` (and `FileMessageCell`, `AdminMessageCell`, `UnknownMessageCell`, `CustomMessageCell`), whose base class is `SBUOpenChannelBaseMessageCell`, and `SBUMessageThreadModule.List.UserMessageCell` and its siblings, whose base class is `SBUBaseMessageCell`. The open channel list configures a user message cell with `configure(_:hideDateView:groupPosition:withTextView:isOverlay:)`.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class NamelessOpenChannelUserMessageCell: SBUOpenChannelUserMessageCell {
    override func configure(
        _ message: BaseMessage,
        hideDateView: Bool,
        groupPosition: MessageGroupPosition,
        withTextView: Bool,
        isOverlay: Bool = false
    ) {
        super.configure(message, hideDateView: hideDateView, groupPosition: groupPosition,
                        withTextView: withTextView, isOverlay: isOverlay)
        userNameView.isHidden = true
    }
}

// Once at launch:
SBUOpenChannelModule.List.UserMessageCell = NamelessOpenChannelUserMessageCell.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/OpenChannel/SBUOpenChannelModule.swift#L56; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/OpenChannel/SBUOpenChannelModule.List.swift#L394-L401 (the call that configures a user message cell; the cell is registered from `UserMessageCell` at line 133); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/OpenChannel/SBUOpenChannelUserMessageCell.swift#L120; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/MessageThread/SBUMessageThreadModule.swift#L54; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/109)

## Message list: order, menus, and taps
`SBUGroupChannelViewController` is the delegate and data source of its list component. Subclass it, override the methods below, and register the subclass once at launch with `SBUViewControllerSet.GroupChannelViewController = MyChannelViewController.self`.

**What the list draws.** The list asks `baseChannelModule(_:fullMessagesInTableView:)` for its rows, and the default returns `viewModel.fullMessageList`. In a channel the list is upside down: index 0 is the newest row. From index 0, the array holds the typing indicator bubble (when shown), then pending and failed messages from newest to oldest, then sent messages from newest to oldest. A message thread uses the opposite order, oldest first. If your override returns a different array, keep the indices in line with `viewModel.fullMessageList`: tapping a quoted message scrolls to the row index of that message in `viewModel.fullMessageList`.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class FilteredChannelViewController: SBUGroupChannelViewController {
    override func baseChannelModule(
        _ listComponent: SBUBaseChannelModule.List,
        fullMessagesInTableView tableView: UITableView
    ) -> [BaseMessage] {
        let messages = super.baseChannelModule(listComponent, fullMessagesInTableView: tableView)
        // Read the array, for example to count messages before enabling something on screen.
        // Returning a filtered or reordered array changes the rows, see the note above.
        return messages
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/Channel/SBUBaseChannelViewModel.swift#L901-L936 (`isTransformedList` defaults to `true` at line 179; a message thread sets it to `false` in https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/MessageThread/SBUMessageThreadViewModel.swift#L136); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L1123-L1128; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/SBUBaseChannelModule.List.swift#L374-L376; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L1164-L1177 (quoted-message scroll); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/78, https://github.com/sendbird/sendbird-uikit-ios/discussions/88)

**Long press, menu items, and menu events.** A long press calls `baseChannelModule(_:didLongTapMessage:forRowAt:)`, which ends editing and calls `listComponent.showMessageMenu(on:forRowAt:)`. For a sent message, that shows the menu sheet when reactions are on and a context menu otherwise. Both build their items with the list component's `createMessageMenuItems(for:)`. The list component's `createCopyMenuItem(for:)`, `createEditMenuItem(for:)`, `createDeleteMenuItem(for:)`, `createSaveMenuItem(for:)`, and `createReplyMenuItem(for:)` return the built-in items, and an `SBUMenuItem` you create runs its `completionHandler` when tapped. When a built-in item is tapped, the view controller's `baseChannelModule(_:didTapCopyMessage:)`, `didTapEditMessage`, `didTapDeleteMessage`, `didTapSaveMessage`, or `didTapReplyMessage` runs, and closing the menu calls `baseChannelModule(_:didDismissMenuForCell:)`.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class ReportableMessageList: SBUGroupChannelModule.List {
    override func createMessageMenuItems(for message: BaseMessage) -> [SBUMenuItem] {
        var items: [SBUMenuItem] = []
        if message is UserMessage {
            items.append(createCopyMenuItem(for: message))
        }
        items.append(SBUMenuItem(title: "Report") {
            // Your report flow for `message`.
        })
        return items
    }
}

final class LoggingChannelViewController: SBUGroupChannelViewController {
    override func baseChannelModule(
        _ listComponent: SBUBaseChannelModule.List,
        didLongTapMessage message: BaseMessage,
        forRowAt indexPath: IndexPath
    ) {
        // Your logging, then the default menu. Leave out super to replace the menu entirely.
        super.baseChannelModule(listComponent, didLongTapMessage: message, forRowAt: indexPath)
    }

    override func baseChannelModule(_ listComponent: SBUBaseChannelModule.List, didDismissMenuForCell cell: UITableViewCell) {
        super.baseChannelModule(listComponent, didDismissMenuForCell: cell)
        // The menu closed.
    }
}

// Once at launch:
SBUModuleSet.GroupChannelModule.ListComponent = ReportableMessageList.self
SBUViewControllerSet.GroupChannelViewController = LoggingChannelViewController.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L921-L924 (default long press; `didDismissMenuForCell` at line 977); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/SBUBaseChannelModule.List.swift#L561-L582 (menu sheet or context menu; both call `createMessageMenuItems(for:)` at lines 651 and 696); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.List.swift#L644; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/Menu/SBUMenuCell.swift#L43-L46 (a tapped item runs its `completionHandler`; the context menu does the same at https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/Menu/SBUMenuView.swift#L426); SendbirdUIKit 3.36.2 public `.swiftinterface`: `SBUMenuItem.init(title:color:image:font:tintColor:textAlignment:tag:completionHandler:)`, the `create…MenuItem(for:)` methods, and the `didTap…Message` delegate methods; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/64, https://github.com/sendbird/sendbird-uikit-ios/discussions/72, https://github.com/sendbird/sendbird-uikit-ios/discussions/59)

**Taps in the reactions member list.** Long-pressing a reaction opens the list of who reacted, and `SBUGroupChannelViewController` makes itself the delegate of that screen. Tapping a profile calls `reactionsViewController(_:didTapUserProfile:)`, which shows the user profile by default. Selecting a row calls `reactionsViewController(_:tableView:didSelect:forRowAt:)`, which does nothing by default. Override either in your subclass.

```swift
import UIKit
import SendbirdUIKit

final class ReactionAwareChannelViewController: SBUGroupChannelViewController {
    override func reactionsViewController(_ viewController: SBUReactionsViewController, didTapUserProfile user: SBUUser) {
        // Your action. Call super to keep the default profile view.
        super.reactionsViewController(viewController, didTapUserProfile: user)
    }

    override func reactionsViewController(
        _ viewController: SBUReactionsViewController,
        tableView: UITableView,
        didSelect user: SBUUser,
        forRowAt indexPath: IndexPath
    ) {
        // Your action for a selected row.
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L1641-L1659 (the reactions screen is created with `delegate = self` at lines 1123–1136); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/52)

**Handle link taps yourself, for example to play a video link in the app.** A tap on a link in the message text and a tap on the link preview (OG) card of a user message both go through the cell's `urlTapHandler` to the view controller's `groupChannelModule(_:didTapURL:)`. Its default calls the UIKit `URL.open()` helper, which tries the URL as a universal link and otherwise hands it to the system, so a video link leaves the app. Override that method in your `SBUGroupChannelViewController` subclass. The link preview data (`OGMetaData`) has only `title`, `url`, `desc`, and `defaultImage`, with no media type, so decide yourself which URLs to play, for example by path extension.

```swift
import UIKit
import AVKit
import SendbirdUIKit

final class InAppLinkChannelViewController: SBUGroupChannelViewController {
    override func groupChannelModule(_ listComponent: SBUGroupChannelModule.List, didTapURL url: URL) {
        guard ["mp4", "mov", "m3u8"].contains(url.pathExtension.lowercased()) else {
            super.groupChannelModule(listComponent, didTapURL: url) // default: universal link, else the system opens it
            return
        }
        let playerViewController = AVPlayerViewController()
        playerViewController.player = AVPlayer(url: url)
        present(playerViewController, animated: true) { playerViewController.player?.play() }
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L1190-L1192 (default `url.open()`); https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.List.swift#L1119-L1121 (`urlTapHandler` calls `didTapURL`); https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUUserMessageCell.swift#L339-L349 (`onTapWebview(sender:)` for the preview card, and lines 429–430 for text links); https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/URL+SBUIKit.swift#L12-L20; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/OGMetaData.html)

## Message input bar
**Limit attachment options.** The "+" button opens a sheet whose items come from the input config. A value set in code takes priority over the value from the dashboard's UIKit configuration.

```swift
SendbirdUI.config.groupChannel.channel.input.camera.isVideoEnabled = false
SendbirdUI.config.groupChannel.channel.input.gallery.isVideoEnabled = false
SendbirdUI.config.groupChannel.channel.input.isDocumentEnabled = false
```
When every option is off, the sheet has no items. The "+" button still appears, and tapping it opens a sheet with only the cancel row, because the button's visibility does not depend on these settings. To remove the button, set `addButton` to `nil` in a subclass (next example). Voice messages have their own switch, `SendbirdUI.config.groupChannel.channel.isVoiceMessageEnabled`, which sets the default of `showsVoiceMessageButton`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Configuration/SBUConfig.Base.swift#L13-L74; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Util/SBUPropertyWrapper.swift#L89-L127 (a value set in code outranks the dashboard value); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L1266-L1310 (`addButton` at lines 142–148, `showsVoiceMessageButton` at line 298); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/ActionSheet/SBUActionSheet.swift#L100-L195)

**Add a custom button, or remove the "+" button.** Subclass `SBUMessageInputView`. `inputHStackView` holds, in order, the "+" button, a spacer, the text view, a spacer, the send button, and the voice button. `setupViews()` skips `nil` entries.

```swift
import UIKit
import SendbirdUIKit

final class MyMessageInputView: SBUMessageInputView {
    lazy var stickerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "face.smiling"), for: .normal)
        button.addTarget(self, action: #selector(onTapSticker), for: .touchUpInside)
        return button
    }()

    override func setupViews() {
        addButton = nil          // removes the "+" button; delete this line to keep it
        super.setupViews()
        inputHStackView.insertArrangedSubview(stickerButton, at: 0)
    }

    @objc func onTapSticker() {
        // Your action, for example present a sticker picker.
    }
}

// Once at launch:
SBUGroupChannelModule.Input.MessageInputView = MyMessageInputView.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L640-L763 (`setupViews()` builds `inputHStackView`, declared at line 220); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/UIStackView.SBUIKit.swift#L32-L45 (`nil` views are skipped); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.Input.swift#L159 (the default input view is created from `MessageInputView`))

**Disable the input from your app's own logic.** `SBUMessageInputView.setInputState(_:placeholder:)` (3.22.0+) turns off the text field, the "+" button, and the voice button, and shows your placeholder. Frozen, muted, and server-side disabled states take priority. While any of them is on, the call returns early. When those states change, the input view sets the text view's editability from those three states only. To keep your own condition in force, apply it again whenever the component refreshes the input state.

```swift
import UIKit
import SendbirdUIKit

final class MyInputComponent: SBUGroupChannelModule.Input {
    var isPausedByApp = false {
        didSet { applyAppInputState() }
    }

    override func updateMessageInputModeState() {
        super.updateMessageInputModeState()
        applyAppInputState()
    }

    func applyAppInputState() {
        (messageInputView as? SBUMessageInputView)?
            .setInputState(!isPausedByApp, placeholder: "Messaging is paused")
    }
}

// Once at launch:
SBUModuleSet.GroupChannelModule.InputComponent = MyInputComponent.self
// Later, on a channel screen you hold:
let channelVC = SBUGroupChannelViewController(channelURL: CHANNEL_URL)
(channelVC.inputComponent as? MyInputComponent)?.isPausedByApp = true
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L1104-L1182; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.Input.swift#L611-L654; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L39 (`inputComponent`))

**Add your own items to the "+" sheet, and send from them.** The "+" button calls `onTapAddButton(_:)`, which shows the items from `generateResourceItems()` (3.6.0+). A tapped item calls the input view's `didSelectActionSheetItem(index:identifier:)` with the item's `tag` as `index`. The default treats `index` as a `MediaResourceType` raw value (camera 0, library 1, document 2), so give your items tags outside that range and handle them before calling `super`. To send something from your own flow, call the view model's `sendFileMessage(messageParams:parentMessage:)` or `sendUserMessage(text:parentMessage:)`. UIKit sends a file the user picks through the same view model.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class GifInputView: SBUMessageInputView {
    static let gifTag = 100
    var onSelectGif: (() -> Void)?

    override func generateResourceItems() -> [SBUActionSheetItem] {
        var items = super.generateResourceItems()
        items.append(SBUActionSheetItem(title: "GIF", tag: Self.gifTag, completionHandler: nil))
        return items
    }

    override func didSelectActionSheetItem(index: Int, identifier: Int) {
        guard index == Self.gifTag else {
            super.didSelectActionSheetItem(index: index, identifier: identifier)
            return
        }
        onSelectGif?()
    }
}

final class GifChannelViewController: SBUGroupChannelViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        (inputComponent?.messageInputView as? GifInputView)?.onSelectGif = { [weak self] in
            self?.presentGifPicker()
        }
    }

    func presentGifPicker() {
        // Your GIF picker. When it returns the GIF's URL string, call sendGif(urlString:).
    }

    func sendGif(urlString: String) {
        let params = FileMessageCreateParams(fileURL: urlString)
        viewModel?.sendFileMessage(messageParams: params)
    }
}

// Once at launch:
SBUGroupChannelModule.Input.MessageInputView = GifInputView.self
SBUViewControllerSet.GroupChannelViewController = GifChannelViewController.self
```
The input view already exists in `viewDidLoad()`: the view controller configures its components from `loadView()`, and the input component creates its view in its own `setupViews()`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L1265-L1288 (`onTapAddButton(_:)` and `generateResourceItems()`; `didSelectActionSheetItem(index:identifier:)` at lines 1445–1458; default item tags at lines 492–506); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/ActionSheet/SBUActionSheet.swift#L226-L236 (a tapped item reports its `tag` as `index`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Enums/SBUEnums.swift#L190-L196 (`MediaResourceType`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SBUBaseViewController.swift#L65-L71 (`loadView()` calls `setupViews()`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.Input.swift#L192-L228; SendbirdUIKit 3.36.2 public `.swiftinterface`: `SBUBaseChannelViewModel.sendFileMessage(messageParams:parentMessage:)` and `sendUserMessage(text:parentMessage:)` (the same names on the view controller are deprecated); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L1464-L1475 (a picked file goes to `viewModel?.sendFileMessage`); Chat SDK `FileMessageCreateParams(fileURL:)` in the SendbirdChatSDK 4.39.11 `.swiftinterface`; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/147, https://github.com/sendbird/sendbird-uikit-ios/discussions/111)

**Use your own "+" button.** Assign `addButton` before `super.setupViews()`. Only the default button gets the `onTapAddButton(_:)` target, so add it yourself if your button should open the same sheet. `setupStyles()` sets the "+" icon on `addButton` every time it runs, so set your image after `super.setupStyles()`.

```swift
import UIKit
import SendbirdUIKit

final class CustomAddButtonInputView: SBUMessageInputView {
    override func setupViews() {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(onTapAddButton(_:)), for: .touchUpInside)
        addButton = button
        super.setupViews()
    }

    override func setupStyles() {
        super.setupStyles()
        addButton?.setImage(UIImage(systemName: "paperclip"), for: .normal)
    }
}

// Once at launch:
SBUGroupChannelModule.Input.MessageInputView = CustomAddButtonInputView.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L142-L148 (the default button and its target); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L966-L986 (`setupStyles()` sets the icon); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/60)

**Text field height and voice message quality.** `SBUMessageInputView.textViewMaxHeight` (default 87) is the most the text view grows to before it scrolls. `SBUGlobals.voiceMessageConfig.recorder.settings` is the dictionary UIKit passes to `AVAudioRecorder`. The defaults are AAC, 11025 Hz, one channel, `AVAudioQuality.high`, and 12000 bps.

```swift
import AVFoundation
import UIKit
import SendbirdUIKit

final class TallInputView: SBUMessageInputView {
    override func setupViews() {
        super.setupViews()
        textViewMaxHeight = 160
    }
}

// Once at launch:
SBUGroupChannelModule.Input.MessageInputView = TallInputView.self
SBUGlobals.voiceMessageConfig.recorder.settings[AVSampleRateKey] = 44100
SBUGlobals.voiceMessageConfig.recorder.settings[AVEncoderBitRateKey] = 64000
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L1229-L1240 (`updateTextViewHeight()` caps the height at `textViewMaxHeight`, declared at line 293); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Configuration/VoiceMessage/SBUVoiceMessageConfiguration.swift#L30-L44; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Manager/SBUVoiceRecorder.swift#L236-L239; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/68, https://github.com/sendbird/sendbird-uikit-ios/discussions/107)

**Restyle the input bar on open channels only.** Open channels read their input view type from `SBUOpenChannelModule.Input.MessageInputView`, separate from the group channel one. `SBUMessageInputView.setupStyles()` takes the background, text field background, and text field border colors from `SBUTheme.messageInputTheme`. Override it and change the colors after `super` to restyle only the screens that use your subclass. For an app-wide change, set the theme instead (see knowledge/curated/ios/cross-cutting/theme.md).

```swift
import UIKit
import SendbirdUIKit

final class LiveStreamInputView: SBUMessageInputView {
    override func setupStyles() {
        super.setupStyles()
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        textView?.backgroundColor = .systemGray
        textView?.layer.borderColor = UIColor.systemGray.cgColor
    }
}

// Once at launch:
SBUOpenChannelModule.Input.MessageInputView = LiveStreamInputView.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/OpenChannel/SBUOpenChannelModule.swift#L87; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/OpenChannel/SBUOpenChannelModule.Input.swift#L50-L52; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L902-L953 (`setupStyles()`); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/126)

**Mention suggestions without profile images.** The group channel input component creates `SBUSuggestedMentionList` in `presentSuggestedMentionList()` when `suggestedMentionList` is `nil`. Create your subclass there first, and hide the image in `configureCell(_:forRowAt:)` after `super`, which configures each row as an `SBUUserCell`.

```swift
import UIKit
import SendbirdUIKit

final class TextOnlyMentionList: SBUSuggestedMentionList {
    override func configureCell(_ cell: UITableViewCell?, forRowAt indexPath: IndexPath) {
        super.configureCell(cell, forRowAt: indexPath)
        (cell as? SBUUserCell)?.userImageView.isHidden = true
    }
}

final class TextOnlyMentionInput: SBUGroupChannelModule.Input {
    override func presentSuggestedMentionList() {
        if suggestedMentionList == nil {
            let list = TextOnlyMentionList()
            list.delegate = self
            suggestedMentionList = list
        }
        super.presentSuggestedMentionList()
    }
}

// Once at launch:
SBUModuleSet.GroupChannelModule.InputComponent = TextOnlyMentionInput.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.Input.swift#L841-L865 (`suggestedMentionList` at line 123); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUSuggestedMentionList.swift#L150-L158; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/105)

## Channel list
**Customize the list item.** Subclass `SBUGroupChannelCell`, change its public subviews after `super.configure(channel:)`, and assign the type. Subviews include `titleLabel`, `messageLabel`, `coverImage`, `unreadCount`, and `lastUpdatedTimeLabel`.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class MyChannelCell: SBUGroupChannelCell {
    override func configure(channel: BaseChannel) {
        super.configure(channel: channel)
        guard let groupChannel = channel as? GroupChannel else { return }
        titleLabel.font = groupChannel.unreadMessageCount > 0
            ? .boldSystemFont(ofSize: 16)
            : .systemFont(ofSize: 16)
    }
}

// Once at launch:
SBUGroupChannelListModule.List.ChannelCell = MyChannelCell.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/ChannelCell/SBUGroupChannelCell.swift#L17-L43 (`configure(channel:)` at line 249); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelList/GroupChannel/SBUGroupChannelListModule.List.swift#L91-L103 (registers `ChannelCell`))

**Show your own loading indicator.** The channel list calls `showLoading(_:)` when loading starts and ends. The default implementation shows the `SBULoading` overlay. Override it in a subclass to show your own view.

```swift
import UIKit
import SendbirdUIKit

final class MyChannelListViewController: SBUGroupChannelListViewController {
    private let spinner = UIActivityIndicatorView(style: .large)

    override func showLoading(_ isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.spinner.superview == nil {
                self.spinner.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(self.spinner)
                NSLayoutConstraint.activate([
                    self.spinner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                    self.spinner.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                ])
            }
            if isLoading { self.spinner.startAnimating() } else { self.spinner.stopAnimating() }
        }
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/SBUGroupChannelListViewController.swift#L493-L495; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SBUBaseViewController.swift#L264-L272)

The channel screen works the same way: `SBUGroupChannelViewController` passes `shouldUpdateLoadingState(_:)` to `showLoading(_:)`, so the same override shows your indicator there. Two flags from 3.27.5 decide whether loading from the local cache asks for the indicator. `SBUGlobals.loadingIndicator.groupChannel.cachedMessages` (default `false`) is the value the channel screen sends when it starts loading the channel. Later, when it loads the initial messages, it asks for the indicator either way. `SBUGlobals.loadingIndicator.groupChannelList.cachedChannels` also exists, but in 3.36.1 the group channel list view model passes it to its private `setLoading(_:_:)`, which ignores it and reports only the loading state. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SBUGlobals.swift#L219-L259; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/Channel/SBUGroupChannelViewModel.swift#L223-L224 (start of `loadChannel`; `loadInitialMessages` asks with `showIndicator: true` at lines 267–271 and 443–445); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/ChannelList/SBUGroupChannelListViewModel.swift#L270-L275 (`setLoading` ignores its `showIndicator` argument); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L1546-L1548; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/139, https://github.com/sendbird/sendbird-uikit-ios/discussions/137, https://github.com/sendbird/sendbird-uikit-ios/discussions/43)

**Search or filter the list.** `SBUGroupChannelListViewModel.initializeAndLoad(channelListQuery:)` (3.29.2+) resets the list with a new query and loads it again. Passing `nil` keeps the last query you set, so pass a query without the filter to clear a search. For a list that should always use your query (for example one that includes empty channels), pass it to `SBUGroupChannelListViewController(channelListQuery:)` instead.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class SearchableChannelListViewController: SBUGroupChannelListViewController, UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let params = GroupChannelListQueryParams()
        params.order = .latestLastMessage
        params.includeMetaData = true
        let keyword = searchBar.text ?? ""
        params.channelNameContainsFilter = keyword.isEmpty ? nil : keyword
        viewModel?.initializeAndLoad(channelListQuery: GroupChannel.createMyGroupChannelListQuery(params: params))
        searchBar.resignFirstResponder()
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/ChannelList/SBUGroupChannelListViewModel.swift#L95-L101 (the default query when you pass none is built at lines 107–125); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/SBUGroupChannelListViewController.swift#L52 (`viewModel`); Chat SDK `GroupChannelListQueryParams.channelNameContainsFilter` (see "Filter the channel list by name" in knowledge/curated/ios/products/chat.md); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/45, https://github.com/sendbird/sendbird-swiftui-ios/discussions/19)

**A header above the channel rows.** The channel list component is the table view's delegate and data source, and its `tableView(_:viewForHeaderInSection:)` and `tableView(_:heightForHeaderInSection:)` return `nil` and `0`. Override both in a list subclass to show your view as the header of the list's single section. The component does not implement the footer methods, so this override approach does not cover a footer.

```swift
import UIKit
import SendbirdUIKit

final class AnnouncementChannelList: SBUGroupChannelListModule.List {
    lazy var announcementLabel: UILabel = {
        let label = UILabel()
        label.text = "Support hours: 9:00 to 18:00"
        label.textAlignment = .center
        label.backgroundColor = .secondarySystemBackground
        return label
    }()

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        announcementLabel
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }
}

// Once at launch:
SBUModuleSet.GroupChannelListModule.ListComponent = AnnouncementChannelList.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelList/SBUBaseChannelListModule.List.swift#L233-L269 (`numberOfSections(in:)` returns 1; no footer methods); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelList/GroupChannel/SBUGroupChannelListModule.List.swift#L272-L276; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/84)

## Header (navigation bar)
The header component owns the title view and the bar buttons. Set your own before `super.setupViews()`. The component fills in a default only where you left `nil`. The theme's bar-button tint is applied to your buttons in `setupStyles`.

```swift
import UIKit
import SendbirdUIKit

final class MyChannelHeader: SBUGroupChannelModule.Header {
    override func setupViews() {
        let label = UILabel()
        label.text = "Support"
        label.font = .boldSystemFont(ofSize: 17)
        titleView = label
        rightBarButton = UIBarButtonItem(
            image: UIImage(systemName: "phone"),
            style: .plain,
            target: self,
            action: #selector(onTapCall)
        )
        super.setupViews()
    }

    @objc func onTapCall() {
        // Your action.
    }
}

// Once at launch:
SBUModuleSet.GroupChannelModule.HeaderComponent = MyChannelHeader.self
```
For colors only, change `SBUTheme.channelTheme` (see knowledge/curated/ios/cross-cutting/theme.md). The channel list header works the same way with `SBUModuleSet.GroupChannelListModule.HeaderComponent`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/SBUBaseChannelModule.Header.swift#L169-L207 (properties at lines 83–135); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/GroupChannel/SBUGroupChannelModule.Header.swift#L69-L84; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/SBUModuleSet.swift#L21; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L82-L117; source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/group-channel-views/chat-in-group-channel)

**React to a tap on the title.** The header delegate protocol already has `baseChannelModule(_:didTapTitleView:)`, and `SBUBaseChannelViewController` implements it as an empty `open` method. In 3.36.1 only the message thread header calls it. In a group channel, add the tap yourself in a header subclass and override the method in your view controller.

```swift
import UIKit
import SendbirdUIKit

final class TappableTitleHeader: SBUGroupChannelModule.Header {
    override func setupViews() {
        super.setupViews()
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTapTitle))
        titleView?.isUserInteractionEnabled = true
        titleView?.addGestureRecognizer(tap)
    }

    @objc func onTapTitle() {
        baseDelegate?.baseChannelModule(self, didTapTitleView: titleView)
    }
}

final class TitleTapChannelViewController: SBUGroupChannelViewController {
    override func baseChannelModule(_ headerComponent: SBUBaseChannelModule.Header, didTapTitleView titleView: UIView?) {
        // Your action, for example open the channel settings.
        showChannelSettings()
    }
}

// Once at launch:
SBUModuleSet.GroupChannelModule.HeaderComponent = TappableTitleHeader.self
SBUViewControllerSet.GroupChannelViewController = TitleTapChannelViewController.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/SBUBaseChannelModule.Header.swift#L50 (the delegate method; `baseDelegate` is public, `setupViews()` assigns the default `titleView` at lines 169–172); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L829-L830; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/MessageThread/SBUMessageThreadModule.Header.swift#L141-L145 (the only caller); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/53)

## Channel settings and member list
**Choose the rows of the channel settings screen.** `SBUGroupChannelSettingsModule.List.setupItems()` builds `items` from `createModerationsItem()` (operators only), `createNotificationItem()`, `createMembersItem()`, `createSearchItem()` (when message search is available), and `createLeaveItem()`. Override it and assign your own array.

```swift
import UIKit
import SendbirdUIKit

final class ShortSettingsList: SBUGroupChannelSettingsModule.List {
    override func setupItems() {
        var items = isOperator ? [createModerationsItem()] : []
        items += [createNotificationItem(), createMembersItem(), createLeaveItem()]
        self.items = items
    }
}

// Once at launch:
SBUModuleSet.GroupChannelSettingsModule.ListComponent = ShortSettingsList.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelSettings/GroupChannel/SBUGroupChannelSettingsModule.List.swift#L117-L131; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelSettings/SBUBaseChannelSettingsModule.List.swift#L55-L83 (`isOperator`, `items`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/ChannelSettings/GroupChannel/SBUGroupChannelSettingsModule.swift#L20; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/47)

**Remove the right bar button of the member list.** The member list header puts its default right button in place in `setupViews()` only when you have not set one. The view controller runs that from `loadView()`. Setting `headerComponent?.rightBarButton = nil` afterwards updates the navigation item through the header delegate.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class MemberListViewController: SBUUserListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        if (channel as? GroupChannel)?.myRole != .operator {
            headerComponent?.rightBarButton = nil
        }
    }
}

// Once at launch:
SBUViewControllerSet.GroupUserListViewController = MemberListViewController.self
```
`channel` comes from the view model and is `nil` until the channel is loaded, so this example also removes the button when the channel is not loaded yet. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/UserList/SBUUserListModule.Header.swift#L98-L108 (the default is set at lines 247–248); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/UserList/SBUUserListViewController.swift#L459-L464 (`channel` at line 43); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SBUViewControllerSet.swift#L44; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/54)

## Message threads
**Restyle the parent message at the top of a thread.** `SBUParentMessageInfoView.setupStyles()` takes the sender name color and font from `SBUTheme.messageCellTheme` (`parentInfoUserNameTextColor`, `parentInfoUserNameTextFont`) and runs on every layout pass. Change the theme for every thread, or subclass the view, change it after `super`, and assign `SBUMessageThreadModule.List.ParentMessageInfoView`.

```swift
import UIKit
import SendbirdUIKit

final class BrandedParentMessageInfoView: SBUParentMessageInfoView {
    override func setupStyles() {
        super.setupStyles()
        userNameLabel.textColor = .systemIndigo
    }
}

// Once at launch:
SBUMessageThreadModule.List.ParentMessageInfoView = BrandedParentMessageInfoView.self
// Or for every thread, without a subclass:
SBUTheme.messageCellTheme.parentInfoUserNameTextColor = .systemIndigo
```
`SBUTheme.set(colorScheme:)` replaces the theme objects, so set theme values after it (see knowledge/curated/ios/cross-cutting/theme.md). (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/MessageThread/SBUParentMessageInfoView.swift#L390-L402 (the theme at line 128); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Life%20cycles/SBUView.swift#L43-L46 (`layoutSubviews()` calls `setupStyles()`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/MessageThread/SBUMessageThreadModule.swift#L82 (used at https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/MessageThread/SBUMessageThreadModule.List.swift#L162); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L2520; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/57)

## Media: thumbnails and video
**Why an image thumbnail can look blurry.** For an image or video message, the cell loads the message's first server thumbnail (`thumbnails.first.url`) when it exists, except for GIFs. Otherwise, once the message is sent, it loads the original `url`. It draws the image in a box of `SBUGlobals.messageCellConfiguration.groupChannel.thumbnailSize` (240×160 pt by default) with `.scaleAspectFill`. If the first thumbnail is smaller than that box, it is stretched to fill it. When UIKit sends an image, it asks for one thumbnail as large as the image itself (`ThumbnailSize.make(maxSize: image.size)`). When you send file messages yourself with the Chat SDK, set a large enough `FileMessageCreateParams.thumbnailSizes`.

```swift
// Once at launch: a larger box for image and video messages in group channels.
SBUGlobals.messageCellConfiguration.groupChannel.thumbnailSize = CGSize(width: 280, height: 280)
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/FileMessageContentView/SBUImageContentView.swift#L80-L131 (image view and size constraints at lines 13–17 and 65–76); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Constant/SBUConstant.swift#L13; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SBUGlobals.swift#L117-L125 (`messageCellConfiguration`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/Channel/SBUBaseChannelViewModel.swift#L355-L370; Chat SDK `FileMessageCreateParams.thumbnailSizes` and `ThumbnailSize.make(maxSize:)` in the SendbirdChatSDK 4.39.11 `.swiftinterface`)

**Play a video message as a stream.** Tapping a sent file message calls `openFile(fileMessage:)`. For audio and video, the default downloads the whole file first, then opens it in `UIDocumentInteractionController`, or in `AVPlayerViewController` when `SBUGlobals.isAVPlayerAlwaysEnabled` is `true`. To start playback without waiting for the download, override `openFile(fileMessage:)` and hand the URL to `AVPlayer`.

```swift
import AVKit
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class MyChannelViewController: SBUGroupChannelViewController {
    override func openFile(fileMessage: FileMessage) {
        guard SBUUtils.getFileType(by: fileMessage) == .video,
              let url = URL(string: fileMessage.url) else {
            super.openFile(fileMessage: fileMessage)
            return
        }
        let playerVC = AVPlayerViewController()
        playerVC.player = AVPlayer(url: url)
        present(playerVC, animated: true) { playerVC.player?.play() }
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L509-L576 (`openFile`; a tap on a sent file message calls `openFile(fileMessage:)` at lines 886–918); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SBUGlobals.swift#L154; source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/features/file-sharing)

**Replace the bottom bar of the image viewer.** An image message opens in the view controller type set in `SBUCommonViewControllerSet.FileViewController` (3.5.2+). `SBUFileViewController.bottomView` is the bar with the delete and download buttons. `setupViews()` adds whatever `bottomView` holds and `setupLayouts()` pins it to the bottom, 56 pt tall plus the bottom safe area. `viewDidLoad()` wires the delete and download buttons only when `bottomView` is the built-in bar. So a bar of your own runs only the actions you connect, for example the open `onClickDownload(sender:)`.

```swift
import UIKit
import SendbirdUIKit

final class SaveOnlyFileViewController: SBUFileViewController {
    override func setupViews() {
        let bar = UIView()
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(onClickDownload(sender:)), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(saveButton)
        NSLayoutConstraint.activate([
            saveButton.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            saveButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: 12),
        ])
        bottomView = bar
        super.setupViews()
    }
}

// Once at launch:
SBUCommonViewControllerSet.FileViewController = SaveOnlyFileViewController.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/FileViewer/SBUFileViewController.swift#L200-L326 (`bottomView` at line 108; buttons wired at lines 229–247; added at line 300, constrained at lines 310–325); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/SBUCommonViewControllerSet.swift#L19; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L515-L522 (an image opens in this type); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/48)

**Video sound with the silent switch on.** Apple's `AVAudioSession.Category.playback` keeps app audio playing when the Ring/Silent switch is set to silent. UIKit does not set this category for video. Its voice message player and recorder switch the category while they run and put the app's previous category back afterwards. To play video sound in silent mode, set the category in your app.

```swift
import AVFoundation

try AVAudioSession.sharedInstance().setCategory(.playback)
```
(source: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Manager/SBUVoicePlayer.swift#L174-L204 (the only `setCategory` calls in UIKit, with https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Manager/SBUVoiceRecorder.swift#L171-L213); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/49)

## Loading overlay and emojis
**Let touches through the loading overlay.** `SBULoading` (the overlay `showLoading(_:)` uses) blocks touches behind it. `SBULoadingDataSource.shouldPassTouchHit(_:with:)` (3.16.0+) decides per touch: return `true` to pass the touch to the views behind the overlay. There is one data source for the whole app, so set it when your screen appears and remove it when it disappears.

```swift
import UIKit
import SendbirdUIKit

final class PassThroughChannelViewController: SBUGroupChannelViewController, SBULoadingDataSource {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SBULoading.setDataSource(dataSource: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SBULoading.removeDataSource()
    }

    func shouldPassTouchHit(_ point: CGPoint, with event: UIEvent?) -> Bool {
        navigationController?.navigationBar.frame.contains(point) == true   // keep the back button usable
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/SBULoading.swift#L11-L34 (`setDataSource` and `removeDataSource` at lines 106–114; the overlay's `hitTest` at lines 170–178); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/91)

**Read the reaction emojis yourself.** `SBUEmojiManager.getAllEmojis()` returns what is already loaded, and an empty array before that or when reactions are off. UIKit starts `loadAllEmojis(completionHandler:)` after its own connect, without waiting for it, so read the list inside the load's completion.

```swift
import SendbirdUIKit

SendbirdUI.connectIfNeeded { user, error in
    guard error == nil else { return }
    SBUEmojiManager.loadAllEmojis { container, error in
        let emojis = SBUEmojiManager.getAllEmojis()
        // Use emojis (each has a key and a URL).
    }
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Manager/SBUEmojiManager.swift#L56-L75 (`loadAllEmojis(completionHandler:)` at line 149); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L250-L254 (the load starts in a `defer` after connect); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/50)

## Start a 1:1 chat from a button (no channel list)
For a "Chat with seller" button: create the channel with `isDistinct = true`, which returns the existing 1:1 channel when one already has the same members, and then open the channel screen by its URL. Push `SBUGroupChannelViewController(channelURL:)` on your own navigation controller, so the back button returns to your screen.

```swift
import UIKit
import SendbirdChatSDK
import SendbirdUIKit

final class SellerProfileViewController: UIViewController {
    var sellerUserId = ""

    @objc func chatWithSellerTapped() {
        let params = GroupChannelCreateParams()
        params.userIds = [sellerUserId]
        params.isDistinct = true   // same members -> the existing channel comes back
        GroupChannel.createChannel(params: params) { [weak self] channel, error in
            guard let self, let channel, error == nil else { return }
            let channelVC = SBUGroupChannelViewController(channelURL: channel.channelURL)
            self.navigationController?.pushViewController(channelVC, animated: true)
        }
    }

    // From a notification tap, where no navigation controller of yours is at hand.
    // Payload format: knowledge/curated/ios/cross-cutting/push.md ("Handle a notification payload").
    func openChannel(fromPush userInfo: [AnyHashable: Any]) {
        let sendbird = userInfo["sendbird"] as? [String: Any]
        guard let channelURL = (sendbird?["channel"] as? [String: Any])?["channel_url"] as? String else { return }
        SendbirdUI.moveToChannel(channelURL: channelURL, basedOnChannelList: false)
    }
}
```

`SendbirdUI.moveToChannel(channelURL:basedOnChannelList:messageListParams:channelType:rootViewController:)` returns without doing anything when `SBUGlobals.currentUser` is not set. It starts from the window's root view controller (or the selected tab), reuses a channel list or channel screen it finds there, and otherwise presents `SBUViewControllerSet.GroupChannelViewController` in a new `UINavigationController`. With `basedOnChannelList: true` (the default) it presents a channel list first and opens the channel from it. UIKit's own `startChatWithAIBot` uses the same create-then-`moveToChannel(..., basedOnChannelList: false)` sequence. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L750-L872 — `moveToChannel` and `showChannelViewController`) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L1096-L1116 — create with `isDistinct`, then move) (SendbirdUIKit.swiftinterface 3.36.2: `moveToChannel` 16572, `SBUGroupChannelViewController.init(channelURL:startingPoint:messageListParams:)` 7363) (source: knowledge/curated/ios/products/chat.md — Create and list group channels)

## Attachment permissions (Info.plist)
UIKit lets users attach photos, videos, and documents, and save media. The docs list four `Info.plist` usage descriptions for these features: `NSPhotoLibraryUsageDescription` (pick from the library), `NSCameraUsageDescription` (take a photo or video), `NSMicrophoneUsageDescription` (record sound with a video), and `NSPhotoLibraryAddUsageDescription` (save media to the library). When camera capture from the message input fails while picking from the library works, check the camera and microphone keys first. Documents from iCloud also need the iCloud capability with iCloud Documents checked under Signing & Capabilities.

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>$(PRODUCT_NAME) would like access to your photo library</string>
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) would like to use your camera</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) would like to use your microphone (for videos)</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>$(PRODUCT_NAME) would like to save photos to your photo library</string>
```
(source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/get-attachment-permission; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/README.md#L150-L178)

## Pitfalls
- Assign custom cell, input view, and component types once at launch, before the first screen that uses them is created.
- Initialize once at launch; set `currentUser` before presenting any UIKit screen.
- App ID from config/env; access token is a secret — never hard-code.
- UIKit is UIViewController-based — for SwiftUI, wrap in `UIViewControllerRepresentable`.

## Related
- Repo + quickstart: https://github.com/sendbird/sendbird-uikit-ios
- Theming: knowledge/curated/ios/cross-cutting/theme.md
- Underlying Chat: knowledge/curated/ios/products/chat.md
