// source: knowledge/curated/ios/setup.md ("Pitfalls": App ID from config)
import Foundation

enum AppConfig {
    /// BP02: the App ID compiled into the bundle (Info.plist `SendbirdAppId`, filled from the
    /// `SENDBIRD_APP_ID` build setting in Config/Sendbird.xcconfig). Empty when it was not set;
    /// the sign-in screen reports that instead of the build failing.
    static let sendbirdAppId: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "SendbirdAppId") as? String ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("$(") ? "" : trimmed
    }()
}
