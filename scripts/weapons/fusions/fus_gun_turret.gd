# --- turret + every other weapon: deployed sentry variants --------------------
# bolt + turret: instead of a couple of sustained sentries, throw down a swarm
# of short-lived gatling nests that are constantly being redeployed
class_name FusGunTurret
extends FusSentryBase

func _init() -> void:
	weapon_id = "fus_gunturret"
	display_name = "Gatling Nest"
	mode = "bolt"
	dmg_base = 1.5
	life_scale = 0.4
	cooldown_scale = 0.3
func _deploy_cap() -> int:
	return count_level() + 4
