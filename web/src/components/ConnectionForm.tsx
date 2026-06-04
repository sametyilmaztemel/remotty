import { useState, type FormEvent } from 'react';

interface Props {
  onConnect: (url: string) => void;
  initialUrl: string;
}

export default function ConnectionForm({ onConnect, initialUrl }: Props) {
  const [url, setUrl] = useState(initialUrl);
  const [password, setPassword] = useState('');
  const [showHelp, setShowHelp] = useState(false);
  const [showQuickStart, setShowQuickStart] = useState(false);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    onConnect(url);
  };

  const detectLocalIP = async () => {
    try {
      const pc = new RTCPeerConnection();
      pc.createDataChannel('');
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      pc.addEventListener('icecandidate', (e) => {
        if (e.candidate) {
          const ip = e.candidate.candidate.split(' ')[4];
          if (ip && !ip.includes(':')) {
            setUrl(`ws://${ip}:9000`);
          }
          pc.close();
        }
      });
      setTimeout(() => pc.close(), 2000);
    } catch {}
  };

  return (
    <div className="connect-screen">
      <div className="connect-card">
        <div className="connect-logo">
          <span className="logo-icon">⎈</span>
          <h1>remotyy</h1>
          <p className="tagline">remote terminal &middot; open source</p>
        </div>

        <form onSubmit={handleSubmit} className="connect-form">
          <div className="field">
            <label>Signaling Server</label>
            <div style={{ display: 'flex', gap: 4 }}>
              <input
                type="text"
                value={url}
                onChange={e => setUrl(e.target.value)}
                placeholder="ws://host:port"
                className="input mono"
                style={{ flex: 1 }}
              />
              <button type="button" className="btn-small" onClick={detectLocalIP} title="Auto-detect local IP">
                ↻
              </button>
            </div>
          </div>
          <div className="field">
            <label>Master Password <span className="optional">(optional)</span></label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="Leave blank if not set"
              className="input mono"
            />
          </div>
          <button type="submit" className="btn-primary">
            ⚡ Connect
          </button>
        </form>

        <div style={{ marginTop: 20 }}>
          <button
            className="btn-text"
            onClick={() => setShowQuickStart(!showQuickStart)}
            style={{
              background: 'none', border: 'none', color: 'var(--accent)',
              cursor: 'pointer', fontSize: 12, width: '100%', textAlign: 'center',
              padding: 8,
            }}
          >
            {showQuickStart ? '▾ Hide quick start' : '▸ Quick start guide'}
          </button>

          {showQuickStart && (
            <div style={{
              background: 'var(--bg-card)', border: '1px solid var(--border)',
              borderRadius: 8, padding: 16, fontSize: 11, lineHeight: 1.6,
              marginTop: 8,
            }}>
              <strong style={{ fontSize: 12 }}>Test between Mac and iPhone</strong>
              <ol style={{ margin: '8px 0', paddingLeft: 20 }}>
                <li>Mac'te terminal aç: <code>remotyy signal --dev</code></li>
                <li>Başka terminal: <code>remotyy host --signal ws://localhost:9000</code></li>
                <li>Mac'in IP'sini bul: <code>ipconfig getifaddr en0</code></li>
                <li>iPhone'da Safari'den <code>http://&lt;MAC_IP&gt;:3000</code></li>
                <li>Bağlantı URL'ine <code>ws://&lt;MAC_IP&gt;:9000</code> yaz → Connect</li>
              </ol>
              <strong style={{ fontSize: 12 }}>Requirements</strong>
              <ul style={{ margin: '8px 0', paddingLeft: 20 }}>
                <li>Mac ve iPhone aynı WiFi'da</li>
                <li>Web client build edilmiş: <code>cd web && npm run build</code></li>
                <li>Web server: <code>npx serve web/dist -l 3000</code></li>
              </ul>
              <strong style={{ fontSize: 12 }}>From anywhere (internet)</strong>
              <ul style={{ margin: '8px 0', paddingLeft: 20 }}>
                <li>Signaling server'ı public IP'de veya Cloudflare Tunnel arkasında çalıştır</li>
                <li>Host'u remote sunucuda başlat</li>
                <li>Web client'ı da aynı host'ta serve et</li>
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
