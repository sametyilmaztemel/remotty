// remotyy — Web client
// Connects to signaling server, establishes WebRTC, opens terminal.

let signalConn = null;
let peerConn = null;
let term = null;
let fitAddon = null;
let currentHostId = null;
let dataChannels = {};

// ─── Connection ────────────────────────────────────────────
async function connect() {
  const signalURL = document.getElementById('signal-url').value.trim();
  if (!signalURL) {
    showStatus('Please enter a signaling server URL', 'error');
    return;
  }

  showStatus(`Connecting to ${signalURL}...`, 'info');
  document.getElementById('connect-btn').disabled = true;

  try {
    signalConn = new WebSocket(signalURL + '/ws');

    signalConn.onopen = () => {
      showStatus('Connected to signaling server', 'info');
      // Request host list
      sendSignal('request_host', {});
    };

    signalConn.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      handleSignalMessage(msg);
    };

    signalConn.onclose = () => {
      showStatus('Disconnected from signaling server', 'error');
      document.getElementById('connect-btn').disabled = false;
      document.getElementById('host-list').classList.add('hidden');
    };

    signalConn.onerror = () => {
      showStatus('Connection failed', 'error');
      document.getElementById('connect-btn').disabled = false;
    };
  } catch (err) {
    showStatus(`Error: ${err.message}`, 'error');
    document.getElementById('connect-btn').disabled = false;
  }
}

function disconnect() {
  if (peerConn) peerConn.close();
  if (signalConn) signalConn.close();
  if (term) term.dispose();
  peerConn = null;
  signalConn = null;
  term = null;
  showTerminalScreen(false);
  document.getElementById('connect-btn').disabled = false;
  showStatus('Disconnected', 'info');
}

// ─── Signaling ─────────────────────────────────────────────
function sendSignal(type, payload) {
  if (signalConn && signalConn.readyState === WebSocket.OPEN) {
    signalConn.send(JSON.stringify({ type, payload }));
  }
}

function handleSignalMessage(msg) {
  switch (msg.type) {
    case 'request_host':
      handleHostList(msg.payload);
      break;
    case 'approved':
      startWebRTC(msg.payload);
      break;
    case 'offer':
      handleOffer(msg);
      break;
    case 'ice_candidate':
      handleICE(msg);
      break;
    case 'error':
      showStatus(`Error: ${msg.payload?.message || 'unknown'}`, 'error');
      break;
  }
}

// ─── Host List ─────────────────────────────────────────────
function handleHostList(payload) {
  const container = document.getElementById('hosts-container');
  container.innerHTML = '';

  const hosts = payload?.hosts || [];
  const list = document.getElementById('host-list');

  if (hosts.length === 0) {
    container.innerHTML = '<div class="host-item"><span class="host-meta">No hosts online</span></div>';
    list.classList.remove('hidden');
    return;
  }

  hosts.forEach(host => {
    const item = document.createElement('div');
    item.className = 'host-item';
    item.innerHTML = `
      <div>
        <div class="host-name"><span class="host-status"></span>${escapeHtml(host.name || host.id)}</div>
        <div class="host-meta">${host.platform || '?'} / ${host.arch || '?'} · ${(host.features || []).join(', ') || 'terminal'}</div>
      </div>
      <div style="color: #666; font-family: var(--font-mono); font-size: 0.8rem;">→</div>
    `;
    item.onclick = () => selectHost(host.id);
    container.appendChild(item);
  });

  list.classList.remove('hidden');
  showStatus(`${hosts.length} host(s) available`, 'info');
}

function selectHost(hostId) {
  currentHostId = hostId;
  showStatus(`Connecting to host ${hostId}...`, 'info');

  // Request connection to specific host
  sendSignal('request_host', { host_id: hostId });
}

// ─── WebRTC ────────────────────────────────────────────────
async function startWebRTC(payload) {
  showStatus('Establishing encrypted connection...', 'info');

  const config = {
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
    ]
  };

  peerConn = new RTCPeerConnection(config);

  peerConn.onicecandidate = (event) => {
    if (event.candidate && signalConn) {
      sendSignal('ice_candidate', event.candidate.toJSON());
    }
  };

  peerConn.oniceconnectionstatechange = () => {
    const state = peerConn.iceConnectionState;
    console.log('ICE state:', state);
    if (state === 'connected' || state === 'completed') {
      showStatus('Connected — encrypted tunnel established', 'info');
      document.getElementById('host-list').classList.add('hidden');
    }
    if (state === 'disconnected' || state === 'failed') {
      showStatus('Connection lost', 'error');
      disconnect();
    }
  };

  // Handle data channels
  peerConn.ondatachannel = (event) => {
    const dc = event.channel;
    dataChannels[dc.label] = dc;

    dc.onopen = () => {
      console.log(`Data channel '${dc.label}' opened`);
      if (dc.label === 'terminal') {
        showTerminalScreen(true);
        setupTerminal();
      }
      if (dc.label === 'auth') {
        // Send master password if provided
        const pw = document.getElementById('master-password').value;
        if (pw) {
          dc.send(JSON.stringify({ type: 'auth', payload: { password: pw } }));
        }
      }
    };

    dc.onmessage = (event) => {
      if (dc.label === 'terminal' && term) {
        term.write(event.data);
      }
      if (dc.label === 'auth') {
        try {
          const resp = JSON.parse(event.data);
          if (resp.type === 'auth_fail') {
            showStatus('❌ Master password rejected', 'error');
            disconnect();
          }
        } catch (e) {}
      }
    };
  };

  // Create and send offer
  const dc = peerConn.createDataChannel('terminal');
  dataChannels['terminal'] = dc;

  // Also create auth channel if needed
  const authDC = peerConn.createDataChannel('auth');
  dataChannels['auth'] = authDC;

  const offer = await peerConn.createOffer();
  await peerConn.setLocalDescription(offer);
  sendSignal('offer', { type: offer.type, sdp: offer.sdp });
}

async function handleOffer(msg) {
  if (!peerConn) {
    const config = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
      ]
    };
    peerConn = new RTCPeerConnection(config);

    peerConn.onicecandidate = (event) => {
      if (event.candidate) {
        sendSignal('ice_candidate', event.candidate.toJSON());
      }
    };

    peerConn.ondatachannel = (event) => {
      const dc = event.channel;
      dataChannels[dc.label] = dc;
      dc.onopen = () => {
        if (dc.label === 'terminal') {
          showTerminalScreen(true);
          setupTerminal();
        }
      };
      dc.onmessage = (e) => {
        if (dc.label === 'terminal' && term) term.write(e.data);
      };
    };
  }

  await peerConn.setRemoteDescription(new RTCSessionDescription(msg.payload));
  const answer = await peerConn.createAnswer();
  await peerConn.setLocalDescription(answer);
  sendSignal('answer', { type: answer.type, sdp: answer.sdp });
}

function handleICE(msg) {
  if (peerConn && msg.payload) {
    peerConn.addIceCandidate(new RTCIceCandidate(msg.payload)).catch(e => console.error('ICE error:', e));
  }
}

// ─── Terminal ──────────────────────────────────────────────
function setupTerminal() {
  const container = document.getElementById('terminal-container');
  container.innerHTML = '';

  term = new Terminal({
    cursorBlink: true,
    cursorStyle: 'block',
    fontSize: 14,
    fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
    theme: {
      background: '#0a0a0a',
      foreground: '#a3a3a3',
      cursor: '#8b5cf6',
      selection: 'rgba(139,92,246,0.3)',
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

  const fitAddon = new FitAddon.FitAddon();
  term.loadAddon(fitAddon);
  term.open(container);
  fitAddon.fit();

  // Handle terminal input
  term.onData((data) => {
    const dc = dataChannels['terminal'];
    if (dc && dc.readyState === 'open') {
      dc.send(data);
    }
  });

  // Handle resize
  const observer = new ResizeObserver(() => {
    try { fitAddon.fit(); } catch(e) {}
  });
  observer.observe(container);

  term.focus();
  document.getElementById('term-title').textContent =
    `remotyy — ${currentHostId || 'connected'}`;
}

// ─── UI Helpers ────────────────────────────────────────────
function showStatus(message, type) {
  const el = document.getElementById('connection-status');
  el.textContent = message;
  el.className = `status ${type || 'info'}`;
}

function showTerminalScreen(show) {
  document.getElementById('connect-screen').classList.toggle('hidden', show);
  document.getElementById('terminal-screen').classList.toggle('hidden', !show);
}

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen();
  } else {
    document.exitFullscreen();
  }
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// ─── Keyboard shortcuts ───────────────────────────────────
document.addEventListener('keydown', (e) => {
  if (e.ctrlKey && e.key === 'q') { disconnect(); e.preventDefault(); }
  if (e.key === 'Escape' && document.fullscreenElement) { document.exitFullscreen(); }
});
