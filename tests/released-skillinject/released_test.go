// SPDX-License-Identifier: AGPL-3.0-or-later

// Package releasedskillinject runs a RELEASED pilot-daemon skill injector
// (github.com/pilot-protocol/skillinject, the version go.mod pins; CI also
// runs it against the versions shipped in released daemons) against this
// checkout's inject-manifest.json, served over HTTP the way the daemon
// fetches it from raw.githubusercontent.com.
//
// The manifest's "gatedTools" key (Meta Muse) is read only by skillinject
// builds that know it. Released builds decode the manifest with plain
// json.Unmarshal into a struct without the key, so they must accept the
// manifest, keep injecting the regular tools, and never touch
// ~/workspace/skills, even on a host that is marked as a Muse target.
//
// The marker is the one the Muse installer leaves after installing the
// Muse-format skills into ~/workspace/skills. Builds that read gatedTools
// act on the muse row only when the marker names that directory and
// format, one key=value per line (pilot-protocol/skillinject gated.go):
//
//	skills_dir=/root/workspace/skills
//	skill_format=muse
//
// An empty marker, or one for another folder or for skill_format=canonical
// (PILOT_MUSE_FRONTMATTER=0), turns the row off.
package releasedskillinject

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/pilot-protocol/skillinject"
)

// repoRoot is the pilot-skills checkout this test lives in.
const repoRoot = "../.."

func serveRepo(t *testing.T) skillinject.Config {
	t.Helper()
	srv := httptest.NewServer(http.FileServer(http.Dir(repoRoot)))
	t.Cleanup(srv.Close)
	return skillinject.Config{
		ManifestURL: srv.URL + "/inject-manifest.json",
		RepoBaseURL: srv.URL + "/",
	}
}

// museHome is a home directory that looks like a Meta Muse VM after the
// Muse installer ran: ~/workspace/skills exists and ~/.pilot/targets/muse
// marks it as holding the Muse-format skills. ~/.claude is there too, to
// show the regular tools are still injected.
func museHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	for _, d := range []string{"workspace/skills", ".pilot/targets", ".claude"} {
		if err := os.MkdirAll(filepath.Join(home, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	marker := "# written by pilot-skills muse/install.sh\n" +
		"skills_dir=" + filepath.Join(home, "workspace", "skills") + "\n" +
		"skill_format=muse\n"
	if err := os.WriteFile(filepath.Join(home, ".pilot", "targets", "muse"), []byte(marker), 0o644); err != nil {
		t.Fatal(err)
	}
	return home
}

// listTree returns every path under dir, relative to it.
func listTree(t *testing.T, dir string) []string {
	t.Helper()
	var out []string
	err := filepath.WalkDir(dir, func(p string, _ os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if rel, _ := filepath.Rel(dir, p); rel != "." {
			out = append(out, rel)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

// The manifest this test serves really carries the gated Muse row, and
// the row has the shape new skillinject builds accept.
func TestManifestHasGatedMuseRow(t *testing.T) {
	body, err := os.ReadFile(filepath.Join(repoRoot, "inject-manifest.json"))
	if err != nil {
		t.Fatal(err)
	}
	var m struct {
		Tools      []map[string]any `json:"tools"`
		GatedTools []struct {
			Name          string `json:"name"`
			RootDir       string `json:"rootDir"`
			SkillsDir     string `json:"skillsDir"`
			RequireMarker string `json:"requireMarker"`
			SkillFormat   string `json:"skillFormat"`
		} `json:"gatedTools"`
	}
	if err := json.Unmarshal(body, &m); err != nil {
		t.Fatal(err)
	}
	for _, tool := range m.Tools {
		if tool["name"] == "muse" {
			t.Error(`muse must not be a "tools" row: released daemons would write ~/workspace/skills on every host that has it`)
		}
	}
	found := false
	for _, g := range m.GatedTools {
		if !strings.HasPrefix(g.RequireMarker, "~/.pilot/") || strings.Contains(g.RequireMarker, "..") {
			t.Errorf("gated %s: requireMarker %q must be inside ~/.pilot", g.Name, g.RequireMarker)
		}
		if !strings.HasPrefix(g.RootDir, "~/") || strings.Contains(g.RootDir, "..") {
			t.Errorf("gated %s: rootDir %q must be inside the home directory", g.Name, g.RootDir)
		}
		if g.SkillsDir != g.RootDir && !strings.HasPrefix(g.SkillsDir, g.RootDir+"/") {
			t.Errorf("gated %s: skillsDir %q must be inside rootDir %q", g.Name, g.SkillsDir, g.RootDir)
		}
		if g.SkillFormat != "" && g.SkillFormat != "muse" {
			t.Errorf("gated %s: unknown skillFormat %q", g.Name, g.SkillFormat)
		}
		if g.Name == "muse" {
			found = true
			if g.RootDir != "~/workspace/skills" || g.SkillsDir != "~/workspace/skills" ||
				g.RequireMarker != "~/.pilot/targets/muse" || g.SkillFormat != "muse" {
				t.Errorf("muse row = %+v", g)
			}
		}
	}
	if !found {
		t.Fatal(`inject-manifest.json has no "gatedTools" muse row; this test would prove nothing`)
	}
}

func TestReleasedTickIgnoresGatedTools(t *testing.T) {
	home := museHome(t)
	cfg := serveRepo(t)
	cfg.Home = home

	for i := 0; i < 2; i++ {
		rep, err := skillinject.Tick(context.Background(), cfg)
		if err != nil {
			t.Fatalf("released Tick %d rejected the manifest: %v", i, err)
		}
		for _, o := range rep.Outcomes {
			if o.Tool == "muse" || strings.HasPrefix(o.Path, filepath.Join(home, "workspace")) {
				t.Errorf("released Tick acted on the Muse target: %+v", o)
			}
			if o.Action == skillinject.ActionError {
				t.Errorf("released Tick error row: %+v", o)
			}
		}
		for _, s := range rep.Skipped {
			if s == "muse" {
				t.Errorf("released Tick knows about muse: Skipped=%v", rep.Skipped)
			}
		}
	}
	if got := listTree(t, filepath.Join(home, "workspace")); len(got) != 1 || got[0] != "skills" {
		t.Errorf("~/workspace changed under a released Tick: %v", got)
	}
	// The manifest was not rejected: the regular tools were injected.
	for _, p := range []string{".claude/skills/pilotctl/SKILL.md", ".claude/CLAUDE.md"} {
		if _, err := os.Stat(filepath.Join(home, p)); err != nil {
			t.Errorf("claude-code was not injected (%s): %v", p, err)
		}
	}
}

// A released `pilotctl skills disable all` (Uninstall) does not remove a
// Muse skill it never wrote.
func TestReleasedUninstallLeavesMuseTargetAlone(t *testing.T) {
	home := museHome(t)
	cfg := serveRepo(t)
	cfg.Home = home
	muse := filepath.Join(home, "workspace", "skills", "pilotctl", "SKILL.md")
	if err := os.MkdirAll(filepath.Dir(muse), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(muse, []byte("installed by muse/install.sh\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := skillinject.Tick(context.Background(), cfg); err != nil {
		t.Fatalf("released Tick: %v", err)
	}
	rep, err := skillinject.Uninstall(context.Background(), cfg)
	if err != nil {
		t.Fatalf("released Uninstall: %v", err)
	}
	for _, r := range rep.Removals {
		if r.Tool == "muse" || strings.HasPrefix(r.Path, filepath.Join(home, "workspace")) {
			t.Errorf("released Uninstall acted on the Muse target: %+v", r)
		}
	}
	if b, err := os.ReadFile(muse); err != nil || string(b) != "installed by muse/install.sh\n" {
		t.Errorf("Muse skill changed: %q, %v", b, err)
	}
}
