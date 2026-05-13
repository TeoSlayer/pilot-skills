// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Pilot Protocol Webhook Receiver for openclaw.
//
// Registers POST /pilot-webhook on openclaw's gateway HTTP server. The
// pilot-daemon's webhook plugin posts a JSON event to this path whenever
// it receives an inbox message, a file, or a trust handshake (see the
// daemon's `webhook_topics` filter — default subset is
// message.received, file.received, handshake.received, trust.changed).
//
// What we do with the event: append it as a single JSON line to
// ~/.openclaw/workspace/pilot-events.log. The agent's heartbeat /
// context engine can read that file on its next pass and surface
// pending events to the model. This keeps the plugin minimal and
// composable — operators can also `tail -f` the log directly.
//
// Auth is `none` by default because openclaw's gateway is loopback-
// bound on a typical install. When the gateway binds to a non-loopback
// interface, configure `auth: "bearer"` and set the shared token in
// the daemon's webhook headers (future work — pilot's webhook Client
// doesn't send Authorization today).

import { appendFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const DEFAULT_LOG_PATH = join(
  homedir(),
  ".openclaw",
  "workspace",
  "pilot-events.log",
);

async function ensureDir(filePath) {
  await mkdir(dirname(filePath), { recursive: true, mode: 0o700 });
}

function readBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on("data", (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        reject(new Error(`body exceeds maxBodyBytes=${maxBytes}`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    req.on("error", reject);
  });
}

const plugin = {
  id: "pilotprotocol-webhook-receiver",
  name: "Pilot Protocol Webhook Receiver",
  description:
    "Receives inbox/file/trust events from pilot-daemon at POST /pilot-webhook and appends them to ~/.openclaw/workspace/pilot-events.log.",
  register(api) {
    const cfg = api.pluginConfig ?? {};
    if (cfg.enabled === false) {
      api.logger?.info?.(
        "pilot-webhook-receiver: disabled via plugin config (enabled=false)",
      );
      return;
    }

    const path =
      typeof cfg.path === "string" && cfg.path.trim()
        ? cfg.path.trim()
        : "/pilot-webhook";
    const auth = cfg.auth === "bearer" ? "bearer" : "none";
    const logPath =
      typeof cfg.logPath === "string" && cfg.logPath.trim()
        ? cfg.logPath.trim()
        : DEFAULT_LOG_PATH;
    const maxBodyBytes =
      typeof cfg.maxBodyBytes === "number" && cfg.maxBodyBytes > 0
        ? Math.min(cfg.maxBodyBytes, 1024 * 1024)
        : 64 * 1024;

    api.registerHttpRoute({
      path,
      auth,
      handler: async (req, res) => {
        // Only POST. Hard-rejecting other verbs makes accidental
        // browser requests fail loudly rather than silently 200.
        if (req.method !== "POST") {
          res.statusCode = 405;
          res.setHeader("Allow", "POST");
          res.end("method not allowed");
          return true;
        }
        let raw;
        try {
          raw = await readBody(req, maxBodyBytes);
        } catch (err) {
          res.statusCode = 413;
          res.end(String(err?.message ?? err));
          return true;
        }
        // We accept any well-formed JSON. pilot emits
        // {event_id, event, node_id, timestamp, data}; we don't
        // schema-validate so future event-shape additions don't
        // require a plugin rev.
        let parsed;
        try {
          parsed = JSON.parse(raw);
        } catch {
          res.statusCode = 400;
          res.end("body is not valid JSON");
          return true;
        }
        try {
          await ensureDir(logPath);
          // One JSON object per line so the agent can stream-read.
          await appendFile(logPath, JSON.stringify(parsed) + "\n", {
            mode: 0o600,
          });
        } catch (err) {
          api.logger?.error?.(
            `pilot-webhook-receiver: append failed: ${String(err?.message ?? err)}`,
          );
          res.statusCode = 500;
          res.end("write failed");
          return true;
        }
        res.statusCode = 204;
        res.end();
        return true;
      },
    });

    api.logger?.info?.(
      `pilot-webhook-receiver: registered POST ${path} (auth=${auth}, log=${logPath}, maxBody=${maxBodyBytes}b)`,
    );
  },
};

export default plugin;
