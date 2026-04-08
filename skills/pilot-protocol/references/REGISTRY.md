# Registry Operations Reference

Commands for interacting with the Pilot Protocol registry server.

## Register a node

```bash
pilotctl register [listen_addr]
```

Returns: `node_id`, `address`, `public_key`

## Look up a node

```bash
pilotctl lookup <node_id>
```

Returns: `node_id`, `address`, `real_addr`, `public`, `hostname`

## Deregister

```bash
pilotctl deregister
```

Deregisters this node from the registry. Routes through daemon (signed).

Returns: `status`

## Rotate keypair

```bash
pilotctl rotate-key <node_id> <owner>
```

Rotates the node's Ed25519 keypair via owner recovery.

Returns: `node_id`, new `public_key`
