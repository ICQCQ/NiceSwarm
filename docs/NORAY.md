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
   netfox rollback core; NiceSwarm keeps its own host-authoritative snapshot netcode.

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
- [ ] ENet socket-reuse spike.
- [ ] `netfox.noray` client ported (minimal, no rollback core).
- [ ] `host_via_noray` / `join_via_noray` in `net.gd`.
- [ ] Menu wiring (OID-based host/join, direct-IP kept as fallback).
- [ ] Verified against a local Noray container.
- [ ] Noray server deployed (container + `.env` + healthcheck) — separate task.
- [ ] Public inbound unblocked (CGNAT decision: bridge ONT vs. VPS) — infra/owner.
