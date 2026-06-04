import { useEffect, useRef, useState } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { WebLinksAddon } from 'xterm-addon-web-links';
import { SearchAddon } from 'xterm-addon-search';
import { useSignaling } from '../hooks/useSignaling';
import { useWebRTC } from '../hooks/useWebRTC';
import type { HostInfo, Message } from '../lib/protocol';

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

  // Initialize WebRTC
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
      fontSize: 14,
      fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
      allowTransparency: true,
      theme: {
        background: '#0a0a0a',
        foreground: '#a3a3a3',
        cursor: '#8b5cf6',
        cursorAccent: '#000000',
        selectionBackground: 'rgba(139, 92, 246, 0.3)',
        black: '#000000',
        red: '#ef4444',
        green: '#22c55e',
        yellow: '#eab308',
        blue: '#3b82f6',
        magenta: '#a855f7',
        cyan: '#06b6d4',
        white: '#e0e0e0',
        brightBlack: '#555555',
        brightRed: '#ef4444',
        brightGreen: '#22c55e',
        brightYellow: '#eab308',
        brightBlue: '#60a5fa',
        brightMagenta: '#c084fc',
        brightCyan: '#22d3ee',
        brightWhite: '#ffffff',
      },
    });

    const fitAddon = new FitAddon();
    term.loadAddon(fitAddon);
    term.loadAddon(new WebLinksAddon());
    term.loadAddon(new SearchAddon());

    term.open(termRef.current);
    fitAddon.fit();
    term.focus();

    terminalRef.current = term;
    fitRef.current = fitAddon;

    // Handle terminal input
    term.onData((data) => {
      webrtc.send('terminal', data);
    });

    // Handle resize
    const observer = new ResizeObserver(() => {
      try { fitAddon.fit(); } catch {}
    });
    observer.observe(termRef.current);

    // Init WebRTC
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
          {host.name} — {status}
        </div>
        <div className="terminal-controls">
          <button className="btn-small" onClick={() => fitRef.current?.fit()}>
            ⊞ Fit
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
