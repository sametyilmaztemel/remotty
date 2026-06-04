import { useEffect, useRef, useState } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { WebLinksAddon } from 'xterm-addon-web-links';
import { useSignaling } from '../hooks/useSignaling';
import { useWebRTC } from '../hooks/useWebRTC';
import type { HostInfo } from '../lib/protocol';

const TERMINAL_THEME = {
  background: '#0f0f0f',
  foreground: '#c6c6c6',
  cursor: '#8b5cf6',
  cursorAccent: '#ffffff',
  selectionBackground: 'rgba(139, 92, 246, 0.25)',
  black: '#1a1a1a',
  red: '#e5484d',
  green: '#30a46c',
  yellow: '#f5a623',
  blue: '#6b8cff',
  magenta: '#c084fc',
  cyan: '#22d3ee',
  white: '#d4d4d4',
  brightBlack: '#404040',
  brightRed: '#ef4444',
  brightGreen: '#22c55e',
  brightYellow: '#facc15',
  brightBlue: '#60a5fa',
  brightMagenta: '#d8b4fe',
  brightCyan: '#67e8f9',
  brightWhite: '#ffffff',
};

interface Props {
  host: HostInfo;
  signalUrl: string;
}

export default function TerminalView({ host, signalUrl: _ }: Props) {
  const { client } = useSignaling();
  const termRef = useRef<HTMLDivElement>(null);
  const terminalRef = useRef<Terminal | null>(null);
  const fitRef = useRef<FitAddon | null>(null);
  const [status, setStatus] = useState('connecting...');

  const webrtc = useWebRTC({
    signal: client!,
    room: `term-${host.id}-${Date.now()}`,
    onDataChannel: (label, dc) => {
      if (label === 'terminal' && terminalRef.current) {
        dc.onmessage = (event) => {
          const data = typeof event.data === 'string'
            ? event.data
            : new TextDecoder().decode(event.data);
          terminalRef.current?.write(data);
        };
      }
    },
    onStateChange: setStatus,
  });

  useEffect(() => {
    if (!termRef.current) return;

    const term = new Terminal({
      cursorBlink: true,
      cursorStyle: 'block',
      fontSize: 13,
      fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
      lineHeight: 1.35,
      letterSpacing: 0,
      theme: TERMINAL_THEME,
      allowTransparency: false,
      scrollback: 5000,
      smoothScrollDuration: 0,
    });

    const fitAddon = new FitAddon();
    term.loadAddon(fitAddon);
    term.loadAddon(new WebLinksAddon());

    term.open(termRef.current);
    fitAddon.fit();
    term.focus();

    terminalRef.current = term;
    fitRef.current = fitAddon;

    term.onData((data) => {
      webrtc.send('terminal', data);
    });

    const observer = new ResizeObserver(() => {
      try { fitAddon.fit(); } catch {}
    });
    observer.observe(termRef.current);

    webrtc.init(true);

    return () => {
      observer.disconnect();
      webrtc.close();
      term.dispose();
    };
  }, []);

  return (
    <div className="terminal-screen">
      <div className="terminal-header">
        <div className="terminal-title">
          <span className="status-indicator small online" />
          {host.name}
          <span className="terminal-subtitle">{status}</span>
        </div>
        <div className="terminal-controls">
          <button className="btn-small" onClick={() => fitRef.current?.fit()}>
            Fit
          </button>
          <button className="btn-small" onClick={() => terminalRef.current?.clear()}>
            Clear
          </button>
        </div>
      </div>
      <div className="terminal-container" ref={termRef} />
    </div>
  );
}
