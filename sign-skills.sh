#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Rebuilds skills/pilotctl/SKILL.md, then signs inject-manifest.json and
# every file it lists with the pilot-skills signing key, writing a .sig
# next to each (SIGNING.md). CI (build-pilotctl-skill.yml) does this on
# every push to main; this script is the same step by hand, for a branch
# or when CI cannot run.
#
# The private key stays in the macOS login keychain (generic password,
# service pilot-skills-signing); it is piped straight into sign-skills,
# which never prints it or writes it anywhere.
#
#   ./sign-skills.sh
#
# Environment:
#   PILOT_SKILLS_KEYCHAIN_SERVICE  keychain service (default pilot-skills-signing)
#   PILOT_SKILLS_KEYCHAIN_ACCOUNT  keychain account (default $USER)
#   SKILLINJECT_DIR                run sign-skills from this skillinject checkout
#   SIGN_SKILLS_VERSION            otherwise, the skillinject version to run (default latest)
set -euo pipefail
cd "$(dirname "$0")"
repo=$PWD

service=${PILOT_SKILLS_KEYCHAIN_SERVICE:-pilot-skills-signing}
account=${PILOT_SKILLS_KEYCHAIN_ACCOUNT:-$USER}

sign_skills() {
  if [ -n "${SKILLINJECT_DIR:-}" ]; then
    (cd "$SKILLINJECT_DIR" && GOWORK=off go run ./cmd/sign-skills "$@")
  else
    GOWORK=off go run "github.com/pilot-protocol/skillinject/cmd/sign-skills@${SIGN_SKILLS_VERSION:-latest}" "$@"
  fi
}

./build-pilotctl-skill.sh >/dev/null
security find-generic-password -s "$service" -a "$account" -w | sign_skills sign -repo "$repo"
sign_skills verify -repo "$repo" >/dev/null
echo
echo "Signed and verified. Commit the changes:"
git status --short
