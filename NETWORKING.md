# NETWORKING.md — Online lobby, NAT traversal & relay

> Design plan for letting players find and join online co-op games **without
> knowing an IP:port** — across home NATs, with a self-hosted central server on
> a cloud VPS. This is the design for milestone **M7.6** (see [PLAN.md](PLAN.md)).
> Nothing here is implemented yet; this document is the agreed blueprint.

## 1. Where we are vs. where we're going

**Today** ([`scripts/core/net.gd`](scripts/core/net.gd), menu in
[`scripts/main.gd`](scripts/main.gd)):

- `ENetMultiplayerPeer`, host-authoritative, UDP port `24565`.
- Host calls `create_server`; clients type the host's **IP:port** and
  `create_client`. The menu prints the host's LAN IPs.
- This only works on a **LAN** (or with **manual port forwarding** — already
  flagged as a gap in PLAN.md M7.5). Two players on different home networks
  cannot connect, because the host sits behind a NAT that drops unsolicited
  inbound packets.

**Goal (user-stated):**

- A **lobby list** — players browse open games and click to join. **No IP:port
  typing, ever.**
- Works across consumer NATs on the open internet.
- A **central server self-hosted on the user's cloud VPS** (systemd/Docker).
- Keep latency low when a direct path exists; **relay** only when it doesn't.

## 2. The three jobs a "central server" must actually do

These are distinct problems. One box on the VPS can do all three, but keep them
mentally separate:

| Job | Problem it solves | Component |
| --- | --- | --- |
| **Discovery** | "What games are open? Join one without an address." | **Lobby Registry** (net-new, small) |
| **Traversal** | Open a direct path through both peers' NATs. | **Hole-punch / rendezvous** |
| **Relay** | When hole-punch fails (symmetric NAT/firewall), forward packets. | **Relay** |

The user's headline ask ("lobby list, no IP:port") is **Discovery** — and it is
**transport-agnostic**. Traversal + Relay are how the bytes actually flow once a
game is chosen.

## 3. Transport decision

### Research-&-Reuse result: adopt **Noray** for Traversal + Relay

[**Noray**](https://github.com/foxssake/noray) (foxssake, MIT) is a Godot-focused
"connection orchestrator and relay". Its client side, the
[**netfox.noray**](https://foxssake.github.io/netfox/latest/netfox.noray/) addon,
is **pure GDScript** and sits directly on top of `ENetMultiplayerPeer`:

- Host registers and receives an **OID** (OpenID, shareable handle) + **PID**
  (PrivateID, secret). Clients connect using the host's **OID** — never an
  IP:port.
- Does **NAT hole-punching**: both peers register public addresses with the
  server, exchange them, fire simultaneous packets to open NAT mappings, then a
  UDP handshake confirms the path is bidirectional.
- **Automatic relay fallback**: if punch-through fails, the same Noray server
  relays the traffic (one extra round-trip).
- Server is **TypeScript/Node.js, Docker-shipped, MIT** — deploys cleanly to the
  user's VPS.

**Why this fits NiceSwarm specifically (verified, not assumed):**

- **No GDExtension / no native dependency.** The client addon is GDScript. This
  preserves the project's pure-GDScript ethos *and* the single self-contained
  `build/NiceSwarm.exe` with **embedded PCK** (`build.ps1`, `embed_pck` in
  `export_presets.cfg`). See the WebRTC note below for why that matters.
- **Keeps the existing transport.** Noray hands back a connected
  `ENetMultiplayerPeer`, so the entire host-authoritative RPC layer in `net.gd`
  / `main.gd` (peer id 1 = host, world-state channels, etc.) works **unchanged**
  once the peer is established.
- **Self-hostable** on the VPS, MIT-licensed. A free public instance
  (`tomfol.io:8890`) exists for dev/testing only.

### What Noray does NOT give us — and must be built

Noray is **connection orchestration only**. From its own README: *"Sharing the
OpenID is not taken care of, you'll need a manual solution for that."* There is
**no lobby, no game list, no matchmaking.** A client can only connect to a host
whose OID it already knows.

➡️ **The net-new component is the Lobby Registry** (§5): the directory that turns
"browse open games" into "here is the chosen host's OID", which we then hand to
Noray. This is small, transport-agnostic, and is exactly the user's headline ask.

### Alternatives considered (documented, not chosen)

| Option | Traversal quality | Build/dep impact | Verdict |
| --- | --- | --- | --- |
| **A. Noray (ENet) + Lobby Registry** | Hole-punch + relay fallback (proven) | **None** — pure GDScript, single-exe intact | **✅ Recommended** |
| B. WebRTC + STUN/TURN (coturn on VPS) | Best-in-class ICE traversal; also unlocks web/HTML5 export | **Breaks single-exe**: needs `webrtc-native` **GDExtension**, whose `.dll` **cannot be embedded in the PCK** and must ship beside the exe (confirmed Godot limitation). Re-tooling `build.ps1`. | Reconsider only if web export becomes a goal |
| C. Hand-rolled ENet rendezvous + relay | Same idea as Noray, worse | None, but symmetric-NAT punch is unreliable and `ENetMultiplayerPeer` doesn't expose the socket reuse you'd need (`ENetConnection` low-level is poorly trodden) | Reinventing Noray — no |
| D. Always-relay, no hole-punch | N/A (always relayed) | None | Higher latency + full relay bandwidth bill for every session; Noray gives this **for free** as its fallback, so no reason to build it standalone |

`WebRTCMultiplayerPeer` *does* support star topology (`create_server` → id 1,
`create_client`), so it could host-authoritatively in principle — the blocker is
purely the GDExtension-vs-single-exe build constraint, which is project-specific.

## 4. Target architecture

```
                       ┌────────────────────── VPS (user's cloud) ──────────────────────┐
                       │                                                                 │
   ┌─────────┐  HTTPS  │   ┌──────────────────┐         ┌──────────────────────────┐    │
   │ Client  │◄───────►│   │  Lobby Registry  │         │          Noray           │    │
   │ (menu)  │  list/  │   │  (net-new, Node) │         │ (orchestrator + relay)   │    │
   └────┬────┘ announce│   │  game list ↔ OID │         │ TCP 8890 / UDP relays    │    │
        │              │   └──────────────────┘         └────────────┬─────────────┘    │
        │              └─────────────────────────────────────────────┼──────────────────┘
        │  1) browse list → choose room → get host OID                │
        │  2) register with Noray, request connect to host OID        │
        ▼                                                             ▼
   ┌─────────┐   hole-punch (direct UDP)  ──────────────────►  ┌─────────┐
   │ Client  │◄──────────────────────────────────────────────►│  Host   │
   │  ENet   │   …or relay fallback through Noray  ◄─────────► │  ENet   │
   └─────────┘                                                 └─────────┘
        once connected: existing host-authoritative RPCs run unchanged
```

Two server processes on one VPS:

1. **Noray** — adopted as-is (Docker). Traversal + relay.
2. **Lobby Registry** — small companion service we write. Same Node.js stack as
   Noray, so one runtime to operate.

## 5. Lobby Registry — the component we build

A tiny stateless-ish directory service. **In-memory is fine** (rooms are
ephemeral; a restart just drops the list and hosts re-announce on heartbeat).

### Room record

```
{
  room_id:    "uuid",          // server-assigned
  name:       "Chawasit's run",// host-provided, sanitized, length-capped
  host_oid:   "noray-open-id", // how clients actually connect (via Noray)
  version:    "0.9.0",         // from main.gd VERSION const — gate mismatches
  players:    2,               // current
  max_players:4,               // = Net.MAX_PLAYERS
  in_progress:false,           // mirror lock_session(): hide/grey started runs
  region:     "sea",           // optional, for future filtering
  last_seen:  <ts>             // updated by heartbeat; TTL eviction
}
```

### API (HTTP/JSON or a single WebSocket — see §12)

| Action | Who | Notes |
| --- | --- | --- |
| `announce(name, version, max)` → `room_id` | host | After it has a Noray OID. Returns the room handle. |
| `heartbeat(room_id, players, in_progress)` | host | ~every 5 s. Updates counts + liveness. |
| `withdraw(room_id)` | host | On start-locked or leave; also covered by TTL. |
| `list(version)` | client | Returns only **same-version**, **not-full**, **not-in-progress** rooms, freshest first. |

### Rules baked in (from advisor review)

- **Version gating** — `list` filters by the client's `VERSION`; never show a
  room a different build can't actually join. Surface a "N games on other
  versions" hint so it's not silently empty.
- **Heartbeat + TTL** — evict rooms with no heartbeat for ~15 s (host crashed /
  closed laptop). Prevents dead rooms accumulating.
- **Reflect `lock_session()`** — when the host presses Start, it flips
  `in_progress=true` (or withdraws). NiceSwarm has no mid-game join (M7.5), so
  started runs disappear from the browseable list.
- **No PII** — room "name" is the only user string; sanitize + length-cap it.

## 6. Client integration

### Menu / UI changes (`main.gd`)

- New **"Browse Games"** screen: polls `list()` (every ~3 s), shows
  `name · players/max · ping?`, click-to-join. This replaces IP:port entry as
  the *default* online path.
- **Host Online**: same as today but instead of "your LAN IP is …", it
  registers with Noray + announces to the registry, then shows "Listed as
  '<name>' — N joined".
- **Keep the existing LAN/direct-IP mode** as an advanced/offline option — do
  **not** regress the working path. (LAN parties + the headless co-op smoke
  tests depend on direct `host_game`/`join_game`.)

### Transport plumbing (`net.gd`)

- Add the `netfox.noray` addon under `addons/`.
- New helpers wrapping the Noray handshake that ultimately produce the same
  connected `ENetMultiplayerPeer` the code already expects:
  - `host_online(name) -> err` : Noray `register-host` → get OID/PID → announce
    to registry → listen.
  - `join_online(host_oid) -> err` : Noray register → `connect` to OID →
    hole-punch, else relay → `create_client`-equivalent peer.
- **Peer IDs unchanged**: host stays id 1, clients 2+. The existing
  `is_server()`, `get_peers()`, `peer_ids` logic in `main.gd` keeps working
  because Noray preserves Godot's standard ENet peer numbering.
- Keep `lock_session()`; additionally call registry `withdraw`/`in_progress`.

### Config

- Server endpoints (registry URL, Noray host/port) in `GameConfig` (alongside
  `NET_PORT`), overridable by env for dev vs. the user's VPS — mirrors the
  existing `NICESWARM_NET` test-hook style.

## 7. Connection flow (happy path)

**Host:**
1. Menu → "Host Online", enter a room name.
2. `net` registers with Noray → receives `oid`/`pid`.
3. `net` announces `{name, version, max}` to the Lobby Registry → `room_id`.
4. Heartbeats every ~5 s; ENet peer listens for incoming (punched/relayed).

**Client:**
1. Menu → "Browse Games" → registry `list(version)` → pick a row (carries `oid`).
2. `net` registers with Noray, requests connect to host `oid`.
3. Noray exchanges public addrs → **hole-punch**; on failure → **relay**.
4. ENet connection completes → `multiplayer.connected_to_server` → existing
   `on_join_ok()` → host `start_game` broadcast → game runs as it does today.

## 8. Implementation phases → milestones

Lead with the transport-agnostic registry so the **headline UX ships first**;
add traversal, then harden. Each phase is independently testable.

- **Phase 1 — Lobby Registry + Noray relay (ships "no IP:port"):**
  Stand up Noray (Docker) + the registry service on the VPS. Client: addon
  wired, Browse/Host-Online screens, connect via Noray (relay path is enough to
  prove end-to-end). At this point two players on different networks can find &
  join each other from a list. **This already satisfies the user's core ask.**
- **Phase 2 — Direct hole-punch:** confirm netfox.noray punch-through engages so
  most sessions go direct (lower latency, off the relay). Relay remains the
  automatic fallback.
- **Phase 3 — Hardening:** version-mismatch UX, registry TTL/eviction tuning,
  reconnect/jitter, security pass (§9), ops/monitoring (§11), docs. Folds into
  PLAN.md **M7.5 co-op hardening**.

## 9. Security (first public-facing service — mandatory pass)

Per the project's security rules, this is bolted **in**, not on:

- **Rate-limit** registry `announce`/`heartbeat`/`list` per IP; cap rooms per IP.
- **Validate & sanitize all input** — room name (length, strip control/markup),
  version string format, numeric ranges for player counts. Never trust client
  numbers; clamp.
- **UDP amplification risk** — Noray's registration/relay are UDP; ensure
  responses aren't larger than requests to unverified addresses, and keep the
  relay port range firewalled to Noray only. Track upstream Noray advisories.
- **No secrets in client/logs** — the Noray **PID is secret**; never log it or
  put it in the registry. Only the **OID** is shared.
- **TLS** on the registry HTTP endpoint (reverse-proxy, or Cloudflare Tunnel — §11).
- **DoS posture** — registry is in-memory and cheap; cap total rooms; the VPS
  firewall exposes only 8890 (Noray reg), the relay UDP range, the registry
  port, and 22.

## 10. Bandwidth & cost (self-hosted)

Worst case is the **relay** path (direct hole-punch costs the VPS ~nothing after
setup). Order-of-magnitude for budgeting, from the current sync model
(CLAUDE.md): host broadcasts enemies 12 Hz, items 8 Hz, HUD 4 Hz, ≤80
entities/packet; clients send pos/facing 20 Hz.

- Rough host→client downstream under load: ballpark **30–80 KB/s per client**.
  A relayed 4-player game (host + 3) ≈ host's combined stream both directions
  through the VPS. **Estimate ≈ 0.5–1.5 Mbit/s per fully-relayed 4p session.**
- A small VPS (1 vCPU / 1 GB, a few TB/mo transfer) comfortably handles a
  handful of concurrent relayed games. **Most sessions should be direct**
  (hole-punch) and cost only the lightweight registration traffic.
- ⚠️ These are estimates — **measure** real packet sizes with a 2-machine
  capture in Phase 1 before sizing the VPS plan. (Action item, not a fact.)

## 11. VPS deployment & ops

- **Noray**: `docker compose up -d` from its repo. Expose **TCP 8890**
  (registration), **UDP 8809** (remote addr registration), **UDP 49152–51200**
  (relays, configurable/narrowable). 8891 (metrics) stays internal.
- **Lobby Registry**: small Node service (same runtime as Noray), behind a
  TLS reverse proxy; `systemd` unit or a second compose service.
- **Firewall**: default-deny; open only the ports above + SSH.
- **Monitoring**: scrape Noray's 8891 metrics; basic registry `/health` +
  room-count gauge.
- **DNS**: one record (e.g. `play.<domain>`) for the registry; clients ship with
  that hostname in `GameConfig`.

### Cloudflare Tunnel — partial fit (important caveat)

**Short answer: yes for the Lobby Registry, no for Noray's traversal/relay.**

- ✅ **Lobby Registry behind a Cloudflare Tunnel works great.** It's plain
  HTTP(S), which is exactly what `cloudflared` is built to proxy. You get free
  TLS, a stable hostname, and you **don't expose the VPS IP or open an inbound
  HTTP port** — the tunnel dials out. Recommended for the registry.
- ❌ **Noray cannot run through a Cloudflare Tunnel.** Two hard blockers:
  1. **UDP isn't proxied.** Cloudflare Tunnel carries HTTP and (via limited
     setups) some TCP, but **not arbitrary inbound UDP**. Noray's address
     registration (UDP 8809) and **all relay traffic (UDP 49152–51200) are UDP**
     — there's nothing for the tunnel to carry.
  2. **Hole-punch needs the real public UDP source address.** NAT punchthrough
     works precisely because Noray observes each peer's *actual* public IP:port
     and feeds it to the other peer. A proxy/tunnel **rewrites or hides** that
     source address, so the punch can never line up. Tunneling would defeat the
     entire traversal mechanism even if UDP were supported.
- ➡️ **Recommended hybrid:** Registry → Cloudflare Tunnel (hidden IP, free TLS).
  Noray → **direct public UDP/TCP ports** on the VPS (open the ports above in the
  firewall; point clients at the raw VPS IP/hostname for Noray). This keeps the
  HTTP surface zero-exposure while giving traversal the direct UDP it requires.
  Since the user already has a VPS with a public IP, this is straightforward.
- *(If avoiding any exposed UDP is a hard requirement, the only alternative is a
  pure-relay TURN-style service that the client reaches over TCP/TLS — but that
  forfeits hole-punch, adds latency to every session, and still isn't what
  Cloudflare Tunnel is for. Not recommended.)*

## 12. Open decisions (defer to implementation, flag now)

1. **Registry transport**: plain HTTP/JSON polling (simplest, fine at this
   scale) vs. a single WebSocket (push updates, live player counts). *Lean:
   HTTP polling for Phase 1; revisit if the list feels stale.*
2. **Room codes too?** A short "join by code" alongside the browse list is cheap
   once the registry exists (code → room_id). Nice-to-have.
3. **Noray version pinning** + who owns upgrades on the VPS.
4. **Public vs. invite-only rooms** — current plan lists all same-version rooms
   publicly; add a private flag later if needed.

## 13. Deployment plan (decided 2026-06-15) & status

**Status: BLOCKED — waiting on a fixed/static public IP from the home ISP.**
Online co-op is built, verified (relay path), and in PR #8. Deploy is paused
until the home network has a static-IP package (today the public IP is dynamic
and the free-VPS fallback was unavailable when checked). Resume from here.

**Chosen architecture — port-forward path (NOT tunnel-only):**
- **Lobby Registry → docker-server (`192.168.1.36`), behind the Cloudflare
  Tunnel** at `niceswarm.hh.coffee` (proxied / orange-cloud → Traefik
  `http://traefik:80` on the `proxy` network — mirrors the `auction.hh.coffee`
  stack). HTTP only; no port-forward.
- **Noray → docker-server, exposed via home-router port-forwards** to
  `192.168.1.36`, reachable at `noray.hh.coffee` (**DNS-only / grey-cloud** A
  record → the home public IP; Noray's raw UDP/TCP must bypass the tunnel).

**Why not tunnel-only:** a Cloudflare Tunnel carries only HTTP/WebSocket and
hides the real source address — it cannot carry Noray's UDP or its hole-punch.
Tunnel-only would force a WebSocket *always-relay* (no P2P) + replacing the
Noray transport; rejected in favour of keeping the built-and-verified UDP path.

**Port-forwards (home router → `192.168.1.36`):**

| Proto | Port(s) | Noray role |
| --- | --- | --- |
| TCP | 8890 | client registration / orchestration |
| UDP | 8809 | remote-address registration (NAT discovery) |
| UDP | 49152–51200 (narrow to ~200 in Noray config) | relay data ports |

(8891 metrics stays internal — do not forward.)

**Confirm before/at deploy:**
1. **Static public IP** (the package being waited on). With a static IP there is
   **no DDNS** — set the `noray.hh.coffee` A record once. (If the IP stays
   dynamic, add a Cloudflare-API DDNS updater, grey-cloud record.)
2. **Not behind CGNAT** — a real fixed IP should settle this, but verify the
   router WAN IP equals `curl ifconfig.me` and isn't in `100.64.0.0/10`. If
   CGNAT persists, port-forward can't work → fall back to a public VPS for Noray
   (Oracle Always Free / LightNode) or the WebSocket-via-tunnel rewrite (§3 alt).

**Then point the client** (`GameConfig`): `LOBBY_URL=https://niceswarm.hh.coffee`,
`NORAY_HOST=noray.hh.coffee`, `NORAY_PORT=8890`.

**Remaining build work (when unblocked):**
- Compose stacks: registry (Traefik labels for `niceswarm.hh.coffee` on the
  `proxy` network) + Noray (host port publishes, relay range pinned in config).
- Owner Cloudflare-dashboard actions: add the proxied `niceswarm.hh.coffee`
  tunnel hostname; add the grey-cloud `noray.hh.coffee` A record.
- Real **2-machine playtest** — the direct NAT-punch path is the one piece not
  yet exercised (same-machine testing routes via relay).

## References

- Noray (server, MIT, Node/Docker): <https://github.com/foxssake/noray>
- netfox.noray (GDScript client addon): <https://foxssake.github.io/netfox/latest/netfox.noray/>
- NAT punchthrough & relay fallback overview: <https://deepwiki.com/foxssake/netfox/6.1-nat-punchthrough-and-connectivity>
- Godot `WebRTCMultiplayerPeer` (alternative B): <https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html>
- GDExtension cannot embed in PCK (why B breaks single-exe): <https://github.com/godotengine/godot/issues/87761>
