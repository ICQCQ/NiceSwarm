# Noray NAT-traversal lobby

Online co-op currently requires a **directly reachable host** (`net.host_game` /
`net.join_game` in `scripts/core/net.gd` → raw ENet on UDP `24565`). That only
works on LAN or when the host has a port-forward. **Noray** ([foliotek/noray](https://github.com/foliotek/noray))
is a small relay/registrar that lets two peers behind NAT find and reach each
other: hole-punch when possible, relay through the server as fallback.

This doc is the single source of truth for the game-side integration. The
**public DNS / port-forward layer** is tracked in the infra repo
(`F:\ZalzerTriratInfraDoc/network/external-access.md` → "ns.javis.coffee —
niceswarm Noray relay").

## Server contract (from infra repo, verified 2026-06-18)

- **Public name:** `ns.javis.coffee` (DDNS straight to the home IP — Noray is raw
  TCP+UDP and is **not** Cloudflare-Tunnel-able). Kept current by
  `favonia/cloudflare-ddns` on docker-server; resolves to the dynamic home IPv4
  (`125.27.255.192` at time of writing), grey-cloud, TTL 60.
- **Server host:** docker-server `192.168.1.36` (deploy lives in THIS project's
  session, not the infra repo).
- **Ports** (router forwards all → `192.168.1.36`):
  | External | Proto | Noray `.env` var | Purpose |
  | --- | --- | --- | --- |
  | 8890 | TCP | `NORAY_SOCKET_PORT=8890` | client registration / connect requests |
  | 8809 | UDP | `NORAY_UDP_REGISTRAR_PORT=8809` | UDP address registration (host) |
  | 49152–49199 | UDP | `NORAY_UDP_RELAY_PORTS=49152-49199` | relay slots (48, trimmed from default) |
  | 8891 | TCP | `NORAY_HTTP_PORT` | Prometheus metrics — **keep LAN-only, do NOT forward** |

## ⚠️ Blocker: inbound to the home is currently BLOCKED (CGNAT/double-NAT)

An external probe on 2026-06-18 (58-node check-host.net TCP test to `:8890` with a
listener running) got **0 connections through**. `mtr` to 8.8.8.8 shows a private
`10.2.1.82` hop **upstream of the home router** → the public `125.27.x` is likely
**not on the home router** (NT is NAT'ing it), so a port-forward on `192.168.1.1`
can never receive inbound.

- **Decisive datum still to read:** the home router's WAN/Internet IP. If it shows
  `125.27.255.192` → not CGNAT (then it's ISP filtering or a forward misconfig). If
  it shows private (`100.64.x` / `10.x` / `192.168.x`) → CGNAT, home port-forward is
  futile → need NT to bridge the ONT / give a static IP, **or** host Noray on a
  cheap public VPS and point `ns.javis.coffee` there instead.
- **Until inbound is proven, `ns.javis.coffee` cannot serve as the relay.** The
  game-side code below can still be developed and verified against a **local Noray
  container** (same machine / LAN), which needs no inbound from the internet.

## Implementation plan (game side)

Keep the existing direct-IP path 100% intact; Noray is an **additional** way to
get a host/join, not a replacement. Direct-IP stays the fallback.

1. **De-risk the ENet socket-reuse spike first.** Noray hole-punching requires the
   game's ENet traffic to flow over the **same local UDP port** that did the
   handshake punch. In Godot 4 this is `ENetConnection.create_host_bound(bind_addr,
   bind_port, ...)` then `connect_to_host(...)` (client) / accepting (host),
   wrapped into an `ENetMultiplayerPeer` via `set_host`/`create_*` — prove a bound
   port survives the punch→ENet transition on localhost before building the rest.
2. **Reuse, don't hand-roll.** Port the proven [`netfox.noray`](https://github.com/foxssake/netfox)
   client (repo `foxssake/netfox`, addon `addons/netfox.noray/`). Three runtime
   files cover register → OID/PID → UDP registration → connect/handshake → relay
   fallback: `noray.gd` (`_Noray`, autoload **`Noray`**), `packet-handshake.gd`
   (`_PacketHandshake`, autoload **`PacketHandshake`**), `protocol-handler.gd`. Both
   `_Noray`/`_PacketHandshake` extend `Node` (must be in the tree — register as
   autoloads, do NOT use the editor plugin). The **only** netfox dependency is
   `NetfoxLogger` in `noray.gd` (static `_for_noray(name)` + `info/debug/error/trace
   (fmt, args[])`) — stub it in ~10 lines or strip the calls. Do **not** pull the
   netfox rollback core; NiceSwarm keeps its own host-authoritative snapshot netcode
   (tick rates / channels / interpolation tuning live in [`NETCODE.md`](./NETCODE.md)).

   **API:** `await Noray.connect_to_host(host, 8890)` → `Noray.register_host()` →
   `await Noray.on_pid` → `await Noray.register_remote(8809)` sets `Noray.local_port`.
   `Noray.oid` = shareable join code; `Noray.pid` = secret. Host listens on
   `on_connect_nat`/`on_connect_relay(addr, port)` → `await PacketHandshake.over_enet
   (peer.host, addr, port)`. Client `Noray.connect_nat(host_oid)` (fallback
   `connect_relay`), on the same signals binds a `PacketPeerUDP` to `Noray.local_port`,
   `await PacketHandshake.over_packet_peer(udp)`, then ENet-connects.
3. **Add Noray entry points to `net.gd`**, parallel to the existing API:
   - `host_via_noray(noray_host, noray_port) -> String` — register as host, expose
     our **OID** (the shareable lobby code) for joiners.
   - `join_via_noray(oid, noray_host, noray_port) -> String` — connect to a host by
     its OID.
   Both return `""` on success or an error string (same contract as
   `host_game`/`join_game`), set `multiplayer.multiplayer_peer`, and set `active`.
4. **Wire the menu** (`main._on_host_pressed` / `_on_join_pressed` in `scripts/main.gd`):
   a mode toggle (Direct ↔ Online), host shows its OID to copy, join takes an OID
   instead of IP:port. The lobby/rejoin/late-join flow downstream is unchanged
   (it's all RPC over whatever `multiplayer_peer` we set).
5. **Verify against a LOCAL Noray container** (`docker run` on docker-server or the
   dev box) — host + join over loopback/LAN, confirm both direct-punch and forced
   relay. The public-internet path stays blocked until the CGNAT question is
   resolved (see above).

## Status

- [x] Infra contract + blocker captured (this doc).
- [x] `netfox.noray` client vendored (`addons/netfox.noray/`, 3 files + `NetfoxLogger`
  stub, no rollback core). Autoloads `Noray` + `PacketHandshake` in `project.godot`.
- [x] `host_via_noray` / `join_via_noray` in `net.gd` → `NorayLobby`
  (`scripts/core/noray_lobby.gd`); direct-IP `host_game`/`join_game` kept as fallback.
- [x] Menu wiring (OID join code) + `NICESWARM_NET=noray_host`/`noray_join` headless
  hooks (`NICESWARM_NORAY_HOST`/`NICESWARM_NORAY_OID`).
- [x] **Verified against a live Noray server (2026-06-18).** Ran `ghcr.io/foxssake/noray:main`
  on docker-server (`192.168.1.36`, throwaway `--rm`); two headless instances
  rendezvoused: host advertised OID, joiner connected by OID, both hit
  `start_game peers=[1, <id>]`, joiner received world-state + enemy puppets. This
  proves the ENet socket-reuse handoff over `Noray.local_port` (the one risk a parse
  check couldn't settle). The ENet socket-reuse "spike" is therefore covered by the
  full integration test — no separate spike needed.
- [x] **Noray server deployed (persistent, LAN) — 2026-06-18.** Compose stack on
  docker-server at `~/noray/` (`compose.yml` + `.env`), `restart: unless-stopped`,
  ports 8890/tcp · 8809/udp · 49152-49199/udp. Status: healthy.
  Manage with `cd ~/noray && docker compose {up -d|logs|down}`. Game reaches it on
  the LAN via `NICESWARM_NORAY_HOST=192.168.1.36` (or the lobby host field).
- [x] **Swapped to hardened fork `noray:trirat` — 2026-06-18.** After a security
  review (see `F:\ZalzerTriratInfraDoc\network\noray-security-review.md`) the
  server now runs a **private fork** ([github.com/chawasit/noray](https://github.com/chawasit/noray),
  `upstream` = foxssake/noray) instead of `ghcr.io/foxssake/noray:main`. Build
  source on docker-server at `~/noray-src/` (`docker build -t noray:trirat .`;
  re-ship with `git archive`). Fixes: **DoS-1** (a relay crossing a bandwidth/
  lifetime/traffic cap no longer crashes the whole server — drops instead;
  proven live), **DoS-2/3** (dynamic-relay exhaustion guard, per-connection host
  cap + command rate limit), and **IL-2** (metrics bound to container loopback,
  `8891` publish removed — no longer LAN-reachable; healthcheck still green).
  Relay caps tuned generous for co-op (1mb/s · 24hr · 64gb) so the now-dropping
  constraints don't silently desync relayed players. See the fork's `FORK.md`.
  ⚠️ `NORAY_OID_LENGTH=6` kept (shareable join code) — fine for friends-code
  co-op; raise to ≥10 before any internet exposure if host-IP/lobby disclosure
  matters (rate-limiting does NOT stop distributed OID enumeration).
- [ ] Public inbound unblocked (CGNAT decision: bridge ONT vs. VPS) — infra/owner.
  Until then the stack is LAN-only; `ns.javis.coffee` won't reach it from the internet.

**Healthcheck gotcha:** the image is Debian-based and runs via `pnpm start:prod` —
`node` is NOT on the exec PATH and there's no `nc`/`wget`, so a node/nc TCP
healthcheck fails ("unhealthy" while the server is actually fine). `curl` IS present;
the working check is `curl -fsS http://127.0.0.1:8891/metrics` (returns 200; `/`
404s).

**Known follow-up (pre-existing, not Noray-specific):** when a co-op peer leaves
mid-run it stays in `peer_ids` (for rejoin) but drops out of
`multiplayer.get_peers()`, so `main._refresh_pings()` calls
`ENetMultiplayerPeer.get_peer(ghosted_id)` and the engine logs
`Condition "!peers.has(p_id)" is true`. Cosmetic (ping HUD). Cheap fix: intersect
`peer_ids` with `multiplayer.get_peers()` before `get_peer`. Affects direct-IP co-op
too — out of scope for this change.
