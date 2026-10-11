<!-- last-verified-against: sendbird-uikit-ios 3.36.1 -->
<!-- status: populated -->
# ios uikit

> Verified against the public mirror `sendbird/sendbird-uikit-ios` (README quickstart + QuickStart sample, verified 2026-06-09). init + currentUser + channel list build-verified locally (xcodebuild). The customization sections (message cells, input bar, channel list, header, media) were read from the public source at tag `3.36.1` and the UIKit v3 iOS docs, and every example builds with `tools/curated/compile-snippets-ios.sh` (verified 2026-10-11). Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-uikit-ios

## Overview
Sendbird UIKit gives prebuilt chat screens (channel list, conversation, settings) on top of Chat. Initialize UIKit, set the current user, then present the provided view controllers.

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

The docs page still shows `listComponent.register(userMessageCell:)`. Every `register(...MessageCell:nib:)` method except `register(messageTemplateCell:nib:)` is deprecated (the admin, user, file, multiple-files, and typing-indicator ones since 3.31.0), and each deprecation message points to the matching static type. Use the static types.

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

## Media: thumbnails and video
**Why an image thumbnail can look blurry.** For an image or video message, the cell loads the message's first server thumbnail (`thumbnails.first.url`) when it exists, except for GIFs. Otherwise, once the message is sent, it loads the original `url`. It draws the image in a box of `SBUGlobals.messageCellConfiguration.groupChannel.thumbnailSize` (240×160 pt by default) with `.scaleAspectFill`. If the first thumbnail is smaller than that box, it is stretched to fill it. When UIKit sends an image, it asks for one thumbnail as large as the image itself (`ThumbnailSize.make(maxSize: image.size)`). Messages sent by other clients may carry smaller thumbnails. When you send file messages yourself with the Chat SDK, set a large enough `FileMessageCreateParams.thumbnailSizes`.

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

## Pitfalls
- Assign custom cell, input view, and component types once at launch, before the first screen that uses them is created.
- Initialize once at launch; set `currentUser` before presenting any UIKit screen.
- App ID from config/env; access token is a secret — never hard-code.
- UIKit is UIViewController-based — for SwiftUI, wrap in `UIViewControllerRepresentable`.

## Related
- Repo + quickstart: https://github.com/sendbird/sendbird-uikit-ios
- Theming: knowledge/curated/ios/cross-cutting/theme.md
- Underlying Chat: knowledge/curated/ios/products/chat.md
