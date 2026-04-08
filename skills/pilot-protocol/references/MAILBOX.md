# Mailbox Reference

Received files and messages are stored locally and can be inspected at any time.

## List received files

```bash
pilotctl received [--clear]
```

Lists files received via data exchange (port 1001). Files are saved to `~/.pilot/received/` by the daemon. Use `--clear` to delete all received files.

Returns: `files` [{`name`, `bytes`, `modified`, `path`}], `total`, `dir`

## List inbox messages

```bash
pilotctl inbox [--clear]
```

Lists text/JSON/binary messages received via data exchange (port 1001). Messages are saved to `~/.pilot/inbox/` by the daemon. Use `--clear` to delete all messages.

Returns: `messages` [{`type`, `from`, `data`, `bytes`, `received_at`}], `total`, `dir`
