// source: sendbird-calls 1.12.4 — SendBirdCallListener verified via javap of the published AAR
//   (2026-06-22): abstract onRinging(DirectCall) + onInvitationReceived(RoomInvitation), both required.
// Gradle: implementation 'com.sendbird.sdk:sendbird-calls:1.12.4'
// App ID from BuildConfig/secret; access token is a secret — never hard-code.

import com.sendbird.calls.SendBirdCall;
import com.sendbird.calls.AuthenticateParams;
import com.sendbird.calls.DialParams;
import com.sendbird.calls.DirectCall;
import com.sendbird.calls.RoomInvitation;
import com.sendbird.calls.handler.SendBirdCallListener;

public final class SetupCalls {

    // Call once (e.g. Application.onCreate).
    public static void init(android.content.Context context, String appId) {
        SendBirdCall.init(context, appId);
    }

    public static void authenticate(String userId, String accessToken) {
        AuthenticateParams params = new AuthenticateParams(userId).setAccessToken(accessToken);
        SendBirdCall.authenticate(params, (user, e) -> {
            if (e == null) {
                // authenticated
            }
        });
    }

    public static void addIncomingCallListener(String handlerId) {
        SendBirdCall.addListener(handlerId, new SendBirdCallListener() {
            @Override public void onRinging(DirectCall call) { /* incoming 1:1 call */ }
            @Override public void onInvitationReceived(RoomInvitation invitation) { /* incoming group-room invitation */ }
        });
    }

    // Make a 1:1 direct call.
    public static DirectCall dial(String calleeId) {
        DialParams params = new DialParams(calleeId);
        return SendBirdCall.dial(params, (directCall, e) -> {
            if (e != null) { /* handle error */ }
        });
    }
}
