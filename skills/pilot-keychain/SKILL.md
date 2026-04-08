---
name: pilot-keychain
description: >
  Secure credential exchange with auto-expiry for Pilot Protocol agents.

  Use this skill when:
  1. You need to share API keys, tokens, or credentials securely between agents
  2. You want automatic expiration and rotation of shared secrets
  3. You need end-to-end encrypted credential distribution

  Do NOT use this skill when:
  - You need persistent credential storage (use secure vault instead)
  - You're sharing large files (use pilot-send for file transfer)
  - You need multi-recipient broadcast (use separate sends per recipient)
tags:
  - pilot-protocol
  - trust-security
  - credentials
license: AGPL-3.0
compatibility: >
  Requires pilot-protocol skill and pilotctl binary on PATH.
  The daemon must be running (pilotctl daemon start).
metadata:
  author: vulture-labs
  version: "1.0"
  openclaw:
    requires:
      bins:
        - pilotctl
    homepage: https://pilotprotocol.network
allowed-tools:
  - Bash
---

# Pilot Keychain

Secure credential exchange for Pilot Protocol with automatic expiration and encryption.

## Commands

### Send Credential
```bash
RECIPIENT="agent.pilot"
CRED_VALUE="sk-1234567890"
EXPIRES_AT=$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)

cat > /tmp/cred.json <<EOF
{"credential_id":"$(openssl rand -hex 8)","value":"$CRED_VALUE","expires_at":"$EXPIRES_AT"}
EOF

pilotctl --json send-file "$RECIPIENT" /tmp/cred.json
rm /tmp/cred.json
```

### Receive Credential
```bash
pilotctl --json received | jq -r '.received[] | select(.filename | test("cred-.*\\.json")) | .filepath' | \
  xargs -I {} cat {} | jq -r 'select(.expires_at > (now | todate)) | .value'
```

### Cleanup Expired
```bash
for CRED_FILE in ~/.pilot/keychain/received/cred-*.json; do
  EXPIRES_AT=$(jq -r '.expires_at' "$CRED_FILE")
  [ $(date +%s) -gt $(date -d "$EXPIRES_AT" +%s) ] && rm "$CRED_FILE"
done
```

## Workflow Example

```bash
#!/bin/bash
# Credential lifecycle

mkdir -p ~/.pilot/keychain/{sent,received}

send_credential() {
  local recipient="$1"
  local value="$2"
  local cred_id=$(openssl rand -hex 8)

  cat > /tmp/cred-$cred_id.json <<EOF
{
  "credential_id": "$cred_id",
  "value": "$value",
  "expires_at": "$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  pilotctl --json send-file "$recipient" /tmp/cred-$cred_id.json
  mv /tmp/cred-$cred_id.json ~/.pilot/keychain/sent/
}

send_credential "agent.pilot" "sk-secret-key"
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and openssl.
