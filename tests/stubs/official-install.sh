#!/bin/sh
# Stub of https://pilotprotocol.network/install.sh for the tests: installs the
# stub binaries (version STUB_INSTALL_VERSION) into ~/.pilot/bin and records the
# environment it saw. Refuses root without PILOT_ALLOW_ROOT, like the real one.
set -e
if [ "$(id -u)" = 0 ] && [ -z "${PILOT_ALLOW_ROOT:-}" ]; then
  echo "Error: refusing to install as root." >&2
  exit 1
fi
mkdir -p "$HOME/.pilot/bin"
echo "ALLOW_ROOT=${PILOT_ALLOW_ROOT:-} TRANSPORT=${PILOT_TRANSPORT:-}" >> "$HOME/.pilot/stub-installer.log"
for b in pilot-daemon pilotctl; do
  sed "s/^STUB_VERSION=.*/STUB_VERSION=\"${STUB_INSTALL_VERSION:-v1.0.0}\"/" "$STUB_DIR/$b" > "$HOME/.pilot/bin/$b.new"
  chmod 755 "$HOME/.pilot/bin/$b.new"
  mv -f "$HOME/.pilot/bin/$b.new" "$HOME/.pilot/bin/$b"
done
echo "Pilot Protocol installed. Start the daemon: pilotctl daemon start"
