// source: https://github.com/sendbird/sendbird-calls-javascript/blob/1.10.21/README.md ("Receive a call": register onRinging,
//   accept or decline with call.accept()/call.end(); DirectCall events onEstablished/onConnected/onEnded;
//   "remoteMediaView is required for the remote media stream to be displayed", autoplay recommended; verified 2026-10-17)
// sendbird-calls 1.10.21 SendBirdCall.min.d.ts: DirectCall.onEstablished / onConnected / onEnded are assignable
//   handlers, DirectCall.isVideoCall / remoteUser (verified 2026-10-17).
// Type-checked with tools/templates/compile-check-js.sh. The Calls calls themselves live in ./setup.ts.
// Render it after authenticate(...) succeeded (for example on the signed-in screen); the browser asks for
// the microphone, and the camera for a video call, the first time a call starts.

import { useEffect, useRef, useState } from 'react';
import { accept, dial, end, listenForCalls, type DirectCall } from './setup';

type CallState = 'idle' | 'dialing' | 'ringing' | 'connecting' | 'connected' | 'ended';

export function DirectCallPanel({ handlerId = 'direct-call-panel' }: { handlerId?: string }) {
  const [calleeId, setCalleeId] = useState('');
  const [state, setState] = useState<CallState>('idle');
  const [peer, setPeer] = useState('');
  const [isVideo, setIsVideo] = useState(false);
  const callRef = useRef<DirectCall | null>(null);
  const localRef = useRef<HTMLVideoElement>(null);
  const remoteRef = useRef<HTMLVideoElement>(null);

  const watch = (call: DirectCall) => {
    callRef.current = call;
    setIsVideo(call.isVideoCall);
    setPeer(call.remoteUser?.userId ?? '');
    call.onEstablished = () => setState('connecting');
    call.onConnected = () => setState('connected');
    call.onEnded = () => {
      callRef.current = null;
      setState('ended');
    };
  };

  useEffect(() => listenForCalls(handlerId, (call) => {
    if (callRef.current) { call.end(); return; }   // already in a call: decline the second one
    watch(call);
    setState('ringing');
  }), [handlerId]);

  const views = () => ({ local: localRef.current, remote: remoteRef.current });

  const startCall = (video: boolean) => {
    const id = calleeId.trim();
    if (!id || callRef.current) return;
    setState('dialing');
    watch(dial(id, video, views()));
    setPeer(id);
  };

  return (
    <section aria-label="Calls">
      <p role="status">
        Call: {state}{peer ? ` (${peer})` : ''}
      </p>
      {(state === 'idle' || state === 'ended') && (
        <div>
          <input aria-label="User ID to call" value={calleeId} onChange={(e) => setCalleeId(e.target.value)} />
          <button type="button" onClick={() => startCall(false)}>Voice call</button>
          <button type="button" onClick={() => startCall(true)}>Video call</button>
        </div>
      )}
      {state === 'ringing' && (
        <div>
          <button type="button" onClick={() => { setState('connecting'); if (callRef.current) accept(callRef.current, views()); }}>Accept</button>
          <button type="button" onClick={() => callRef.current && end(callRef.current)}>Decline</button>
        </div>
      )}
      {(state === 'dialing' || state === 'connecting' || state === 'connected') && (
        <button type="button" onClick={() => callRef.current && end(callRef.current)}>End</button>
      )}
      {/* The remote element carries the other side's audio too, so it stays mounted for voice calls. */}
      <video ref={remoteRef} autoPlay playsInline style={{ width: isVideo ? 320 : 0, height: isVideo ? 240 : 0 }} />
      <video ref={localRef} autoPlay playsInline muted style={{ width: isVideo ? 120 : 0, height: isVideo ? 90 : 0 }} />
    </section>
  );
}
