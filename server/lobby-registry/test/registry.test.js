// Unit tests for the Lobby Registry core logic. Zero deps — node:test.
//   run: node --test
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
	LobbyRegistry,
	validateAnnounce,
	sanitizeName,
	clamp,
	LIMITS,
} from '../src/registry.js'

const VALID = { name: 'My Run', version: '0.9.0', host_oid: 'abc123', max_players: 4 }

test('clamp bounds values', () => {
	assert.equal(clamp(5, 0, 4), 4)
	assert.equal(clamp(-1, 0, 4), 0)
	assert.equal(clamp(3, 0, 4), 3)
})

test('sanitizeName strips control chars, caps length, defaults when empty', () => {
	assert.equal(sanitizeName('hi there'), 'hi there')
	assert.equal(sanitizeName('   '), 'Game')
	assert.equal(sanitizeName(12345), 'Game')
	assert.equal(sanitizeName('x'.repeat(100)).length, LIMITS.NAME_MAX)
})

test('validateAnnounce rejects bad version and oid', () => {
	assert.ok(validateAnnounce({ ...VALID, version: '1.2' }).errors.length)
	assert.ok(validateAnnounce({ ...VALID, version: 'nope' }).errors.length)
	assert.ok(validateAnnounce({ ...VALID, host_oid: 'has space' }).errors.length)
	assert.ok(validateAnnounce({ ...VALID, host_oid: '' }).errors.length)
	assert.equal(validateAnnounce(VALID).errors.length, 0)
})

test('validateAnnounce clamps max_players and defaults missing', () => {
	assert.equal(validateAnnounce({ ...VALID, max_players: 99 }).value.max_players, 4)
	assert.equal(validateAnnounce({ ...VALID, max_players: 1 }).value.max_players, 2)
	assert.equal(validateAnnounce({ ...VALID, max_players: undefined }).value.max_players, 4)
})

test('announce returns room_id + secret token and lists for same version', () => {
	const reg = new LobbyRegistry()
	const { value } = validateAnnounce(VALID)
	const res = reg.announce(value, '1.1.1.1')
	assert.ok(res.room_id)
	assert.ok(res.token)
	const { rooms } = reg.list('0.9.0')
	assert.equal(rooms.length, 1)
	assert.equal(rooms[0].host_oid, 'abc123')
	// token + ip must never leak in the public view
	assert.equal(rooms[0].token, undefined)
	assert.equal(rooms[0].ip, undefined)
})

test('list version-gates and counts other versions', () => {
	const reg = new LobbyRegistry()
	reg.announce(validateAnnounce(VALID).value, 'a')
	reg.announce(validateAnnounce({ ...VALID, version: '0.8.0' }).value, 'b')
	const r = reg.list('0.9.0')
	assert.equal(r.rooms.length, 1)
	assert.equal(r.other_versions, 1)
})

test('list hides full and in-progress rooms', () => {
	const reg = new LobbyRegistry()
	const full = reg.announce(validateAnnounce({ ...VALID, max_players: 2 }).value, 'a')
	reg.heartbeat(full.room_id, full.token, { players: 2 }) // now full
	const started = reg.announce(validateAnnounce(VALID).value, 'b')
	reg.heartbeat(started.room_id, started.token, { in_progress: true })
	assert.equal(reg.list('0.9.0').rooms.length, 0)
})

test('heartbeat requires the right token', () => {
	const reg = new LobbyRegistry()
	const { room_id } = reg.announce(validateAnnounce(VALID).value, 'a')
	assert.ok(reg.heartbeat(room_id, 'wrong', { players: 2 }).error)
	assert.ok(reg.heartbeat('nope', 'tok').error)
})

test('withdraw is idempotent and token-guarded', () => {
	const reg = new LobbyRegistry()
	const { room_id, token } = reg.announce(validateAnnounce(VALID).value, 'a')
	assert.ok(reg.withdraw(room_id, 'wrong').error)
	assert.equal(reg.withdraw(room_id, token).ok, true)
	assert.equal(reg.withdraw(room_id, token).ok, true) // already gone -> no-op
	assert.equal(reg.size, 0)
})

test('evict drops rooms past TTL (injected clock)', () => {
	let t = 1000
	const reg = new LobbyRegistry({ now: () => t, ttlMs: 5000 })
	reg.announce(validateAnnounce(VALID).value, 'a')
	assert.equal(reg.list('0.9.0').rooms.length, 1)
	t += 6000 // past TTL with no heartbeat
	assert.equal(reg.list('0.9.0').rooms.length, 0)
	assert.equal(reg.size, 0)
})

test('per-host room cap is enforced', () => {
	const reg = new LobbyRegistry()
	for (let i = 0; i < LIMITS.MAX_ROOMS_PER_IP; i++)
		assert.ok(reg.announce(validateAnnounce(VALID).value, 'same-ip').room_id)
	assert.ok(reg.announce(validateAnnounce(VALID).value, 'same-ip').error)
	// a different host is unaffected
	assert.ok(reg.announce(validateAnnounce(VALID).value, 'other-ip').room_id)
})
