#!/usr/bin/env bash
# install.sh — one-shot "Pilot in Meta Muse" installer. In one run it:
#   1. installs the Pilot Protocol skills into the agent's workspace,
#   2. installs pilotctl + pilot-daemon into ~/.pilot/bin if they are missing
#      (the official installer; no root, no systemd or launchd needed),
#   3. brings the node online through the sandbox's HTTPS proxy with
#      pilot-sandbox/scripts/pilot-up.sh (rerun that script after a VM restart).
# Works in any agent that loads SKILL.md folders from a directory.
#
#   curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | bash
#
# Skills only (step 1, the installer's original behaviour):
#
#   curl -fsSL https://raw.githubusercontent.com/TeoSlayer/pilot-skills/main/muse/install.sh | PILOT_SKILLS_ONLY=1 bash
#
# Environment (optional):
#   MUSE_SKILLS_DIR    destination folder (default ~/workspace/skills)
#   PILOT_SKILLS_REF   branch, tag or commit of TeoSlayer/pilot-skills (default main)
#   PILOT_SKILLS       space-separated skill list (default: pilotctl pilot-protocol pilot-sandbox)
#   PILOT_SKILLS_ONLY  1 = install the skills and stop
#   PILOT_NO_START     1 = install skills and binaries, but do not start the node
#   PILOT_UPGRADE      1 = rerun the official Pilot installer even if the binaries exist
#   PILOT_INSTALL_URL  official installer (default https://pilotprotocol.network/install.sh)
#   pilot-up.sh also reads PILOT_HOSTNAME, PILOT_PROXY, PILOT_UP_WAIT, PILOT_UP_MODE.
#
# curl honours HTTPS_PROXY, so every download works from proxy-only sandboxes.
# Proxy credentials are never printed. Exit status: 0 when everything asked
# for is done (the node is online unless PILOT_SKILLS_ONLY/PILOT_NO_START),
# otherwise pilot-up.sh's code (1 not registered, 3 needs root or a newer daemon).
set -euo pipefail

# Everything runs inside main so that `curl | bash` parses the whole script
# before executing any of it.
main() {
  local dest ref tarball tmp src skill up rc=0 skills_only no_start pilot_dir bin_dir
  dest="${MUSE_SKILLS_DIR:-$HOME/workspace/skills}"
  ref="${PILOT_SKILLS_REF:-main}"
  skills_only="${PILOT_SKILLS_ONLY:-0}"
  no_start="${PILOT_NO_START:-0}"
  pilot_dir="${PILOT_HOME:-$HOME}/.pilot"
  bin_dir="$pilot_dir/bin"
  read -r -a SKILLS <<< "${PILOT_SKILLS:-pilotctl pilot-protocol pilot-sandbox}"
  # pilot-up.sh ships in pilot-sandbox, so the full install always includes it.
  if [ "$skills_only" != "1" ] && [[ " ${SKILLS[*]} " != *" pilot-sandbox "* ]]; then
    SKILLS+=(pilot-sandbox)
  fi
  tarball="https://codeload.github.com/TeoSlayer/pilot-skills/tar.gz/$ref"

  command -v curl > /dev/null || { echo "install: curl is required" >&2; exit 1; }
  command -v tar > /dev/null || { echo "install: tar is required" >&2; exit 1; }

  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064 # expand $tmp now; it is local to main
  trap "rm -rf '$tmp'" EXIT

  # --- 1. skills ---
  echo "Fetching TeoSlayer/pilot-skills@$ref ..."
  curl -fsSL "$tarball" | tar -xz -C "$tmp"
  src="$(find "$tmp" -maxdepth 2 -type d -name skills | head -n 1)"
  [ -d "$src" ] || { echo "install: archive did not contain a skills/ directory" >&2; exit 1; }

  mkdir -p "$dest"
  for skill in "${SKILLS[@]}"; do
    if [ ! -f "$src/$skill/SKILL.md" ]; then
      echo "install: skill '$skill' not found in $ref" >&2
      exit 1
    fi
    # Keep a hosts file the operator extended for run-daemon.sh.
    if [ -f "$dest/$skill/scripts/hosts" ]; then
      cp "$dest/$skill/scripts/hosts" "$tmp/hosts.keep"
    fi
    rm -rf "${dest:?}/$skill"
    cp -R "$src/$skill" "$dest/$skill"
    if [ -f "$tmp/hosts.keep" ]; then
      mv "$tmp/hosts.keep" "$dest/$skill/scripts/hosts"
    fi
    echo "installed $skill -> $dest/$skill"
  done

  if [ "$skills_only" = "1" ]; then
    cat << MSG

Done. ${#SKILLS[@]} skills in $dest.
Next: install Pilot itself (pilotctl + pilot-daemon), then ask your agent about
Pilot Protocol. Rerun without PILOT_SKILLS_ONLY=1 to do both in one go; from a
proxy-only sandbox the pilot-sandbox skill has the recipe.
MSG
    exit 0
  fi

  # --- 2. pilotctl + pilot-daemon ---
  if [ -x "$bin_dir/pilotctl" ] && [ -x "$bin_dir/pilot-daemon" ] && [ "${PILOT_UPGRADE:-0}" != "1" ]; then
    echo "Pilot already installed in $bin_dir ($("$bin_dir/pilot-daemon" -version 2> /dev/null || echo "unknown version")); PILOT_UPGRADE=1 reinstalls"
  else
    echo "Installing pilotctl + pilot-daemon into $bin_dir (official installer) ..."
    curl -fsSL "${PILOT_INSTALL_URL:-https://pilotprotocol.network/install.sh}" -o "$tmp/pilot-install.sh"
    if [ "$(id -u)" = "0" ]; then
      # Muse agents usually run as root; the official installer refuses root
      # unless told otherwise. The node's state still lands in $HOME/.pilot.
      echo "Running as root: passing PILOT_ALLOW_ROOT=1 to the official installer"
      PILOT_ALLOW_ROOT=1 sh "$tmp/pilot-install.sh" < /dev/null
    else
      sh "$tmp/pilot-install.sh" < /dev/null
    fi
    if [ ! -x "$bin_dir/pilotctl" ] || [ ! -x "$bin_dir/pilot-daemon" ]; then
      echo "install: the official installer finished but $bin_dir has no pilotctl/pilot-daemon" >&2
      exit 1
    fi
    echo
    echo "Pilot installed ($("$bin_dir/pilot-daemon" -version 2> /dev/null || echo "unknown version"))."
    echo "Ignore its 'pilotctl daemon start' hint: in this sandbox pilot-up.sh starts the node."
  fi

  # --- 3. bring the node up ---
  up="$dest/pilot-sandbox/scripts/pilot-up.sh"
  if [ "$no_start" = "1" ]; then
    cat << MSG

Done. Skills in $dest, Pilot in $bin_dir. Node not started (PILOT_NO_START=1).
Start it with: bash $up
MSG
    exit 0
  fi
  echo
  echo "Bringing the node online: bash $up"
  bash "$up" < /dev/null || rc=$?

  echo
  case "$rc" in
    0)
      cat << MSG
Done. Skills in $dest, Pilot in $bin_dir, node online.
After a VM restart run: bash $up
Try it: $bin_dir/pilotctl --json send-message pilot-mom --data 'current BTC price in USD' --wait
MSG
      ;;
    3)
      echo "Skills and Pilot are installed, but the node cannot start from this shell yet: see the steps above." >&2
      ;;
    *)
      echo "Skills and Pilot are installed, but the node is not online yet: see the log tail and next step above." >&2
      ;;
  esac
  exit "$rc"
}

main "$@"
