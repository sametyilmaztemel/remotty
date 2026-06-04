package transfer

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"

	"github.com/sametyilmaztemel/remotyy/internal/protocol"
)

func TestNewManager(t *testing.T) {
	m := NewManager(t.TempDir())
	if m == nil {
		t.Fatal("NewManager returned nil")
	}
}

func TestInitiateSend(t *testing.T) {
	dir := t.TempDir()
	m := NewManager(dir)

	// Create a test file
	testFile := filepath.Join(dir, "test.txt")
	os.WriteFile(testFile, []byte("hello world"), 0644)

	tf, err := m.InitiateSend(testFile)
	if err != nil {
		t.Fatalf("InitiateSend: %v", err)
	}

	if tf.Name != "test.txt" {
		t.Errorf("Name = %q, want %q", tf.Name, "test.txt")
	}
	if tf.Size != 11 {
		t.Errorf("Size = %d, want 11", tf.Size)
	}
	if tf.Direction != "send" {
		t.Errorf("Direction = %q, want %q", tf.Direction, "send")
	}
	if tf.State != TransferPending {
		t.Errorf("State = %d, want TransferPending", tf.State)
	}
	if tf.ChunkSize != DefaultChunkSize {
		t.Errorf("ChunkSize = %d, want %d", tf.ChunkSize, DefaultChunkSize)
	}
	if tf.TotalChunks != 1 {
		t.Errorf("TotalChunks = %d, want 1", tf.TotalChunks)
	}
}

func TestInitiateSendNonExistent(t *testing.T) {
	m := NewManager(t.TempDir())
	_, err := m.InitiateSend("/nonexistent/file.txt")
	if err == nil {
		t.Error("InitiateSend with non-existent file should error")
	}
}

func TestInitiateReceive(t *testing.T) {
	dir := t.TempDir()
	m := NewManager(dir)

	req := protocol.FileRequestPayload{
		TransferID: "tf-123",
		Name:       "download.bin",
		Size:       1024 * 1024,
		MimeType:   "application/octet-stream",
		ChunkSize:  65536,
	}

	tf, err := m.InitiateReceive(req)
	if err != nil {
		t.Fatalf("InitiateReceive: %v", err)
	}

	if tf.ID != "tf-123" {
		t.Errorf("ID = %q, want %q", tf.ID, "tf-123")
	}
	if tf.Direction != "receive" {
		t.Errorf("Direction = %q, want receive", tf.Direction)
	}
	if tf.State != TransferActive {
		t.Errorf("State = %d, want TransferActive", tf.State)
	}
	if tf.TotalChunks != 16 { // 1MB / 64KB = 16
		t.Errorf("TotalChunks = %d, want 16", tf.TotalChunks)
	}

	// Verify downloads dir was created
	downloadDir := filepath.Join(dir, "downloads")
	if _, err := os.Stat(downloadDir); os.IsNotExist(err) {
		t.Error("downloads directory was not created")
	}
}

func TestTransferProgress(t *testing.T) {
	tf := &Transfer{
		TotalChunks:    10,
		ReceivedChunks: 5,
	}

	progress := tf.Progress()
	if progress != 0.5 {
		t.Errorf("Progress() = %f, want 0.5", progress)
	}
}

func TestTransferProgressZero(t *testing.T) {
	tf := &Transfer{TotalChunks: 0}
	if tf.Progress() != 0 {
		t.Error("Progress with zero chunks should be 0")
	}
}

func TestTransferComplete(t *testing.T) {
	tf := &Transfer{State: TransferActive}
	tf.Complete()
	if tf.State != TransferComplete {
		t.Errorf("State = %d, want TransferComplete", tf.State)
	}
	if tf.CompletedAt.IsZero() {
		t.Error("CompletedAt should be set")
	}
}

func TestTransferCancel(t *testing.T) {
	tf := &Transfer{State: TransferActive}
	tf.Cancel()
	if tf.State != TransferCancelled {
		t.Errorf("State = %d, want TransferCancelled", tf.State)
	}
}

func TestOnProgress(t *testing.T) {
	m := NewManager(t.TempDir())
	called := false
	m.OnProgress(func(_ *Transfer) {
		called = true
	})
	if m.onProgress == nil {
		t.Error("onProgress should be set")
	}
	m.onProgress(nil) // trigger
	if !called {
		t.Error("callback should have been called")
	}
}

func TestWriteChunkChecksum(t *testing.T) {
	dir := t.TempDir()
	testFile := filepath.Join(dir, "chunk.bin")
	os.WriteFile(testFile, []byte{}, 0644)

	tf := &Transfer{
		Path:       testFile,
		State:      TransferActive,
		ChunkSize:  1024,
	}

	data := []byte("test data")
	h := sha256.Sum256(data)
	checksum := hex.EncodeToString(h[:])

	err := tf.WriteChunk(0, data, checksum)
	if err != nil {
		t.Fatalf("WriteChunk: %v", err)
	}
	if tf.ReceivedChunks != 1 {
		t.Errorf("ReceivedChunks = %d, want 1", tf.ReceivedChunks)
	}
}

func TestWriteChunkBadChecksum(t *testing.T) {
	dir := t.TempDir()
	testFile := filepath.Join(dir, "bad.bin")
	os.WriteFile(testFile, []byte{}, 0644)

	tf := &Transfer{
		Path:      testFile,
		State:     TransferActive,
		ChunkSize: 1024,
	}

	err := tf.WriteChunk(0, []byte("data"), "bad-checksum")
	if err == nil {
		t.Error("WriteChunk with bad checksum should error")
	}
}

func TestWriteChunkNotActive(t *testing.T) {
	tf := &Transfer{State: TransferComplete}
	err := tf.WriteChunk(0, []byte("data"), "")
	if err == nil {
		t.Error("WriteChunk on non-active transfer should error")
	}
}
