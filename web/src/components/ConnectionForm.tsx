import { useState, type FormEvent } from 'react';

interface Props {
  onConnect: (url: string) => void;
  initialUrl: string;
}

export default function ConnectionForm({ onConnect, initialUrl }: Props) {
  const [url, setUrl] = useState(initialUrl);
  const [password, setPassword] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    onConnect(url);
  };

  return (
    <div className="connect-screen">
      <div className="connect-card">
        <div className="connect-logo">
          <span className="logo-icon">⎈</span>
          <h1>remotyy</h1>
          <p className="tagline">remote terminal · open source</p>
        </div>

        <form onSubmit={handleSubmit} className="connect-form">
          <div className="field">
            <label>Signaling Server</label>
            <input
              type="text"
              value={url}
              onChange={e => setUrl(e.target.value)}
              placeholder="ws://host:port"
              className="input mono"
            />
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
      </div>
    </div>
  );
}
