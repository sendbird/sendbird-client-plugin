// source: knowledge/curated/ios/products/uikit.md ("Present prebuilt screens", "How customization is wired")
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L152-L171
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Module/Channel/SBUBaseChannelModule.Input.swift#L122
import UIKit
import SendbirdUIKit

/// The UIKit channel list. Tapping a row opens the conversation screen UIKit picks from
/// SBUViewControllerSet, which SendbirdSession points at ChannelViewController below.
final class ChannelListViewController: SBUGroupChannelListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "sb_channel_list"   // BP17
    }
}

/// The UIKit conversation screen with stable identifiers on its message input and send button.
final class ChannelViewController: SBUGroupChannelViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        labelInput()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        labelInput()
    }

    // BP17: inputComponent.messageInputView is the UIKit input bar; its textView and sendButton are public.
    private func labelInput() {
        guard let input = inputComponent?.messageInputView as? SBUMessageInputView else { return }
        input.textView?.accessibilityIdentifier = "sb_message_input"
        input.sendButton?.accessibilityIdentifier = "sb_send_button"
    }
}
