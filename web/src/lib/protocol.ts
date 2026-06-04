// Protocol types matching the Go backend

export type MessageType =
  | 'register' | 'heartbeat' | 'update'
  | 'list_hosts' | 'connect'
  | 'host_list' | 'room_ready' | 'peer_left'
  | 'offer' | 'answer' | 'ice_candidate'
  | 'auth' | 'auth_ok' | 'auth_fail'
  | 'input' | 'output' | 'resize'
  | 'screen_start' | 'screen_stop'
  | 'file_request' | 'file_accept' | 'file_reject'
  | 'file_chunk' | 'file_complete' | 'file_progress'
  | 'clipboard'
  | 'ping' | 'pong'
  | 'error';

export interface Message<T = unknown> {
  type: MessageType;
  payload?: T;
  from?: string;
  to?: string;
  room?: string;
  id?: string;
}

export interface HostInfo {
  id: string;
  name: string;
  platform: string;
  arch: string;
  version?: string;
  online: boolean;
  features: string[];
}

export interface ResizePayload {
  rows: number;
  cols: number;
}

export interface AuthPayload {
  password: string;
}

export interface FileRequestPayload {
  transfer_id: string;
  name: string;
  size: number;
  mime_type: string;
  chunk_size: number;
}

export interface FileChunkPayload {
  transfer_id: string;
  index: number;
  data: number[];
  checksum?: string;
}

export interface FileProgressPayload {
  transfer_id: string;
  bytes_sent: number;
  total_bytes: number;
  speed: number;
}
