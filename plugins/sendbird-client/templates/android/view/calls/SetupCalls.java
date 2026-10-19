// source: https://sendbird.com/docs/calls/sdk/v1/android/getting-started/make-first-call (Step 3 permissions, Step 5 init,
//   Step 6 authenticate, Step 8 add an event handler, Step 9 make a call, Step 10 receive a call; verified 2026-10-17)
// source: https://sendbird.com/docs/calls/sdk/v1/android/features/authentication (SendBirdCall.deauthenticate)
// source: https://github.com/sendbird/sendbird-calls-android/blob/v1.12.5/README.md (README implementation guide)
// sendbird-calls 1.12.5 — verified via javap of the published AAR (2026-10-17):
//   SendBirdCall.init(Context, String) / authenticate(AuthenticateParams, AuthenticateHandler) /
//   deauthenticate(CompletionHandler) / addListener(String, SendBirdCallListener) / dial(DialParams, DialHandler);
//   abstract SendBirdCallListener: onRinging(DirectCall) + onInvitationReceived(RoomInvitation), both required;
//   abstract DirectCallListener: onConnected(DirectCall) + onEnded(DirectCall); onEstablished(DirectCall) optional;
//   DirectCall.isVideoCall() / getCallId() / setListener(DirectCallListener) / accept(AcceptParams) / end();
//   CallOptions.setAudioEnabled(boolean) / setVideoEnabled(boolean); AcceptParams.setCallOptions(CallOptions);
//   DialParams(String).setVideoCall(boolean) / setCallOptions(CallOptions);
//   AuthenticateHandler.onResult(User, SendBirdException), DialHandler.onResult(DirectCall, SendBirdException),
//   CompletionHandler.onResult(SendBirdException) are single-method interfaces (lambdas work).
//   The AAR's own manifest declares CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, BLUETOOTH_CONNECT, INTERNET.
// Gradle: implementation 'com.sendbird.sdk:sendbird-calls:1.12.5'
// App ID from BuildConfig/secret; access token is a secret — never hard-code.

import android.Manifest;
import android.os.Build;
import com.sendbird.calls.AcceptParams;
import com.sendbird.calls.AuthenticateParams;
import com.sendbird.calls.CallOptions;
import com.sendbird.calls.DialParams;
import com.sendbird.calls.DirectCall;
import com.sendbird.calls.RoomInvitation;
import com.sendbird.calls.SendBirdCall;
import com.sendbird.calls.SendBirdException;
import com.sendbird.calls.handler.CompletionHandler;
import com.sendbird.calls.handler.DirectCallListener;
import com.sendbird.calls.handler.SendBirdCallListener;

public final class SetupCalls {

    /** Called on the SDK's callback thread; post to the main thread before touching views. */
    public interface CallEvents {
        void onRinging(DirectCall call);
        void onConnected(DirectCall call);
        void onEnded(DirectCall call);
        void onDialFailed(SendBirdException e);   // e.g. the callee is not signed in to Calls
    }

    /** Ask for these at runtime before the first dial or accept (docs "Make first call", Step 3). */
    public static String[] callPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return new String[] { Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA,
                    Manifest.permission.BLUETOOTH_CONNECT };
        }
        return new String[] { Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA };
    }

    // Call once (e.g. Application.onCreate).
    public static void init(android.content.Context context, String appId) {
        SendBirdCall.init(context, appId);
    }

    // Call from the app's sign-in code (onLoginSucceeded), after the Chat connect when the app uses Chat.
    // done.onResult(null) means authenticated.
    public static void authenticate(String userId, String accessToken, CompletionHandler done) {
        AuthenticateParams params = new AuthenticateParams(userId).setAccessToken(accessToken);
        SendBirdCall.authenticate(params, (user, e) -> done.onResult(e));
    }

    // Call from the app's sign-out code (onLogout) so this device stops ringing for the user.
    public static void deauthenticate() {
        SendBirdCall.deauthenticate(e -> { /* signed out of Calls */ });
    }

    // Add once at startup (Application.onCreate), before a call can ring.
    public static void addIncomingCallListener(String handlerId, CallEvents events) {
        SendBirdCall.addListener(handlerId, new SendBirdCallListener() {
            @Override public void onRinging(DirectCall call) {
                call.setListener(callListener(events));   // register before accepting
                events.onRinging(call);
            }
            @Override public void onInvitationReceived(RoomInvitation invitation) { /* incoming group-room invitation */ }
        });
    }

    // Make a 1:1 direct call; video == false makes a voice call.
    public static DirectCall dial(String calleeId, boolean video, CallEvents events) {
        DialParams params = new DialParams(calleeId)
                .setVideoCall(video)
                .setCallOptions(new CallOptions().setAudioEnabled(true).setVideoEnabled(video));
        DirectCall call = SendBirdCall.dial(params, (directCall, e) -> {
            if (e != null) events.onDialFailed(e);
        });
        if (call != null) call.setListener(callListener(events));
        return call;
    }

    // Make a 1:1 voice call.
    public static DirectCall dial(String calleeId) {
        return SendBirdCall.dial(new DialParams(calleeId), (directCall, e) -> {
            if (e != null) { /* handle error */ }
        });
    }

    // Accept a ringing call, with video when the caller placed a video call.
    public static void accept(DirectCall call) {
        CallOptions options = new CallOptions().setAudioEnabled(true).setVideoEnabled(call.isVideoCall());
        call.accept(new AcceptParams().setCallOptions(options));
    }

    // Hang up, cancel an outgoing call, or decline a ringing one.
    public static void end(DirectCall call) {
        call.end();
    }

    private static DirectCallListener callListener(CallEvents events) {
        return new DirectCallListener() {
            @Override public void onConnected(DirectCall call) { events.onConnected(call); }
            @Override public void onEnded(DirectCall call) { events.onEnded(call); }
        };
    }
}
