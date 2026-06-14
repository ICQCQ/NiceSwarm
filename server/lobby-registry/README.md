# NiceSwarm Lobby Registry

The directory that lets players **browse and join online co-op games without
typing an IP:port**. It maps a human room name → the host's **Noray OID** (the
handle the client hands to [Noray](https://github.com/foxssake/noray) to
actually connect). This is the net-new piece from
[`../../NETWORKING.md`](../../NETWORKING.md) §5 — Noray itself has no lobby.

- **Zero npm dependencies** — Node standard library only.
- **In-memory** — rooms are ephemeral; a restart just drops the list and hosts
  re-announce on their next heartbeat.
- Phase 1 of milestone **M7.6**.

## Run locally

```sh
cd server/lobby-registry
npm start            # node src/server.js  (listens on :8088)
npm test             # node --test  (11 unit tests, no deps)
```

Smoke test:

```sh
curl localhost:8088/health
curl -X POST localhost:8088/announce -H 'content-type: application/json' \
  -d '{"name":"My run","version":"0.9.0","host_oid":"oid_abc","max_players":4}'
curl 'localhost:8088/list?version=0.9.0'
```

## Configuration (env)

| Var | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8088` | HTTP listen port |
| `TRUST_PROXY` | `0` | Set `1` when behind a reverse proxy / Cloudflare Tunnel so the client IP is read from `X-Forwarded-For` (needed for the per-host room cap). |

## API

All responses are JSON. The `host` calls are made by a game hosting online; the
`client` call by a game browsing the list.

| Method | Path | Caller | Body / query | Returns |
| --- | --- | --- | --- | --- |
| GET | `/health` | — | — | `{ ok, rooms }` |
| GET | `/list?version=X.Y.Z` | client | `version` query | `{ rooms:[...], other_versions }` |
| POST | `/announce` | host | `{ name, version, host_oid, max_players, region? }` | `{ room_id, token }` |
| POST | `/heartbeat` | host | `{ room_id, token, players?, in_progress? }` | `{ ok }` |
| POST | `/withdraw` | host | `{ room_id, token }` | `{ ok }` |

- `token` (returned by `/announce`) is a **secret** proving room ownership; it is
  required for `heartbeat`/`withdraw` and is never included in `/list`.
- `/list` returns only **same-version**, **not-full**, **not-in-progress** rooms,
  freshest first. `other_versions` counts hidden rooms on different builds so the
  client can show "N games on other versions" instead of a silent empty list.
- Hosts should `heartbeat` ~every 5 s; rooms with no heartbeat for **15 s** are
  evicted (host crashed / closed laptop).

### Field rules (validated server-side)

| Field | Rule |
| --- | --- |
| `name` | string, control chars stripped, ≤ 32 chars, defaults to `Game` |
| `version` | must match `X.Y.Z` (the game's `VERSION` const) |
| `host_oid` | `[A-Za-z0-9._:-]`, ≤ 128 chars |
| `max_players` | clamped to 2–4 (`Net.MAX_PLAYERS`) |
| `region` | optional, `[A-Za-z0-9_-]`, ≤ 16 chars |

## Deploy (user's VPS)

Runs alongside Noray. Both are Node — one runtime to operate.

```sh
docker build -t niceswarm-lobby ./server/lobby-registry
docker run -d --name niceswarm-lobby --restart unless-stopped \
  -e TRUST_PROXY=1 -p 127.0.0.1:8088:8088 niceswarm-lobby
```

Put TLS in front (reverse proxy or **Cloudflare Tunnel**) and point the game's
`GameConfig` registry URL at the public hostname.

### Cloudflare Tunnel — good fit for *this* service

The registry is plain HTTP, so a Cloudflare Tunnel is an ideal front: free TLS,
hidden VPS IP, no inbound HTTP port. Set `TRUST_PROXY=1` so the per-host cap sees
the real client IP. **Note:** the Tunnel covers *only* this registry — **Noray's
UDP traversal/relay cannot go through it** (UDP isn't proxied and hole-punch
needs the real public address). See [`../../NETWORKING.md`](../../NETWORKING.md)
§11.

## Security posture

Implemented (see [`../../NETWORKING.md`](../../NETWORKING.md) §9):

- Per-IP **rate limiting** (60 req / 10 s) and a **per-host room cap** (5) +
  global cap (500).
- All input **validated/sanitized**; request body capped at 2 KB; numbers clamped.
- Ownership via a **secret token**, not trust-the-client; secrets never listed
  or logged.
- Errors never leak internals (500s are logged server-side only).

Out of scope here (handle at the edge): TLS termination, WAF, and Noray's own
UDP-amplification hardening.
