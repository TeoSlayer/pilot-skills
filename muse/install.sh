#!/usr/bin/env bash
# install.sh — one-shot "Pilot in Meta Muse" installer. In one run it:
#   1. installs the Pilot Protocol skills into the agent's workspace, with the
#      SKILL.md frontmatter Muse is known to load, and marks this host as a
#      Muse target (~/.pilot/targets/muse),
#   2. installs pilotctl + pilot-daemon into ~/.pilot/bin if they are missing
#      (the official installer; works as root, no systemd or launchd needed),
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
#   MUSE_SKILLS_DIR         destination folder (default ~/workspace/skills)
#   PILOT_SKILLS_REF        branch, tag or commit of TeoSlayer/pilot-skills (default main)
#   PILOT_SKILLS            space-separated skill list (default: pilotctl pilot-protocol pilot-sandbox)
#   PILOT_SKILLS_ONLY       1 = install the skills and stop
#   PILOT_NO_START          1 = install skills and binaries, but do not start the node
#   PILOT_UPGRADE           1 = rerun the official Pilot installer even if the binaries
#                           exist, and restart the node when they changed
#   PILOT_MUSE_FRONTMATTER  0 = keep the canonical SKILL.md frontmatter (for agents
#                           that need name to equal the folder name)
#   PILOT_INSTALL_URL       official installer (default https://pilotprotocol.network/install.sh)
#   pilot-up.sh also reads PILOT_HOSTNAME, PILOT_PROXY, PILOT_UP_WAIT, PILOT_UP_MODE,
#   PILOT_REGISTRY_TRUST and PILOT_REGISTRY_FINGERPRINT.
#
# curl honours HTTPS_PROXY, so every download works from proxy-only sandboxes.
# Proxy credentials are never printed. Exit status: 0 when everything asked
# for is done (the node is online unless PILOT_SKILLS_ONLY/PILOT_NO_START),
# otherwise pilot-up.sh's code (1 not registered, 3 needs root or a newer daemon).
set -euo pipefail

# muse_frontmatter FILE [NAME] — rewrite the YAML frontmatter of an installed
# SKILL.md into the shape Muse is proven to load:
#   name: "<NAME>"            (default: the folder name with - replaced by _)
#   description: "<one line>" (folded/multi-line values joined, quotes and
#                              backslashes escaped, capped at 1024 bytes)
# Every other frontmatter key is dropped; the body is kept byte for byte. A file
# without a closed frontmatter block is left alone. Only ever run it on the
# installed copy: the repo's canonical files keep their full frontmatter.
muse_frontmatter() {
  local file="$1" name="${2:-}" end desc
  if [ -z "$name" ]; then
    name="$(basename "$(dirname "$file")")"
    name="${name//-/_}"
  fi
  end="$(awk 'NR == 1 { if ($0 !~ /^---\r?$/) exit; next } /^---\r?$/ { print NR; exit }' "$file")" || return 1
  [ -n "$end" ] || return 0
  desc="$(awk -v end="$end" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    NR == 1 { next }
    NR >= end { exit }
    {
      sub(/\r$/, "")
      if (state == 1) {
        if ($0 ~ /^[ \t]/ || $0 == "") {
          line = trim($0)
          if (!block && !quoted) sub(/[ \t]#.*$/, "", line)
          if (line != "") value = value " " line
          next
        }
        state = 2
      }
      if (state == 0 && $0 ~ /^description:/) {
        v = $0
        sub(/^description:/, "", v)
        v = trim(v)
        if (v ~ /^[|>][-+0-9]*([ \t]+#.*)?$/) { block = 1; v = "" }
        else if (v ~ /^["\047]/) quoted = 1
        else sub(/[ \t]#.*$/, "", v)
        value = v
        state = 1
      }
    }
    END { printf "%s", value }
  ' "$file")" || return 1
  desc="$(printf '%s' "$desc" | tr -d '\000-\010\013-\037' | tr '\t\n' '  ' | tr -s ' ')"
  desc="${desc# }"
  desc="${desc% }"
  case "$desc" in
    \"*\")
      desc="${desc#\"}"
      desc="${desc%\"}"
      desc="${desc//\\\\/$'\001'}" # protect escaped backslashes
      desc="${desc//\\\"/\"}"
      desc="${desc//\\n/ }"
      desc="${desc//\\t/ }"
      desc="${desc//$'\001'/\\}"
      ;;
    \'*\')
      local q="'"
      desc="${desc#"$q"}"
      desc="${desc%"$q"}"
      desc="${desc//"$q$q"/$q}"
      ;;
  esac
  if [ -z "$desc" ]; then desc="Pilot Protocol skill ${name}"; fi
  if [ "$(printf '%s' "$desc" | LC_ALL=C wc -c | tr -d ' ')" -gt 1024 ]; then
    desc="$(printf '%s' "$desc" | LC_ALL=C cut -c1-1020)"
    desc="${desc% *}..."
  fi
  desc="${desc//\\/\\\\}"
  desc="${desc//\"/\\\"}"
  {
    printf -- '---\nname: "%s"\ndescription: "%s"\n---\n' "$name" "$desc"
    tail -n "+$((end + 1))" "$file"
  } > "$file.muse-tmp" && mv -f "$file.muse-tmp" "$file"
}

# bins_checksum DIR — one line identifying the pilotctl + pilot-daemon builds.
bins_checksum() {
  cat "$1/pilot-daemon" "$1/pilotctl" 2> /dev/null | cksum || true
}

# Everything runs inside main so that `curl | bash` parses the whole script
# before executing any of it.
main() {
  local dest ref tarball tmp src skill up rc=0 skills_only no_start pilot_dir bin_dir
  local frontmatter had_bins=0 before="" upgraded=0 proxy stop_out stop_failed=0
  dest="${MUSE_SKILLS_DIR:-$HOME/workspace/skills}"
  ref="${PILOT_SKILLS_REF:-main}"
  skills_only="${PILOT_SKILLS_ONLY:-0}"
  no_start="${PILOT_NO_START:-0}"
  frontmatter="${PILOT_MUSE_FRONTMATTER:-1}"
  pilot_dir="$HOME/.pilot"
  bin_dir="$pilot_dir/bin"
  proxy="${HTTPS_PROXY:-${https_proxy:-${ALL_PROXY:-${all_proxy:-}}}}"
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
    if [ "$frontmatter" = "0" ]; then
      echo "installed $skill -> $dest/$skill"
    elif muse_frontmatter "$dest/$skill/SKILL.md" "${skill//-/_}"; then
      echo "installed $skill -> $dest/$skill (Muse frontmatter: name \"${skill//-/_}\")"
    else
      rm -f "$dest/$skill/SKILL.md.muse-tmp"
      echo "installed $skill -> $dest/$skill (warning: could not rewrite its frontmatter for Muse; kept the original)" >&2
    fi
  done

  # Pilot's skill injection keys off this marker to keep ~/workspace/skills
  # up to date on Muse hosts.
  mkdir -p "$pilot_dir/targets"
  touch "$pilot_dir/targets/muse"
  echo "marked this host as a Muse target ($pilot_dir/targets/muse)"

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
  if [ -x "$bin_dir/pilotctl" ] && [ -x "$bin_dir/pilot-daemon" ]; then
    had_bins=1
    before="$(bins_checksum "$bin_dir")"
  fi
  if [ "$had_bins" = 1 ] && [ "${PILOT_UPGRADE:-0}" != "1" ]; then
    echo "Pilot already installed in $bin_dir ($("$bin_dir/pilot-daemon" -version 2> /dev/null || echo "unknown version")); PILOT_UPGRADE=1 reinstalls"
  else
    echo "Installing pilotctl + pilot-daemon into $bin_dir (official installer) ..."
    curl -fsSL "${PILOT_INSTALL_URL:-https://pilotprotocol.network/install.sh}" -o "$tmp/pilot-install.sh"
    local env_args=()
    if [ "$(id -u)" = "0" ]; then
      # Muse runs the agent as root; the official installer refuses root
      # unless told otherwise. The node's state still lands in $HOME/.pilot.
      echo "Running as root: passing PILOT_ALLOW_ROOT=1 to the official installer"
      env_args+=(PILOT_ALLOW_ROOT=1)
    fi
    if [ -n "$proxy" ]; then
      # Installers that know --transport then write transport=compat and
      # proxy=auto to config.json, so a later `pilotctl daemon start` also
      # goes through the proxy. Older installers ignore it.
      env_args+=(PILOT_TRANSPORT=compat)
    fi
    env ${env_args[@]+"${env_args[@]}"} sh "$tmp/pilot-install.sh" < /dev/null
    if [ ! -x "$bin_dir/pilotctl" ] || [ ! -x "$bin_dir/pilot-daemon" ]; then
      echo "install: the official installer finished but $bin_dir has no pilotctl/pilot-daemon" >&2
      exit 1
    fi
    echo
    echo "Pilot installed ($("$bin_dir/pilot-daemon" -version 2> /dev/null || echo "unknown version"))."
    echo "Ignore its 'pilotctl daemon start' hint: in this sandbox pilot-up.sh starts the node."
    if [ "$had_bins" = 1 ]; then
      if [ "$(bins_checksum "$bin_dir")" != "$before" ]; then
        upgraded=1
      else
        echo "The binaries did not change (already the latest release)."
      fi
    fi
  fi

  # --- 3. bring the node up ---
  up="$dest/pilot-sandbox/scripts/pilot-up.sh"
  if [ "$no_start" = "1" ]; then
    cat << MSG

Done. Skills in $dest, Pilot in $bin_dir. Node not started (PILOT_NO_START=1).
Start it with: bash $up
MSG
    if [ "$upgraded" = 1 ]; then
      echo "The binaries changed: if a node is running, restart it with: bash $up --stop && bash $up"
    fi
    exit 0
  fi
  if [ "$upgraded" = 1 ]; then
    # The installer swaps the files but not a running daemon (pilot-up's, or
    # one started by hand): stop it so the new binary is the one that comes up.
    # --stop exits 1 when a daemon still answers afterwards.
    echo
    echo "The binaries changed: stopping the running node so the new pilot-daemon comes up"
    stop_out="$(bash "$up" --stop < /dev/null 2>&1)" || stop_failed=1
    if [ -n "$stop_out" ]; then printf '%s\n' "$stop_out"; fi
    if [ "$stop_failed" = 1 ]; then
      echo "warning: the running node could not be stopped, so it stays on the old pilot-daemon until it is (see above)" >&2
    elif [[ $stop_out == *"pilot-up: stopped "* ]]; then
      echo "Restarting the node on the new pilot-daemon"
    else
      echo "No node was running; starting it on the new pilot-daemon"
    fi
  fi
  echo
  echo "Bringing the node online: bash $up"
  bash "$up" < /dev/null || rc=$?

  echo
  case "$rc" in
    0)
      if [ "$stop_failed" = 1 ]; then
        cat << MSG
Done. Skills in $dest, Pilot upgraded in $bin_dir. The node is online but still
runs the old pilot-daemon, which could not be stopped (see above). Stop it,
then run: bash $up
MSG
      else
        cat << MSG
Done. Skills in $dest, Pilot in $bin_dir, node online.
After a VM restart run: bash $up
Try it: $bin_dir/pilotctl --json send-message pilot-mom --data 'current BTC price in USD' --wait
MSG
      fi
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

# Run main unless this file is being sourced (tests source it for
# muse_frontmatter). Under `curl | bash`, BASH_SOURCE is empty and $0 is bash.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
