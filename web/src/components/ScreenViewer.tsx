import { useEffect, useRef, useState, useCallback } from 'react';
import { useSignaling } from '../hooks/useSignaling';
import { useWebRTC } from '../hooks/useWebRTC';
import type { HostInfo, ScreenDCMessage } from '../lib/protocol';

interface Props {
  host: HostInfo;
  signalUrl: string;
}

const ZOOM_MIN = 0.1;
const ZOOM_MAX = 10;
const ZOOM_WHEEL_SENSITIVITY = 0.001;

type ConnectionStatus =
  | 'disconnected'
  | 'connecting'
  | 'starting'
  | 'connected'
  | 'stopping'
  | 'error';

export default function ScreenViewer({ host }: Props) {
  const { client } = useSignaling();

  // ── Refs ──────────────────────────────────────
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const dcRef = useRef<RTCDataChannel | null>(null);
  const frameCountRef = useRef(0);
  const lastFpsTimeRef = useRef(performance.now());
  const fpsIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const screenWidthRef = useRef(0);
  const screenHeightRef = useRef(0);
  const pointerLockActiveRef = useRef(false);
  const lastPinchDistRef = useRef(0);
  const virtualCursorRef = useRef({ x: 0, y: 0 });
  const zoomRef = useRef(1);
  const roomRef = useRef(`screen-${host.id}-${Date.now()}`);
  const mountedRef = useRef(true);

  // ── State ─────────────────────────────────────
  const [active, setActive] = useState(false);
  const [status, setStatus] = useState<ConnectionStatus>('disconnected');
  const [fpsDisplay, setFpsDisplay] = useState(0);
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('disconnected');
  const [zoom, setZoom] = useState(1);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [screenResolution, setScreenResolution] = useState({ width: 0, height: 0 });

  // ── WebRTC Hook ───────────────────────────────
  const webrtc = useWebRTC({
    signal: client!,
    room: roomRef.current,
    onDataChannel(label, dc) {
      if (label === 'screen') {
        setupDataChannel(dc);
      }
    },
    onStateChange(state) {
      setConnectionStatus(state as ConnectionStatus);
      if (state === 'connected' || state === 'completed') {
        setStatus('connected');
      } else if (state === 'failed') {
        setStatus('error');
        setActive(false);
      } else if (state === 'disconnected' || state === 'closed') {
        setStatus('disconnected');
        setActive(false);
      }
    },
  });

  // ── Data Channel Setup ────────────────────────
  const handleScreenMessage = useCallback((event: MessageEvent) => {
    if (!mountedRef.current) return;

    try {
      const raw = typeof event.data === 'string'
        ? event.data
        : new TextDecoder().decode(event.data as ArrayBuffer);
      const msg: ScreenDCMessage = JSON.parse(raw);

      if (msg.type === 'screen_frame') {
        const { width, height, data } = msg.payload;

        // Update tracked resolution
        if (width !== screenWidthRef.current || height !== screenHeightRef.current) {
          screenWidthRef.current = width;
          screenHeightRef.current = height;
          setScreenResolution({ width, height });
        }

        // Decode base64 JPEG bytes
        const binaryStr = atob(data);
        const len = binaryStr.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryStr.charCodeAt(i);
        }

        const blob = new Blob([bytes], { type: 'image/jpeg' });

        createImageBitmap(blob)
          .then((bitmap) => {
            const canvas = canvasRef.current;
            if (!canvas || !mountedRef.current) {
              bitmap.close();
              return;
            }

            // Resize canvas if needed
            const dpr = window.devicePixelRatio || 1;
            const displayW = Math.round(width / dpr);
            const displayH = Math.round(height / dpr);
            if (canvas.width !== width || canvas.height !== height) {
              canvas.width = width;
              canvas.height = height;
              // Match CSS size to natural resolution (accounting for DPR)
              canvas.style.width = `${displayW}px`;
              canvas.style.height = `${displayH}px`;
            }

            const ctx = canvas.getContext('2d');
            if (ctx) {
              ctx.imageSmoothingEnabled = false;
              ctx.drawImage(bitmap, 0, 0);
            }
            bitmap.close();

            frameCountRef.current++;
          })
          .catch((err) => {
            console.error('[ScreenViewer] Failed to decode frame bitmap:', err);
          });
      }
    } catch (err) {
      console.error('[ScreenViewer] Failed to parse data channel message:', err);
    }
  }, []);

  const setupDataChannel = useCallback((dc: RTCDataChannel) => {
    dcRef.current = dc;
    dc.binaryType = 'arraybuffer';
    dc.onmessage = handleScreenMessage;
    dc.onopen = () => {
      setConnectionStatus('connected');
      setStatus('connected');
    };
    dc.onclose = () => {
      setConnectionStatus('disconnected');
      if (mountedRef.current) setStatus('disconnected');
    };
    dc.onerror = (err) => {
      console.error('[ScreenViewer] Data channel error:', err);
      setConnectionStatus('error');
    };
  }, [handleScreenMessage]);

  // ── FPS Counter ───────────────────────────────
  useEffect(() => {
    lastFpsTimeRef.current = performance.now();
    frameCountRef.current = 0;

    fpsIntervalRef.current = setInterval(() => {
      const now = performance.now();
      const elapsed = now - lastFpsTimeRef.current;
      if (elapsed > 0) {
        setFpsDisplay(Math.round((frameCountRef.current / elapsed) * 1000));
      }
      frameCountRef.current = 0;
      lastFpsTimeRef.current = now;
    }, 1000);

    return () => {
      if (fpsIntervalRef.current) {
        clearInterval(fpsIntervalRef.current);
        fpsIntervalRef.current = null;
      }
    };
  }, []);

  // ── Start / Stop ──────────────────────────────
  const startScreenShare = useCallback(async () => {
    try {
      setStatus('connecting');
      setActive(true);

      // Init WebRTC as offerer
      await webrtc.init(true);

      if (!mountedRef.current) return;

      // Create the screen data channel
      const dc = webrtc.rtc.current?.createDataChannel('screen');
      if (dc) {
        setupDataChannel(dc);
        dcRef.current = dc;
      } else {
        throw new Error('Failed to create screen data channel');
      }

      // Notify the host to start screen capture
      setStatus('starting');
      client?.send({ type: 'screen_start', room: roomRef.current });
    } catch (err) {
      console.error('[ScreenViewer] Failed to start:', err);
      setStatus('error');
      setActive(false);
      webrtc.close();
    }
  }, [webrtc, client, setupDataChannel]);

  const stopScreenShare = useCallback(() => {
    try {
      setStatus('stopping');
      client?.send({ type: 'screen_stop' });
    } catch (err) {
      console.error('[ScreenViewer] Error sending stop:', err);
    }

    webrtc.close();
    dcRef.current = null;

    // Clear canvas
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
    }

    // Exit pointer lock if active
    if (document.pointerLockElement) {
      try { document.exitPointerLock(); } catch (_) { /* noop */ }
    }

    if (mountedRef.current) {
      setActive(false);
      setStatus('disconnected');
      setConnectionStatus('disconnected');
      setFpsDisplay(0);
      setScreenResolution({ width: 0, height: 0 });
    }
  }, [webrtc, client]);

  // ── Send Helpers ──────────────────────────────
  const sendOverDC = useCallback((msg: ScreenDCMessage) => {
    try {
      if (dcRef.current?.readyState === 'open') {
        dcRef.current.send(JSON.stringify(msg));
      }
    } catch (err) {
      console.error('[ScreenViewer] Send failed:', err);
    }
  }, []);

  // ── Mouse Events ──────────────────────────────
  const getCanvasCoords = useCallback((clientX: number, clientY: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    const z = zoomRef.current;
    return {
      x: Math.round((clientX - rect.left) / z),
      y: Math.round((clientY - rect.top) / z),
    };
  }, []);

  const handleMouseMove = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!dcRef.current || dcRef.current.readyState !== 'open') return;
    const canvas = canvasRef.current;
    if (!canvas) return;

    if (document.pointerLockElement === canvas) {
      // Pointer lock: accumulate relative movement
      virtualCursorRef.current.x = Math.max(0, virtualCursorRef.current.x + e.movementX);
      virtualCursorRef.current.y = Math.max(0, virtualCursorRef.current.y + e.movementY);

      // Clamp to screen bounds
      if (screenWidthRef.current > 0) {
        virtualCursorRef.current.x = Math.min(screenWidthRef.current, virtualCursorRef.current.x);
      }
      if (screenHeightRef.current > 0) {
        virtualCursorRef.current.y = Math.min(screenHeightRef.current, virtualCursorRef.current.y);
      }

      sendOverDC({
        type: 'mouse_move',
        payload: { x: virtualCursorRef.current.x, y: virtualCursorRef.current.y },
      });
    } else {
      const { x, y } = getCanvasCoords(e.clientX, e.clientY);
      virtualCursorRef.current = { x, y };
      sendOverDC({ type: 'mouse_move', payload: { x, y } });
    }
  }, [sendOverDC, getCanvasCoords]);

  const sendMouseClick = useCallback((
    button: number,
    clientX: number,
    clientY: number,
    down: boolean,
  ) => {
    const { x, y } = getCanvasCoords(clientX, clientY);
    sendOverDC({ type: 'mouse_click', payload: { button, x, y, down } });
  }, [sendOverDC, getCanvasCoords]);

  const handleMouseDown = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    sendMouseClick(e.button, e.clientX, e.clientY, true);
  }, [sendMouseClick]);

  const handleMouseUp = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    sendMouseClick(e.button, e.clientX, e.clientY, false);
  }, [sendMouseClick]);

  const handleWheel = useCallback((e: React.WheelEvent<HTMLCanvasElement>) => {
    if (e.ctrlKey || e.metaKey) {
      // Zoom with Ctrl/Meta + wheel
      e.preventDefault();
      const delta = -e.deltaY * ZOOM_WHEEL_SENSITIVITY;
      const newZoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, zoomRef.current + delta));
      zoomRef.current = newZoom;
      setZoom(newZoom);
    } else if (dcRef.current?.readyState === 'open') {
      // Scroll event to remote host
      sendOverDC({
        type: 'mouse_scroll',
        payload: { delta_x: e.deltaX, delta_y: e.deltaY },
      });
    }
  }, [sendOverDC]);

  // ── Pointer Lock ──────────────────────────────
  const handleCanvasDoubleClick = useCallback((e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas || !active) return;
    e.preventDefault();
    try {
      canvas.requestPointerLock();
    } catch (err) {
      console.warn('[ScreenViewer] Pointer lock request denied:', err);
    }
  }, [active]);

  useEffect(() => {
    const handlePointerLockChange = () => {
      pointerLockActiveRef.current = document.pointerLockElement === canvasRef.current;
    };
    const handlePointerLockError = () => {
      console.warn('[ScreenViewer] Pointer lock error');
    };
    document.addEventListener('pointerlockchange', handlePointerLockChange);
    document.addEventListener('pointerlockerror', handlePointerLockError);
    return () => {
      document.removeEventListener('pointerlockchange', handlePointerLockChange);
      document.removeEventListener('pointerlockerror', handlePointerLockError);
    };
  }, []);

  // ── Keyboard Events ───────────────────────────
  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLDivElement>) => {
    if (!dcRef.current || dcRef.current.readyState !== 'open') return;
    // Let ctrl/meta/alt combos through (browser shortcuts)
    if (e.ctrlKey || e.metaKey) return;
    sendOverDC({
      type: 'key_press',
      payload: { key_code: e.keyCode, chars: e.key, down: true },
    });
    e.preventDefault();
  }, [sendOverDC]);

  const handleKeyUp = useCallback((e: React.KeyboardEvent<HTMLDivElement>) => {
    if (!dcRef.current || dcRef.current.readyState !== 'open') return;
    if (e.ctrlKey || e.metaKey) return;
    sendOverDC({
      type: 'key_press',
      payload: { key_code: e.keyCode, chars: e.key, down: false },
    });
    e.preventDefault();
  }, [sendOverDC]);

  // ── Touch / Mobile ────────────────────────────
  const handleTouchStart = useCallback((e: React.TouchEvent<HTMLCanvasElement>) => {
    e.preventDefault();
    if (e.touches.length === 2) {
      // Pinch start
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      lastPinchDistRef.current = Math.sqrt(dx * dx + dy * dy);
    } else if (e.touches.length === 1 && dcRef.current?.readyState === 'open') {
      sendMouseClick(0, e.touches[0].clientX, e.touches[0].clientY, true);
    }
  }, [sendMouseClick]);

  const handleTouchMove = useCallback((e: React.TouchEvent<HTMLCanvasElement>) => {
    e.preventDefault();
    if (e.touches.length === 2) {
      // Pinch zoom
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (lastPinchDistRef.current > 0) {
        const scale = dist / lastPinchDistRef.current;
        const newZoom = Math.max(
          ZOOM_MIN,
          Math.min(ZOOM_MAX, zoomRef.current * scale),
        );
        zoomRef.current = newZoom;
        setZoom(newZoom);
      }
      lastPinchDistRef.current = dist;
    } else if (e.touches.length === 1 && dcRef.current?.readyState === 'open') {
      sendOverDC({
        type: 'mouse_move',
        payload: {
          x: Math.round(e.touches[0].clientX),
          y: Math.round(e.touches[0].clientY),
        },
      });
    }
  }, [sendOverDC]);

  const handleTouchEnd = useCallback((e: React.TouchEvent<HTMLCanvasElement>) => {
    e.preventDefault();
    lastPinchDistRef.current = 0;
    if (dcRef.current?.readyState === 'open') {
      // Send mouse up on touch end (touch → mouse click emulation)
      // We send button=0 (left) mouse up at origin; the remote should use the last move position
      sendOverDC({
        type: 'mouse_click',
        payload: { button: 0, x: 0, y: 0, down: false },
      });
    }
  }, [sendOverDC]);

  // ── Fullscreen ────────────────────────────────
  const toggleFullscreen = useCallback(() => {
    if (!document.fullscreenElement) {
      containerRef.current?.requestFullscreen().catch((err) => {
        console.warn('[ScreenViewer] Fullscreen request denied:', err);
      });
    } else {
      document.exitFullscreen().catch((err) => {
        console.warn('[ScreenViewer] Exit fullscreen failed:', err);
      });
    }
  }, []);

  useEffect(() => {
    const handleFSChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener('fullscreenchange', handleFSChange);
    return () => document.removeEventListener('fullscreenchange', handleFSChange);
  }, []);

  // ── Reset Zoom ────────────────────────────────
  const resetZoom = useCallback(() => {
    zoomRef.current = 1;
    setZoom(1);
  }, []);

  // ── Cleanup on Unmount ────────────────────────
  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      dcRef.current = null;
      webrtc.close();
    };
  }, [webrtc]);

  // ── Status label helpers ──────────────────────
  const statusLabel = {
    disconnected: 'Disconnected',
    connecting: 'Connecting…',
    starting: 'Starting screen share…',
    connected: 'Connected',
    stopping: 'Stopping…',
    error: 'Error',
  }[status] || status;

  const zoomPercent = Math.round(zoom * 100);

  // ── Render ────────────────────────────────────
  return (
    <div
      className="screen-viewer"
      ref={containerRef}
      tabIndex={-1}
      onKeyDown={handleKeyDown}
      onKeyUp={handleKeyUp}
    >
      {/* ─── Header Bar ──────────────────────── */}
      <div className="screen-header">
        <div className="screen-title">
          <span className="screen-title-icon">🖥</span>
          <span>{host.name}</span>
          {active && screenResolution.width > 0 && (
            <span className="screen-resolution">
              {screenResolution.width} &times; {screenResolution.height}
            </span>
          )}
        </div>

        <div className="screen-header-center">
          <span className={`status-dot ${connectionStatus}`} />
          <span className="status-label">{statusLabel}</span>
        </div>

        <div className="screen-controls">
          {active && (
            <>
              <span className="fps-counter" title="Frames per second">
                {fpsDisplay} FPS
              </span>

              <button
                className="btn-icon"
                title={`Zoom: ${zoomPercent}% — click to reset`}
                onClick={resetZoom}
              >
                {zoomPercent}%
              </button>

              <button
                className="btn-icon"
                title={isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen'}
                onClick={toggleFullscreen}
              >
                {isFullscreen ? '⊠' : '⊞'}
              </button>

              <button className="btn-danger" onClick={stopScreenShare}>
                ■ Stop
              </button>
            </>
          )}

          {!active && (
            <button className="btn-primary" onClick={startScreenShare}>
              ▶ Start Screen Share
            </button>
          )}
        </div>
      </div>

      {/* ─── Screen Area ─────────────────────── */}
      <div className={`screen-container ${active ? 'active' : ''}`}>
        {active ? (
          <div className="screen-canvas-wrapper" style={{ transform: `scale(${zoom})`, transformOrigin: '0 0' }}>
            <canvas
              ref={canvasRef}
              className="screen-canvas"
              onMouseMove={handleMouseMove}
              onMouseDown={handleMouseDown}
              onMouseUp={handleMouseUp}
              onDoubleClick={handleCanvasDoubleClick}
              onWheel={handleWheel}
              onTouchStart={handleTouchStart}
              onTouchMove={handleTouchMove}
              onTouchEnd={handleTouchEnd}
            />
          </div>
        ) : (
          <div className="screen-placeholder">
            <span className="placeholder-icon">🖵</span>
            <p>Screen sharing inactive</p>
            <p className="hint">Click &lsquo;Start Screen Share&rsquo; to begin</p>
          </div>
        )}
      </div>

      {/* ─── HUD overlay (only when connected) ─── */}
      {active && connectionStatus === 'connected' && (
        <div className="screen-hud">
          {pointerLockActiveRef.current && (
            <span className="hud-badge">Pointer Locked — Press ESC to release</span>
          )}
        </div>
      )}
    </div>
  );
}
