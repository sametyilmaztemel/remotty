import { useEffect, useRef, useState } from 'react';
import { useSignaling } from '../hooks/useSignaling';
import { useWebRTC } from '../hooks/useWebRTC';
import type { HostInfo } from '../lib/protocol';

interface Props {
  host: HostInfo;
  signalUrl: string;
}

export default function ScreenViewer({ host, signalUrl: _ }: Props) {
  const { client } = useSignaling();
  const videoRef = useRef<HTMLVideoElement>(null);
  const [active, setActive] = useState(false);
  const [status, setStatus] = useState('inactive');

  const webrtc = useWebRTC({
    signal: client!,
    room: `screen-${host.id}-${Date.now()}`,
    onStateChange: setStatus,
  });

  const startScreenShare = async () => {
    setActive(true);
    // WebRTC negotiation happens here
    // Host will send video track
    // Once received, display in <video> element
    client?.send({ type: 'screen_start', room: `screen-${host.id}-${Date.now()}` });
  };

  const stopScreenShare = () => {
    setActive(false);
    webrtc.close();
    client?.send({ type: 'screen_stop' });
  };

  return (
    <div className="screen-viewer">
      <div className="screen-header">
        <h2>{host.name} — Screen</h2>
        <div className="screen-controls">
          {!active ? (
            <button className="btn-primary" onClick={startScreenShare}>
              ▶ Start Screen Share
            </button>
          ) : (
            <button className="btn-danger" onClick={stopScreenShare}>
              ■ Stop
            </button>
          )}
        </div>
      </div>

      <div className={`screen-container ${active ? 'active' : ''}`}>
        {active ? (
          <video ref={videoRef} autoPlay className="screen-video" />
        ) : (
          <div className="screen-placeholder">
            <span className="placeholder-icon">🖵</span>
            <p>Screen sharing inactive</p>
            <p className="hint">Click 'Start Screen Share' to begin</p>
          </div>
        )}
      </div>

      <div className="screen-info">
        Status: <span className="status-text">{status}</span>
      </div>
    </div>
  );
}
