---
name: pilot-database-bridge
description: >
  Query remote databases through Pilot Protocol tunnels.

  Use this skill when:
  1. You need to access databases behind NATs or firewalls
  2. You want to query remote databases without direct network access
  3. You're building agents that need secure database connectivity

  Do NOT use this skill when:
  - Database is already publicly accessible
  - You have direct VPN or network access
  - The daemon is not running
tags:
  - pilot-protocol
  - integration
  - database
  - bridge
  - sql
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

# Pilot Database Bridge

Secure database access through Pilot Protocol tunnels for remote PostgreSQL, MySQL, MongoDB, and Redis.

## Commands

### Start Gateway
```bash
pilotctl --json gateway start
```

### Map Remote Database
```bash
pilotctl --json gateway map db-server 192.168.100.10
```

### List Mappings
```bash
pilotctl --json gateway list
```

### Stop Gateway
```bash
pilotctl --json gateway stop
```

## Workflow Example

```bash
#!/bin/bash
# Access remote PostgreSQL

pilotctl --json daemon start
pilotctl --json find postgres-prod
pilotctl --json gateway start
pilotctl --json gateway map postgres-prod 192.168.100.10

# Connect with standard client
psql -h 192.168.100.10 -p 5432 -U dbuser -d production
```

## Supported Databases

```bash
# PostgreSQL
pilotctl --json gateway map postgres-server 192.168.100.10
psql -h 192.168.100.10 -p 5432 -U user -d database

# MySQL
pilotctl --json gateway map mysql-server 192.168.100.11
mysql -h 192.168.100.11 -P 3306 -u root -p

# MongoDB
pilotctl --json gateway map mongo-server 192.168.100.12
mongosh mongodb://192.168.100.12:27017

# Redis
pilotctl --json gateway map redis-server 192.168.100.13
redis-cli -h 192.168.100.13 -p 6379
```

## Dependencies

Requires pilot-protocol skill, running daemon, and database clients (psql, mysql, mongosh, redis-cli).
