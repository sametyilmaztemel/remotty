import { useEffect, useState } from 'react';
import { useSignaling } from '../hooks/useSignaling';
import type { HostInfo, Message } from '../lib/protocol';

interface Props {
  onSelect: (host: HostInfo) => void;
}

export default function HostList({ onSelect }: Props) {
  const { client, status, connect } = useSignaling();
  const [hosts, setHosts] = useState<HostInfo[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!client) return;

    client.on('host_list', (msg: Message) => {
      const payload = msg.payload as { hosts: HostInfo[] };
      if (payload?.hosts) {
        setHosts(payload.hosts);
      }
    });

    client.on('error', (msg: Message) => {
      const payload = msg.payload as { message?: string };
      setError(payload?.message || 'Unknown error');
    });

    // Connect and request hosts
    connect().then(() => {
      client.send({ type: 'list_hosts' });
    }).catch(err => {
      setError(err.message || 'Failed to connect');
    });
  }, [client, connect]);

  const handleConnect = (host: HostInfo) => {
    client?.send({ type: 'connect', payload: { host_id: host.id } });
    // Wait for room_ready
    client?.on('room_ready', () => {
      onSelect(host);
    });
  };

  return (
    <div className="host-list-screen">
      <div className="host-list-header">
        <h2>Available Hosts</h2>
        <span className="status-badge">
          <span className={`status-indicator ${status === 'connected' ? 'online' : 'offline'}`} />
          {status}
        </span>
      </div>

      {error && <div className="error-msg">{error}</div>}

      <div className="host-grid">
        {hosts.length === 0 && (
          <div className="empty-state">
            <span className="empty-icon">⎈</span>
            <p>No hosts online</p>
            <p className="hint">Start a host with: <code>remotyy host</code></p>
          </div>
        )}

        {hosts.map(host => (
          <div key={host.id} className="host-card" onClick={() => handleConnect(host)}>
            <div className="host-card-header">
              <span className="host-status-dot" />
              <span className="host-name">{host.name}</span>
            </div>
            <div className="host-card-body">
              <div className="host-detail">
                <span className="detail-label">Platform</span>
                <span className="detail-value">{host.platform}/{host.arch}</span>
              </div>
              <div className="host-detail">
                <span className="detail-label">Features</span>
                <span className="detail-value">{host.features?.join(', ') || 'terminal'}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
