import { useState, useRef } from 'react';
import type { HostInfo } from '../lib/protocol';

interface Props {
  host: HostInfo;
  signalUrl: string;
}

interface Transfer {
  id: string;
  name: string;
  size: number;
  progress: number;
  status: 'pending' | 'active' | 'complete' | 'error';
  speed: string;
}

export default function FileTransfer({ host }: Props) {
  const [transfers, setTransfers] = useState<Transfer[]>([]);
  const [dragging, setDragging] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragging(false);
    const files = Array.from(e.dataTransfer.files);
    files.forEach(uploadFile);
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    files.forEach(uploadFile);
  };

  const uploadFile = (file: File) => {
    const transfer: Transfer = {
      id: `tf-${Date.now()}`,
      name: file.name,
      size: file.size,
      progress: 0,
      status: 'active',
      speed: '0 B/s',
    };
    setTransfers(prev => [...prev, transfer]);

    // TODO: Implement actual file transfer via WebRTC data channel
    // Simulate progress for now
    simulateProgress(transfer.id);
  };

  const simulateProgress = (id: string) => {
    let progress = 0;
    const interval = setInterval(() => {
      progress += Math.random() * 10;
      if (progress >= 100) {
        progress = 100;
        clearInterval(interval);
        setTransfers(prev => prev.map(t =>
          t.id === id ? { ...t, progress, status: 'complete' as const, speed: 'done' } : t
        ));
      } else {
        setTransfers(prev => prev.map(t =>
          t.id === id ? { ...t, progress, speed: `${Math.floor(Math.random() * 50 + 10)} MB/s` } : t
        ));
      }
    }, 500);
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  return (
    <div className="file-transfer">
      <div className="file-header">
        <h2>{host.name} — File Transfer</h2>
      </div>

      <div
        className={`drop-zone ${dragging ? 'dragging' : ''}`}
        onDragOver={e => { e.preventDefault(); setDragging(true); }}
        onDragLeave={() => setDragging(false)}
        onDrop={handleDrop}
        onClick={() => fileInput.current?.click()}
      >
        <input
          ref={fileInput}
          type="file"
          multiple
          onChange={handleFileSelect}
          style={{ display: 'none' }}
        />
        <span className="drop-icon">📁</span>
        <p>Drop files here or click to select</p>
      </div>

      {transfers.length > 0 && (
        <div className="transfer-list">
          <h3>Transfers</h3>
          {transfers.map(transfer => (
            <div key={transfer.id} className="transfer-item">
              <div className="transfer-info">
                <span className="transfer-name">{transfer.name}</span>
                <span className="transfer-size">{formatSize(transfer.size)}</span>
              </div>
              <div className="transfer-progress">
                <div
                  className={`progress-bar ${transfer.status}`}
                  style={{ width: `${transfer.progress}%` }}
                />
              </div>
              <div className="transfer-status">
                {transfer.status === 'active' && (
                  <span>{transfer.speed} — {transfer.progress.toFixed(0)}%</span>
                )}
                {transfer.status === 'complete' && <span>✅ Complete</span>}
                {transfer.status === 'error' && <span>❌ Error</span>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
