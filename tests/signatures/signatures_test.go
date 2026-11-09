// SPDX-License-Identifier: AGPL-3.0-or-later

// Package signatures checks that inject-manifest.json and every file it
// makes pilot-daemon fetch carry a valid signature by the key the daemon
// has built in. A daemon that meets one bad or missing signature refuses
// the whole update and keeps the content it already has, so this test
// fails the build before that can reach a host.
//
// The format is pilot-protocol/skillinject's (signature.go there): a .sig
// next to each file holds the base64 Ed25519 signature over
//
//	"pilot-skills-sig-v1" 0x00 <repo path> 0x00 <file bytes>
//
// The files are the manifest, skills/<entrypoint>/SKILL.md, and every
// "src" and "heartbeatTemplate" value at any depth outside "retired"
// (skillinject.SignedFiles). This copy uses only the standard library so
// it does not depend on a skillinject release.
//
// CI signs main (build-pilotctl-skill.yml). A file that the push or pull
// request under test changed may not be signed yet: CHANGED_FILES (one
// repo path per line, set by test.yml) lists those, and for them a
// missing or stale signature is reported, not failed. Everything else is
// still checked: that each listed file exists, is a regular file within
// the fetch cap, and that every file the change did not touch matches
// its signature.
package signatures

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// publicKeyHex is skillinject.DefaultManifestPublicKeyHex.
const publicKeyHex = "95effdc0863c8e37d65abb292f338856ac703705041a23246c8e468d7426fb31"

const (
	manifestName = "inject-manifest.json"
	domain       = "pilot-skills-sig-v1"
	maxFile      = 1 << 20 // the daemon's fetch cap
)

var repoRoot = filepath.Join("..", "..")

func TestEveryInjectedFileIsSigned(t *testing.T) {
	pub, err := hex.DecodeString(publicKeyHex)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		t.Fatalf("bad pinned key: %v", err)
	}
	raw, err := os.ReadFile(filepath.Join(repoRoot, manifestName))
	if err != nil {
		t.Fatal(err)
	}
	names, err := signedFiles(raw)
	if err != nil {
		t.Fatal(err)
	}
	changed := changedFiles()
	for _, name := range append([]string{manifestName}, names...) {
		t.Run(name, func(t *testing.T) {
			// For a file this change touched, CI signs it on main.
			unsigned := func(format string, args ...any) {
				t.Helper()
				if changed[name] {
					t.Logf("not signed yet, changed here; build-pilotctl-skill signs it on main: "+format, args...)
					return
				}
				t.Fatalf(format, args...)
			}
			p := filepath.Join(repoRoot, filepath.FromSlash(name))
			st, err := os.Lstat(p)
			if err != nil {
				t.Fatalf("listed in %s but %v", manifestName, err)
			}
			if !st.Mode().IsRegular() {
				t.Fatalf("not a regular file")
			}
			if st.Size() > maxFile {
				t.Fatalf("%d bytes; the daemon fetches at most %d", st.Size(), maxFile)
			}
			body, err := os.ReadFile(p)
			if err != nil {
				t.Fatal(err)
			}
			sigFile, err := os.ReadFile(p + ".sig")
			if err != nil {
				unsigned("no signature: %v", err)
				return
			}
			sig, err := base64.StdEncoding.DecodeString(string(bytes.TrimSpace(sigFile)))
			if err != nil || len(sig) != ed25519.SignatureSize {
				unsigned("%s.sig is not a base64 Ed25519 signature", name)
				return
			}
			msg := append(append(append(append([]byte(domain), 0), name...), 0), body...)
			if !ed25519.Verify(ed25519.PublicKey(pub), msg, sig) {
				unsigned("does not match %s.sig: changed after signing, or signed with another key", name)
			}
		})
	}
}

// changedFiles reads CHANGED_FILES: the repo paths the push or pull
// request under test changed, one per line.
func changedFiles() map[string]bool {
	out := map[string]bool{}
	for _, line := range strings.Split(os.Getenv("CHANGED_FILES"), "\n") {
		if line = strings.TrimSpace(line); line != "" {
			out[line] = true
		}
	}
	return out
}

// signedFiles mirrors skillinject.SignedFiles.
func signedFiles(raw []byte) ([]string, error) {
	var top map[string]any
	if err := json.Unmarshal(raw, &top); err != nil {
		return nil, err
	}
	entry, _ := top["entrypoint"].(string)
	seen := map[string]bool{}
	var bad []string
	add := func(p string) {
		name := strings.TrimPrefix(p, "/")
		if c := path.Clean(name); name == "" || c == "." || c == ".." || strings.HasPrefix(c, "../") || strings.ContainsAny(name, "\\\x00") {
			bad = append(bad, p)
			return
		}
		seen[name] = true
	}
	if entry != "" {
		add("skills/" + entry + "/SKILL.md")
	}
	var walk func(any)
	walk = func(v any) {
		switch t := v.(type) {
		case map[string]any:
			for k, child := range t {
				if s, ok := child.(string); ok && (k == "src" || k == "heartbeatTemplate") {
					if s != "" {
						add(s)
					}
					continue
				}
				walk(child)
			}
		case []any:
			for _, child := range t {
				walk(child)
			}
		}
	}
	for k, v := range top {
		if k != "retired" {
			walk(v)
		}
	}
	if len(bad) > 0 {
		return nil, fmt.Errorf("%s names paths outside the repo: %s", manifestName, strings.Join(bad, ", "))
	}
	if entry == "" {
		return nil, fmt.Errorf("%s has no entrypoint", manifestName)
	}
	out := make([]string, 0, len(seen))
	for p := range seen {
		out = append(out, p)
	}
	sort.Strings(out)
	return out, nil
}
