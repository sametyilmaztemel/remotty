import { useState, useRef, useCallback } from 'react';
import { WebRTCClient } from '../lib/webrtc';
import type { SignalingClient } from '../lib/signaling';
import type { Message } from '../lib/protocol';

interface UseWebRTCOptions {
  signal: SignalingClient;
  room: string;
  onDataChannel?: (label: string, dc: RTCDataChannel) => void;
  onStateChange?: (state: string) => void;
}

export function useWebRTC({ signal, room, onDataChannel, onStateChange }: UseWebRTCOptions) {
  const [connected, setConnected] = useState(false);
  const [state, setState] = useState('new');
  const rtcRef = useRef<WebRTCClient | null>(null);

  const init = useCallback(async (isOfferer: boolean) => {
    const rtc = new WebRTCClient();
    rtcRef.current = rtc;

    rtc.onIceCandidateCb((candidate) => {
      signal.send({ type: 'ice_candidate', payload: candidate, room });
    });

    rtc.onDataChannelCb((label, dc) => {
      onDataChannel?.(label, dc);
    });

    rtc.onStateChangeCb((state) => {
      setState(state);
      if (state === 'connected' || state === 'completed') {
        setConnected(true);
      }
      onStateChange?.(state);
    });

    // Listen for signaling messages
    const handleSignal = (msg: Message) => {
      switch (msg.type) {
        case 'offer':
          if (!isOfferer) {
            rtc.handleOffer(msg.payload as RTCSessionDescriptionInit).then(answer => {
              signal.send({ type: 'answer', payload: answer, room });
            });
          }
          break;
        case 'answer':
          if (isOfferer) {
            rtc.handleAnswer(msg.payload as RTCSessionDescriptionInit);
          }
          break;
        case 'ice_candidate':
          rtc.addIceCandidate(msg.payload as RTCIceCandidateInit);
          break;
      }
    };

    signal.on('offer', handleSignal);
    signal.on('answer', handleSignal);
    signal.on('ice_candidate', handleSignal);

    if (isOfferer) {
      const offer = await rtc.createOffer();
      signal.send({ type: 'offer', payload: offer, room });
    }

    return rtc;
  }, [signal, room, onDataChannel, onStateChange]);

  const close = useCallback(() => {
    rtcRef.current?.close();
    setConnected(false);
    setState('closed');
  }, []);

  const send = useCallback((label: string, data: ArrayBuffer | string) => {
    // Find the data channel by label
    const dc = (rtcRef.current as any)?.dataChannels?.get?.(label);
    if (dc?.readyState === 'open') {
      dc.send(data);
    }
  }, []);

  return { init, close, send, connected, state, rtc: rtcRef };
}
