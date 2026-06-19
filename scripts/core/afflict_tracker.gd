class_name AfflictTracker
extends RefCounted
## Tracks named, timed status afflictions on a single enemy or player. Each afflict
## is independent and keyed by id; applying the same id while one is already active
## only replaces it if the new duration is longer than what's left — so when several
## players/instances inflict the same affliction, the longest-remaining application
## always wins outright (its mods AND its duration move together, never just one).
##
## `mods` is a generic key -> multiplier map read by the target: enemies use DMG_*
## (int) keys for affinity-style lookups (`mult(dtype)`), players use named String
## keys for their own effects (`mult("speed")`, etc). Int and String keys never
## collide, so either kind can ride the same tracker. `color` drives a generic UI
## ring for afflicts that don't already have a bespoke draw of their own.

class Affliction:
	var time_left: float
	var mods: Dictionary
	var color: Color
	func _init(duration: float, m: Dictionary, c: Color) -> void:
		time_left = duration
		mods = m
		color = c


var active: Dictionary = {}  # String id -> Affliction


func apply(id: String, duration: float, mods: Dictionary = {}, color: Color = Color.WHITE) -> void:
	var cur: Affliction = active.get(id)
	if cur != null and cur.time_left >= duration:
		return  # an existing, longer-remaining application wins — the weaker one is dropped
	active[id] = Affliction.new(duration, mods, color)


func tick(delta: float) -> void:
	var dead: Array = []
	for id in active:
		var a: Affliction = active[id]
		a.time_left -= delta
		if a.time_left <= 0.0:
			dead.append(id)
	for id in dead:
		active.erase(id)


func has(id: String) -> bool:
	return active.has(id)


## Ends `id` immediately, regardless of time left — e.g. a cleanse effect.
func remove(id: String) -> void:
	active.erase(id)


func is_empty() -> bool:
	return active.is_empty()


## Product of every active affliction's modifier for `key` (default 1.0 each) —
## layered multiplicatively on top of the target's own base state, never replacing it.
func mult(key: Variant) -> float:
	var m := 1.0
	for id in active:
		m *= (active[id] as Affliction).mods.get(key, 1.0)
	return m
