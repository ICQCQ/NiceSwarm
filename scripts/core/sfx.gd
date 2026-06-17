extends Node
## Procedural sound effects — every sound is synthesized at startup, no asset
## files. Autoloaded as `Sfx`. play() is throttled per sound name so rapid-tick
## weapons don't stack into noise.

const SR := 22050
const POOL_2D := 20
const POOL_FLAT := 8

# wave types for _synth
const W_SINE := 0
const W_SQUARE := 1
const W_SAW := 2
const W_TRI := 3

var sounds := {}
var throttle := {
	"orbit": 0.09, "laser": 0.08, "flame": 0.12, "gem": 0.06, "kill": 0.05,
	"venom": 0.25, "bolt": 0.05, "turret": 0.06, "frost": 0.08, "boom": 0.06,
}
var last_play := {}
var pool_2d: Array = []
var pool_flat: Array = []
var idx_2d := 0
var idx_flat := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_2D:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1400.0
		add_child(p)
		pool_2d.append(p)
	for i in POOL_FLAT:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool_flat.append(p)
	_make_sounds()


func play(sname: String, pos: Variant = null, vol_db := 0.0) -> void:
	if not sounds.has(sname):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_play.get(sname, -10.0) < throttle.get(sname, 0.03):
		return
	last_play[sname] = now
	if pos != null:
		var p: AudioStreamPlayer2D = pool_2d[idx_2d]
		idx_2d = (idx_2d + 1) % pool_2d.size()
		p.global_position = pos
		p.stream = sounds[sname]
		p.volume_db = vol_db
		p.play()
	else:
		var q: AudioStreamPlayer = pool_flat[idx_flat]
		idx_flat = (idx_flat + 1) % pool_flat.size()
		q.stream = sounds[sname]
		q.volume_db = vol_db
		q.play()


func _make_sounds() -> void:
	# one distinct voice per weapon
	_synth("bolt", 0.07, 900.0, 480.0, W_SQUARE, 0.0, 0.005, 0.5)       # pew
	_synth("orbit", 0.05, 1500.0, 950.0, W_TRI, 0.0, 0.002, 0.45)       # metallic ting
	_synth("nova", 0.35, 150.0, 55.0, W_SINE, 0.2, 0.01, 0.9)           # deep pulse
	_synth("glaive", 0.14, 360.0, 230.0, W_SAW, 0.1, 0.01, 0.5)         # whirr
	_synth("lightning", 0.13, 1200.0, 300.0, W_SINE, 0.9, 0.002, 0.7)   # crackle zap
	_synth("flame", 0.09, 420.0, 180.0, W_SINE, 0.85, 0.02, 0.35)       # fire puff
	_synth("mine", 0.05, 750.0, 700.0, W_SQUARE, 0.0, 0.002, 0.4)       # arm click
	_synth("missile", 0.18, 650.0, 200.0, W_SINE, 0.6, 0.02, 0.5)       # launch fshh
	_synth("laser", 0.05, 1900.0, 1750.0, W_SINE, 0.0, 0.002, 0.3)      # beam tick
	_synth("frost", 0.12, 1100.0, 2100.0, W_TRI, 0.1, 0.005, 0.45)      # icy shimmer
	_synth("gravity", 0.38, 95.0, 55.0, W_SINE, 0.05, 0.05, 0.8)        # wub
	_synth("turret_deploy", 0.09, 320.0, 190.0, W_SQUARE, 0.1, 0.005, 0.5)
	_synth("turret", 0.06, 700.0, 380.0, W_SQUARE, 0.0, 0.003, 0.35)    # smaller pew
	_synth("venom", 0.1, 230.0, 85.0, W_SINE, 0.2, 0.01, 0.5)           # blub
	# world / UI
	_synth("boom", 0.4, 130.0, 42.0, W_SINE, 0.35, 0.005, 0.95)         # explosions
	_synth("bomb", 0.55, 100.0, 36.0, W_SINE, 0.4, 0.005, 1.0)          # screen bomb
	_synth("kill", 0.08, 520.0, 140.0, W_SINE, 0.5, 0.003, 0.55)        # enemy pop
	_synth("hurt", 0.2, 300.0, 110.0, W_SAW, 0.15, 0.005, 0.7)          # player hit
	_synth("dash", 0.12, 950.0, 280.0, W_SINE, 0.7, 0.01, 0.45)         # swish
	_synth("gem", 0.05, 1150.0, 1600.0, W_SINE, 0.0, 0.003, 0.35)       # pickup blip
	_synth("chest", 0.22, 660.0, 1320.0, W_SINE, 0.0, 0.01, 0.6)        # treasure
	_synth("levelup", 0.3, 520.0, 1040.0, W_SINE, 0.0, 0.02, 0.6)       # chime up
	_synth("merge", 0.45, 330.0, 1320.0, W_SAW, 0.1, 0.03, 0.6)         # power surge
	_synth("revive", 0.3, 400.0, 820.0, W_TRI, 0.0, 0.02, 0.6)
	_synth("click", 0.03, 820.0, 820.0, W_SQUARE, 0.0, 0.002, 0.35)
	_synth("clock", 0.06, 1500.0, 760.0, W_TRI, 0.0, 0.001, 0.55)       # resume-countdown tick
	_synth("alert", 0.2, 760.0, 1320.0, W_SQUARE, 0.0, 0.004, 0.65)     # game-resume alert
	_synth("telegraph", 0.22, 300.0, 620.0, W_SQUARE, 0.1, 0.01, 0.5)  # bombardier warning
	# Sustained foghorn note timed to the 5-second final-stage banner.
	# SINE + zero noise = clean resonant tone; 0.8 s attack = ominous swell;
	# decay_exp=0.4 holds the note through the banner; release=0.5 fades it
	# to true silence so the stream end doesn't click.
	_synth("final_stage", 5.0, 87.0, 87.0, W_SINE, 0.0, 0.8, 0.95, 0.4, 0.5)


## Renders one short sound: exponential pitch sweep f0->f1, optional noise mix,
## linear attack then power-curve decay envelope.
## decay_exp: exponent of pow(1-t, e) — lower = longer sustain (0.5 ≈ sqrt, 1.5 = default fast).
## release: seconds of linear fade-to-silence baked at the tail; prevents the hard
##          cut when AudioStreamWAV reaches its end with non-zero amplitude.
func _synth(sname: String, dur: float, f0: float, f1: float, wave: int,
		noise_mix: float, attack: float, vol: float,
		decay_exp: float = 1.5, release: float = 0.0) -> void:
	var n := int(dur * SR)
	var rel_samples := int(release * SR)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq := f0 * pow(f1 / f0, t)
		phase += freq / SR
		var s: float
		match wave:
			W_SQUARE:
				s = signf(sin(phase * TAU)) * 0.7
			W_SAW:
				s = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.8
			W_TRI:
				s = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
			_:
				s = sin(phase * TAU)
		if noise_mix > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise_mix)
		var env := minf(t / maxf(attack / maxf(dur, 0.001), 0.001), 1.0) * pow(1.0 - t, decay_exp)
		if rel_samples > 0 and i >= n - rel_samples:
			env *= float(n - i) / float(rel_samples)
		bytes.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SR
	stream.data = bytes
	sounds[sname] = stream
