// source: https://github.com/sendbird/sendbird-calls-android/blob/main/README.md (make / receive a call; verified 2026-09-30)
// source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/master/directcall-java/app/src/main/java/com/sendbird/calls/quickstart/call/VideoCallActivity.java (verified 2026-09-30)
// Sendbird Calls ships no Compose API (javap of sendbird-calls 1.12.4 and 1.12.5: no androidx.compose
// references, no Compose dependency in the POM). The video surfaces are Views (SendBirdVideoView), so
// this template hosts them with AndroidView. Symbols verified via javap of the published
// sendbird-calls 1.12.4 and 1.12.5 AARs and their sendbird-webrtc 1.0.6998 dependency (2026-09-30):
//   - SendBirdVideoView(Context) extends org.webrtc.SurfaceViewRenderer
//     (setScalingType(RendererCommon.ScalingType), setEnableHardwareScaler(Boolean))
//   - DirectCall.setLocalVideoView / setRemoteVideoView(SendBirdVideoView), accept(AcceptParams), end(), setListener(...)
//   - SendBirdCall.addListener(id, SendBirdCallListener) / removeListener(id) / dial(DialParams, DialHandler)
//   - DialParams(calleeId).setVideoCall(true).setCallOptions(CallOptions)
//   - CallOptions().setVideoEnabled(Boolean).setAudioEnabled(Boolean); AcceptParams().setCallOptions(...)
//   - abstract DirectCallListener: onConnected(DirectCall), onEnded(DirectCall)
//   - DirectCall.isVideoCall() (sendbird-calls 1.12.5 javap, verified 2026-10-17)
// SendBirdCall.init + authenticate stay as in the View-host template (templates/android/view/calls/SetupCalls.java).
// Needs CAMERA + RECORD_AUDIO runtime permissions before dialing or accepting a video call.
// Gradle: implementation("com.sendbird.sdk:sendbird-calls:1.12.5")

package com.sendbird.client.templatecheck.compose.calls

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.ViewModel
import com.sendbird.calls.AcceptParams
import com.sendbird.calls.CallOptions
import com.sendbird.calls.DialParams
import com.sendbird.calls.DirectCall
import com.sendbird.calls.RoomInvitation
import com.sendbird.calls.SendBirdCall
import com.sendbird.calls.SendBirdVideoView
import com.sendbird.calls.handler.DirectCallListener
import com.sendbird.calls.handler.SendBirdCallListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.webrtc.RendererCommon

private const val LISTENER_ID = "compose-direct-call"

enum class CallState { IDLE, DIALING, RINGING, CONNECTED }

/** Exposes the active 1:1 call (incoming or outgoing) and its state as StateFlows; null and IDLE when idle. */
class DirectCallViewModel : ViewModel() {
    private val _call = MutableStateFlow<DirectCall?>(null)
    val call: StateFlow<DirectCall?> = _call.asStateFlow()
    private val _state = MutableStateFlow(CallState.IDLE)
    val state: StateFlow<CallState> = _state.asStateFlow()

    private val callListener = object : DirectCallListener() {
        override fun onConnected(call: DirectCall) { _state.value = CallState.CONNECTED }
        override fun onEnded(call: DirectCall) {
            _call.value = null
            _state.value = CallState.IDLE
        }
    }

    init {
        SendBirdCall.addListener(LISTENER_ID, object : SendBirdCallListener() {
            override fun onRinging(call: DirectCall) {
                if (_call.value != null) {
                    call.end()   // already in a call: decline the second one
                    return
                }
                call.setListener(callListener)   // register before accepting
                _call.value = call
                _state.value = CallState.RINGING
            }
            override fun onInvitationReceived(invitation: RoomInvitation) { /* group-room invitation */ }
        })
    }

    fun dialVideo(calleeId: String) = dial(calleeId, video = true)

    /** Places a 1:1 call; `video = false` makes a voice call. */
    fun dial(calleeId: String, video: Boolean) {
        val params = DialParams(calleeId)
            .setVideoCall(video)
            .setCallOptions(callOptions(video))
        val call = SendBirdCall.dial(params) { _, e ->
            if (e != null) {
                _call.value = null
                _state.value = CallState.IDLE
            }
        }
        call?.setListener(callListener)
        _call.value = call
        _state.value = if (call != null) CallState.DIALING else CallState.IDLE
    }

    /** Accepts the ringing call, with video when the caller placed a video call. */
    fun accept(call: DirectCall) {
        call.accept(AcceptParams().setCallOptions(callOptions(call.isVideoCall)))
    }

    fun end() {
        _call.value?.end()
    }

    override fun onCleared() {
        SendBirdCall.removeListener(LISTENER_ID)
    }

    private fun callOptions(video: Boolean) = CallOptions().setVideoEnabled(video).setAudioEnabled(true)
}

/** Remote video full-screen with the local preview in the corner, both hosted via AndroidView. */
@Composable
fun DirectCallVideo(call: DirectCall, modifier: Modifier = Modifier) {
    Box(modifier) {
        AndroidView(
            factory = { context ->
                SendBirdVideoView(context).apply {
                    setScalingType(RendererCommon.ScalingType.SCALE_ASPECT_FIT)
                    setZOrderMediaOverlay(false)
                    setEnableHardwareScaler(true)
                    call.setRemoteVideoView(this)
                }
            },
            modifier = Modifier.fillMaxSize(),
        )
        AndroidView(
            factory = { context ->
                SendBirdVideoView(context).apply {
                    setScalingType(RendererCommon.ScalingType.SCALE_ASPECT_FIT)
                    setZOrderMediaOverlay(true)   // draw the small preview above the full-screen view
                    setEnableHardwareScaler(true)
                    call.setLocalVideoView(this)
                }
            },
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp)
                .size(width = 120.dp, height = 160.dp),
        )
    }
}
