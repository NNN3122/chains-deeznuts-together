class_name Groundskeeper
extends HollowHire
## Level 4's hunter: the Groundskeeper of Ashgrave Manor (GroundskeeperBody). It hunts exactly like
## a Hollow Hire (sight, the chase, the four attacks, the catch, the stun, the rescues), walking the
## Manor's grid of the grounds instead of the office's rooms. What makes it the machines' warden
## lives in Manor: it patrols the unfinished machines, is drawn to whichever one is being worked on,
## and kicks a half-repaired machine it passes so it runs back down.


func _make_body() -> HireBody:
	return GroundskeeperBody.new()


func _ready() -> void:
	super()
	add_to_group("groundskeeper")


## Straight at you only when nothing on the grid is in the way either: a raycast at chest height
## sails over the headstones and ledgers it would otherwise walk through.
func _has_clear_floor_line(target: Vector3) -> bool:
	if not super._has_clear_floor_line(target):
		return false
	var manor := level as Manor
	return manor == null or manor.clear_walk(global_position, target)
