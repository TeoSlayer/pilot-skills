---
name: pilot-certificate
description: >
  Issue and verify Ed25519-signed capability certificates for Pilot Protocol agents.

  Use this skill when:
  1. You need to issue capability proofs or authorization certificates
  2. You want to verify agent capabilities using cryptographic signatures
  3. You need delegated authorization with time-limited certificates

  Do NOT use this skill when:
  - You only need basic trust establishment (use pilotctl trust)
  - You need long-term credentials (use pilot-keychain)
  - You're implementing PKI (certificates are capability-based, not identity-based)
tags:
  - pilot-protocol
  - trust-security
  - certificates
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

# Pilot Certificate

Capability certificate system for Pilot Protocol using Ed25519 signatures.

## Commands

### Issue Certificate
```bash
CERT_ID=$(openssl rand -hex 8)
EXPIRES_AT=$(date -u -d '+24 hours' +%Y-%m-%dT%H:%M:%SZ)

cat > ~/.pilot/certificates/issued/cert-$CERT_ID.json <<EOF
{
  "certificate_id": "$CERT_ID",
  "subject": {"hostname": "$SUBJECT"},
  "capabilities": ["read", "write", "admin"],
  "expires_at": "$EXPIRES_AT",
  "status": "active"
}
EOF
```

### Send Certificate
```bash
pilotctl --json send-file "$RECIPIENT" ~/.pilot/certificates/issued/cert-$CERT_ID.json
```

### Verify Certificate
```bash
EXPIRES_AT=$(jq -r '.expires_at' "$CERT_FILE")
EXPIRES_TS=$(date -d "$EXPIRES_AT" +%s)

[ $(date +%s) -le $EXPIRES_TS ] && echo "VERIFIED" || echo "EXPIRED"
```

### Check Capability
```bash
jq -e --arg cap "$CAPABILITY" '.capabilities[] | select(. == $cap)' "$CERT_FILE" && echo "Has capability"
```

## Workflow Example

```bash
#!/bin/bash
# Certificate authority

mkdir -p ~/.pilot/certificates/{issued,received}

CERT_ID=$(openssl rand -hex 8)
SUBJECT="admin.pilot"

cat > ~/.pilot/certificates/issued/cert-$CERT_ID.json <<EOF
{
  "certificate_id": "$CERT_ID",
  "subject": {"hostname": "$SUBJECT"},
  "capabilities": ["read", "write", "admin"],
  "expires_at": "$(date -u -d '+48 hours' +%Y-%m-%dT%H:%M:%SZ)",
  "status": "active"
}
EOF

pilotctl --json send-file "$SUBJECT" ~/.pilot/certificates/issued/cert-$CERT_ID.json
```

## Dependencies

Requires pilot-protocol, pilotctl, jq, and openssl.
