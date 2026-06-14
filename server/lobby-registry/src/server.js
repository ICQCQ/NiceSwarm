// Lobby Registry — HTTP layer. Thin wrapper over LobbyRegistry (registry.js).
// Zero npm dependencies: built-in node:http only. See NETWORKING.md §5/§9/§11.
//
// Endpoints:
//   GET  /health                 -> { ok, rooms }
//   GET  /list?version=X.Y.Z     -> { rooms:[...], other_versions }
//   POST /announce {name,version,host_oid,max_players,region} -> { room_id, token }
//   POST /heartbeat {room_id,token,players,in_progress}        -> { ok }
//   POST /withdraw  {room_id,token}                            -> { ok }

import { createServer } from 'node:http'
import { LobbyRegistry, validateAnnounce } from './registry.js'

const PORT = Number.parseInt(process.env.PORT ?? '8088', 10)
// When behind a reverse proxy / Cloudflare Tunnel, trust X-Forwarded-For.
const TRUST_PROXY = process.env.TRUST_PROXY === '1'
const BODY_MAX = 2048 // bytes — payloads are tiny; reject anything larger
const RATE_MAX = 60 // requests
const RATE_WINDOW_MS = 10_000 // per IP per window

const registry = new LobbyRegistry()

// --- simple per-IP fixed-window rate limiter --------------------------------
const buckets = new Map() // ip -> { count, resetAt }
function rateLimited(ip, now) {
	let b = buckets.get(ip)
	if (!b || now >= b.resetAt) {
		b = { count: 0, resetAt: now + RATE_WINDOW_MS }
		buckets.set(ip, b)
	}
	b.count++
	return b.count > RATE_MAX
}
// periodic cleanup so the bucket map can't grow unbounded
setInterval(() => {
	const now = Date.now()
	for (const [ip, b] of buckets) if (now >= b.resetAt) buckets.delete(ip)
}, RATE_WINDOW_MS).unref()

function clientIp(req) {
	if (TRUST_PROXY) {
		const xff = req.headers['x-forwarded-for']
		if (typeof xff === 'string' && xff.length) return xff.split(',')[0].trim()
	}
	return req.socket.remoteAddress ?? 'unknown'
}

function send(res, status, obj) {
	const body = JSON.stringify(obj)
	res.writeHead(status, {
		'content-type': 'application/json',
		'access-control-allow-origin': '*', // harmless for a public game list; helps a future web client
		'cache-control': 'no-store',
	})
	res.end(body)
}

function readJson(req) {
	return new Promise((resolve) => {
		let data = ''
		let tooBig = false
		req.on('data', (chunk) => {
			data += chunk
			if (data.length > BODY_MAX) {
				tooBig = true
				req.destroy()
			}
		})
		req.on('end', () => {
			if (tooBig) return resolve({ error: 'body too large' })
			if (!data) return resolve({})
			try {
				resolve(JSON.parse(data))
			} catch {
				resolve({ error: 'invalid json' })
			}
		})
		req.on('error', () => resolve({ error: 'read error' }))
	})
}

const server = createServer(async (req, res) => {
	const now = Date.now()
	const ip = clientIp(req)
	if (rateLimited(ip, now)) return send(res, 429, { error: 'rate limited' })

	const url = new URL(req.url, 'http://localhost')
	const path = url.pathname
	const method = req.method

	try {
		if (method === 'GET' && path === '/health') {
			return send(res, 200, { ok: true, rooms: registry.size })
		}

		if (method === 'GET' && path === '/list') {
			const version = url.searchParams.get('version') ?? ''
			return send(res, 200, registry.list(version))
		}

		if (method === 'POST' && path === '/announce') {
			const body = await readJson(req)
			if (body.error) return send(res, 400, { error: body.error })
			const { errors, value } = validateAnnounce(body)
			if (errors.length) return send(res, 400, { error: errors.join('; ') })
			const result = registry.announce(value, ip)
			if (result.error) return send(res, 429, result)
			return send(res, 200, result)
		}

		if (method === 'POST' && path === '/heartbeat') {
			const body = await readJson(req)
			if (body.error) return send(res, 400, { error: body.error })
			const result = registry.heartbeat(body.room_id, body.token, {
				players: body.players,
				in_progress: body.in_progress,
			})
			return send(res, result.error ? 404 : 200, result)
		}

		if (method === 'POST' && path === '/withdraw') {
			const body = await readJson(req)
			if (body.error) return send(res, 400, { error: body.error })
			const result = registry.withdraw(body.room_id, body.token)
			return send(res, result.error ? 403 : 200, result)
		}

		return send(res, 404, { error: 'not found' })
	} catch (err) {
		// Never leak internals to the client; log server-side.
		console.error('[lobby] request error', err)
		return send(res, 500, { error: 'internal error' })
	}
})

server.listen(PORT, () => {
	console.log(`[lobby] registry listening on :${PORT} (trust_proxy=${TRUST_PROXY})`)
})
