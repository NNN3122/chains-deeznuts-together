extends ItemBase
## Shared logic for thrown items (Squeaky Dennis decoy, Deez Charge bomb): F throws it in an arc
## where you're looking. The thrown object's behavior lives in Thrown.

const THROW_SPEED: float = 11.0


func _tick(_delta: float, _held: bool, pressed: bool) -> void:
	if not pressed:
		return
	var dir := holder.aim_direction()
	var vel := dir * THROW_SPEED + Vector3.UP * 3.5 + Vector3(holder.velocity.x, 0.0, holder.velocity.z) * 0.5
	var kind := "bomb" if data.id == "bomb" else "decoy"
	Net.spawn_thrown(kind, holder.eye_position() + dir * 0.6, vel, holder.peer_id)
	consume()
