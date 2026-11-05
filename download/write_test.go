package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteFileCreatesParentsAndWritesIndentedJSONWithNewline(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "records.json")
	if err := writeFile(path, []int{1, 2}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(data, []byte("[\n  1,\n  2\n]\n")) {
		t.Fatalf("file contents = %q", data)
	}
}

func TestWriteFileReplacesExistingLongerContents(t *testing.T) {
	path := filepath.Join(t.TempDir(), "records.json")
	if err := os.WriteFile(path, []byte(strings.Repeat("old", 100)), 0644); err != nil {
		t.Fatal(err)
	}
	if err := writeFile(path, []int{7}); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(data, []byte("[\n  7\n]\n")) {
		t.Fatalf("file contents include stale data: %q", data)
	}
}

func TestWriteFileEncodingFailureLeavesDestinationUnchanged(t *testing.T) {
	path := filepath.Join(t.TempDir(), "records.json")
	before := []byte("existing content")
	if err := os.WriteFile(path, before, 0644); err != nil {
		t.Fatal(err)
	}
	if err := writeFile(path, make(chan int)); err == nil {
		t.Fatal("expected encoding error")
	}
	after, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(after, before) {
		t.Fatalf("destination changed after encoding failure: %q", after)
	}
}

func TestWriteFileReportsDestinationWriteFailure(t *testing.T) {
	path := t.TempDir()
	err := writeFile(path, []int{1})
	if err == nil || !strings.Contains(err.Error(), "writing "+path) {
		t.Fatalf("write error = %v", err)
	}
}
