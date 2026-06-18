class_name NetInterp
extends RefCounted
## Time-based snapshot interpolation for network puppets. Buffers recent
## (timestamp_ms, position) samples and renders slightly in the past, lerping
## between the two snapshots that bracket render_time = now - delay. Looks smoother
## than a fixed-weight chase at low send rates, because we always interpolate
## between two real known positions instead of chasing a moving target.
##
## Opt-in per client via GameSettings.net_interpolation (a render choice, not synced).
## Timestamps are client-receive time (Time.get_ticks_msec), so no host/client clock
## sync is needed — the delay buffer absorbs network jitter. The local player is
## never interpolated (it stays 60 Hz simulated).

const MAX_SNAPS := 8
const PLAYER_DELAY_MS := 100.0   # remote players (~20 Hz, 50 ms spacing) → ~2 snapshots
const ENEMY_DELAY_MS := 160.0    # enemy puppets (~12 Hz, 83 ms spacing) → ~2 snapshots
const TELEPORT_DIST := 400.0     # jumps beyond this snap (reset buffer) instead of sliding across

var _ts := PackedFloat64Array()  # sample timestamps (ms), monotonic
var _ps := PackedVector2Array()  # sample positions, parallel to _ts
var _last := Vector2.ZERO
var _has := false


## Record a freshly-received position. A large jump from the last sample is treated
## as a teleport: clear the buffer so we snap to the new spot rather than slide.
func push(now_ms: float, pos: Vector2) -> void:
	if _has and pos.distance_to(_last) > TELEPORT_DIST:
		_ts.clear()
		_ps.clear()
	_ts.append(now_ms)
	_ps.append(pos)
	_last = pos
	_has = true
	while _ts.size() > MAX_SNAPS:
		_ts.remove_at(0)
		_ps.remove_at(0)


## Position to render at render_time = now_ms - delay_ms. Holds the oldest sample
## until the buffer covers the delay (startup), and holds the newest on underrun
## (e.g. a stationary enemy that stopped sending under delta compression).
func sample(now_ms: float, delay_ms: float) -> Vector2:
	var n := _ts.size()
	if n == 0:
		return _last
	var rt := now_ms - delay_ms
	if rt <= _ts[0]:
		return _ps[0]
	if rt >= _ts[n - 1]:
		return _ps[n - 1]
	for i in range(n - 1):
		if rt <= _ts[i + 1]:
			var span: float = _ts[i + 1] - _ts[i]
			var u: float = 0.0 if span <= 0.0 else (rt - _ts[i]) / span
			return _ps[i].lerp(_ps[i + 1], u)
	return _ps[n - 1]
