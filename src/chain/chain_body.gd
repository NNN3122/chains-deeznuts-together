class_name ChainBody
extends CharacterBody3D
## Anything the Line can be fastened to: players, and the Ballast in solo play.
## Simulated on the server; clients interpolate synced_position.

const LAYER_WORLD: int = 1
const LAYER_BODIES: int = 2
const LAYER_THROWN: int = 4
const LAYER_MONSTER: int = 8
const NET_LERP_SPEED: float = 18.0
const NET_SNAP_DISTANCE: float = 4.0

var join_index: int = 0  # chain order; the Ballast uses a large index so it is always last
var synced_position: Vector3 = Vector3.ZERO
var external_velocity: Vector3 = Vector3.ZERO  # added once on the next tick (blasts, items)
var dragged_this_tick: float = 0.0  # meters the chain moved this body this tick (scrape noise)


func _setup_body_layers() -> void:
	collision_layer = LAYER_BODIES
	collision_mask = LAYER_WORLD | LAYER_BODIES


## Height of the cuff above the feet.
func anchor_height() -> float:
	return 0.92


func chain_anchor() -> Vector3:
	return global_position + Vector3(0.0, anchor_height(), 0.0)


## How much this body yields to a chain pull: 0 = immovable, 1 = fully dragged.
func chain_weight() -> float:
	return 1.0 if not is_on_floor() else 0.35


func is_bracing() -> bool:
	return false


## How hard this body holds a grabbed teammate down (the Custodian only lifts).
func resist_value() -> float:
	return 1.0 if is_on_floor() else 0.0


## How hard this body drags a partner toward a ledge when it dangles (1 = a person).
func hang_mass() -> float:
	return 1.0


## 0..100: how loud this body is right now (the Custodian hunts by sound).
func noise_level() -> float:
	return 0.0


## Move with collision, sliding along surfaces, so a pull drags you along floors and up walls.
func chain_move(motion: Vector3) -> void:
	var start := global_position
	var remaining := motion
	for i in 3:
		var col := move_and_collide(remaining)
		if col == null:
			break
		remaining = col.get_remainder().slide(col.get_normal())
		if remaining.length_squared() < 0.000001:
			break
	dragged_this_tick += global_position.distance_to(start)


func apply_knockback(v: Vector3) -> void:
	external_velocity += v


func teleport_to(pos: Vector3, _yaw: float) -> void:
	global_position = pos
	synced_position = pos
	velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO


func client_interpolate(delta: float) -> void:
	if global_position.distance_to(synced_position) > NET_SNAP_DISTANCE:
		global_position = synced_position
	else:
		global_position = global_position.lerp(synced_position, clampf(NET_LERP_SPEED * delta, 0.0, 1.0))
