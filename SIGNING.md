# Signed content

pilot-daemon's skill injector
([`pilot-protocol/skillinject`](https://github.com/pilot-protocol/skillinject))
fetches `inject-manifest.json` and the files it lists from this repo every
15 minutes and writes them into agents' skill folders and heartbeat files.
From the release that ships `cmd/sign-skills`, it refuses anything that is
not signed by the pilot-skills key, which it has built in:

```
95effdc0863c8e37d65abb292f338856ac703705041a23246c8e468d7426fb31
```

## What is signed

`inject-manifest.json` and every file it makes the daemon fetch:

- `skills/<entrypoint>/SKILL.md` (today `skills/pilotctl/SKILL.md`)
- every `heartbeatTemplate` (`heartbeats/*.md`)
- every `src`: helper scripts and plugin files
  (`workflow-injection/...`), at any depth, so rows a later daemon reads
  (`plugins` next to `plugin`) are covered too

Values under `retired` are not signed: retired surfaces are only removed,
never fetched. Everything else in the repo (other skills, `skills.json`,
`setups.json`, `index.html`, the Muse installer) is not fetched by the
injector and is not signed.

Each signed file has a `<file>.sig` next to it: one line, the base64 Ed25519
signature over `"pilot-skills-sig-v1"`, a NUL byte, the file's repo path, a
NUL byte, and the file's bytes. The path is part of the signature, so a
signed file cannot be served in place of another.

## What a daemon does with them

A tick fetches every file it will use and its `.sig`, and checks them all
before it writes anything. If one is missing, malformed, signed by another
key or changed after signing, the tick writes nothing, keeps what the last
good tick installed, logs `skillinject refused content that failed its
signature check; nothing changed` with the file's name, and tries again 15
minutes later. Older daemons ignore the `.sig` files.

## Signing: CI does it

`build-pilotctl-skill.yml` runs on every push to `main`. It:

1. rebuilds `skills/pilotctl/SKILL.md` from `ONBOARDING.md` and the skills
   in `referencedSkills` (`build-pilotctl-skill.sh`);
2. signs the manifest and every file it lists with
   `sign-skills sign -key-env SKILLS_SIGNING_KEY`, from the skillinject
   version pinned in the workflow (`SIGN_SKILLS_VERSION`);
3. verifies the result twice (`sign-skills verify` and `tests/signatures`);
4. commits the rebuilt `SKILL.md` and the `.sig` files to `main` as
   github-actions[bot], if anything changed.

So a change to a signed file, or to `ONBOARDING.md` or a referenced skill,
needs no manual step: push it or merge the pull request, and about a minute
later `main` has the rebuilt file and its signatures. Until that commit
lands, hosts on a signing release refuse the update and keep what they
have, then pick it up on a later tick. Signing is deterministic, so a push
that changes nothing signed makes no commit.

On pull requests the workflow only rebuilds `SKILL.md`, without the key, to
show that the generator still runs and what main will get.

## The key

The private key (the 32-byte seed, hex) is the repository secret
`SKILLS_SIGNING_KEY`. The owner's macOS login keychain holds the same key
(generic password, service `pilot-skills-signing`). Only the signing step
of `build-pilotctl-skill.yml` reads the secret; `sign-skills` never prints
it or writes it to disk, and refuses a key whose public half is not the one
the daemon has built in.

Anyone who can change the workflows on `main` can sign with the secret, so
write access to this repo is what the signature trusts. Keep that list
short.

To set or replace the secret from the keychain without printing it:

```sh
security find-generic-password -s pilot-skills-signing -a "$USER" -w \
  | tr -d '\n' | gh secret set SKILLS_SIGNING_KEY -R TeoSlayer/pilot-skills
```

To sign by hand (for example a pull request branch, or if CI cannot run),
`./sign-skills.sh` does the same rebuild and signing with the key from the
keychain. To check a checkout without the key:

```sh
go run github.com/pilot-protocol/skillinject/cmd/sign-skills@latest verify -repo .
```

## Checks

- `test.yml` job `signatures` (`tests/signatures`, standard library only)
  runs on pushes and pull requests. Every listed file must exist, be a
  regular file under the daemon's 1 MiB fetch cap, and match its `.sig`.
  Files the push or pull request itself changed are reported instead of
  failing when their signature is missing or stale, because CI signs them
  on `main`; every other file must verify.
- The `build-and-sign` job of `build-pilotctl-skill.yml` fails if signing
  or either verification fails, which leaves `main` unsigned for that
  change: look at that run first.

`test.yml` still rebuilds and commits `skills.json` and `setups.json`. The
daemon does not fetch them, so they are not signed.

## Order of rollout

1. Merge the signatures and the signing workflow to `main` (older daemons
   ignore `.sig` files, so this changes nothing on hosts).
2. Check that `raw.githubusercontent.com` serves them:
   `go run .../sign-skills@latest verify` on a fresh clone, or fetch
   `inject-manifest.json.sig`.
3. Only then release a pilot-daemon whose skillinject requires signatures.

## Losing or replacing the key

The public key is compiled into the daemon. A new key means a new daemon
release with the new `DefaultManifestPublicKeyHex`, a new
`SKILLS_SIGNING_KEY` secret, and content signed with the new key only
reaches hosts that upgraded. If the secret is lost, set it again from the
keychain; if both are lost, the key is gone. An operator who runs a fork
can point a host at their own key with `PILOT_SKILLINJECT_MANIFEST_PUBKEY`
(or `PILOT_SKILLINJECT_PUBKEY`, or `~/.pilot/skillinject.pub`).
