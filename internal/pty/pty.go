package pty

import (
	"io"
	"os"
	"os/exec"

	"github.com/creack/pty"
	"github.com/rs/zerolog/log"
)

// Session holds a PTY session.
type Session struct {
	PTY  *os.File
	cmd  *exec.Cmd
	done chan struct{}
}

// Manager creates and manages PTY sessions.
type Manager struct{}

// NewManager creates a new PTY manager.
func NewManager() *Manager {
	return &Manager{}
}

// Spawn starts a new shell session.
func (m *Manager) Spawn() *Session {
	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/bash"
	}

	cmd := exec.Command(shell)
	cmd.Env = os.Environ()

	f, err := pty.StartWithSize(cmd, &pty.Winsize{
		Rows: 24,
		Cols: 80,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to start PTY")
		return nil
	}

	s := &Session{
		PTY:  f,
		cmd:  cmd,
		done: make(chan struct{}),
	}

	go func() {
		cmd.Wait()
		close(s.done)
	}()

	return s
}

// Read reads from the PTY.
func (s *Session) Read(buf []byte) (int, error) {
	return s.PTY.Read(buf)
}

// Write writes to the PTY stdin.
func (s *Session) Write(data []byte) (int, error) {
	return s.PTY.Write(data)
}

// Resize changes the terminal window size.
func (s *Session) Resize(rows, cols uint16) error {
	return pty.Setsize(s.PTY, &pty.Winsize{
		Rows: rows,
		Cols: cols,
	})
}

// Close terminates the PTY session.
func (s *Session) Close() error {
	s.cmd.Process.Kill()
	return s.PTY.Close()
}

// Wait blocks until the session ends.
func (s *Session) Wait() <-chan struct{} {
	return s.done
}

// Ensure io.ReadWriter interface.
var _ io.ReadWriter = (*Session)(nil)
