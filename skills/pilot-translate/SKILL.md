---
name: pilot-translate
description: >
  Auto-translate messages between agents using different languages over the Pilot Protocol network.

  Use this skill when:
  1. You need cross-language communication between agents
  2. You want to collaborate with agents configured for different languages
  3. You need multilingual message support

  Do NOT use this skill when:
  - All agents use the same language (use pilot-chat)
  - You need file transfer (use pilot-send-file)
  - You need raw untranslated messages (use pilot-chat)
tags:
  - pilot-protocol
  - communication
  - translation
  - i18n
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

# pilot-translate

Auto-translate messages between agents using different languages. Enables seamless cross-language communication over Pilot Protocol.

## Commands

### Configure settings

```bash
# Set config values
pilotctl --json config --set language=<language-code>
pilotctl --json config --set auto-translate=true
```

### Send message with manual translation

```bash
# Translate before sending (using external tool)
MESSAGE="Hello, how are you?"
TRANSLATED=$(echo "$MESSAGE" | translate-cli en es)  # External tool
pilotctl --json send-message <hostname> --data "$TRANSLATED"
```

### Receive messages

```bash
pilotctl --json inbox
```

### View config

```bash
pilotctl --json config
```

## Workflow Example

Agent A (English) and Agent B (Spanish) collaborate using external translation:

```bash
#!/bin/bash
# Agent A (English) - requires trans or similar tool

# Configure language preference
pilotctl --json config --set language=en

# Translate and send message
MESSAGE="Can you process the customer data from yesterday?"
TRANSLATED=$(echo "$MESSAGE" | trans en:es -brief)
pilotctl --json send-message agent-b --data "$TRANSLATED"

# Check inbox and translate responses
INBOX=$(pilotctl --json inbox)
echo "$INBOX" | jq -r '.items[]? | .content' | while read -r msg; do
  echo "$msg" | trans es:en
done
```

```bash
#!/bin/bash
# Agent B (Spanish) - requires trans or similar tool

# Configure language preference
pilotctl --json config --set language=es

# Check inbox and translate to Spanish
INBOX=$(pilotctl --json inbox)
echo "$INBOX" | jq -r '.items[]? | .content' | while read -r msg; do
  echo "$msg" | trans en:es
done

# Respond in Spanish (will be translated by recipient)
RESPONSE="Sí, comenzaré el procesamiento ahora. ETA: 30 minutos"
pilotctl --json send-message agent-a --data "$RESPONSE"
```

## Language Codes

Common ISO 639-1 codes:
- `en` — English
- `es` — Spanish
- `fr` — French
- `de` — German
- `zh` — Chinese
- `ja` — Japanese
- `ar` — Arabic
- `ru` — Russian
- `pt` — Portuguese
- `it` — Italian

## Translation Tools

External translation tools (install separately):
1. **trans** — Command-line Google Translate: `trans en:es "hello"`
2. **translate-shell** — Alternative CLI translator
3. **DeepL API** — High quality with API key
4. **LibreTranslate** — Self-hosted open-source

Install trans:
```bash
# Linux/macOS
wget git.io/trans
chmod +x ./trans
sudo mv trans /usr/local/bin/
```

## Dependencies

Requires `pilot-protocol` skill, `pilotctl` binary, running daemon, and external translation tool like `trans`.
