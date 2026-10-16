extends ItemBase
## Jetpack: hold to thrust. Lifts the whole Line through the chain's pull, wobbles on its own,
## and only refuels while standing on something. Thrust scales with chain size so it can (barely)
## lift everyone; on a slack chain it rockets the holder up until the chain bites.

const THRUST_ACCEL: float = 42.0  # m/s^2 for a solo flyer; must beat gravity (18) with margin
const THRUST_PER_LINK: float = 20.0  # extra m/s^2 per other chained body
const MAX_RISE_SPEED: float = 7.5  # m/s
const FUEL_SECONDS: float = 2.0
const REFUEL_PER_SECOND: float = 0.8
const WOBBLE_STRENGTH: float = 14.0

var fuel: float = FUEL_SECONDS
var _t: float = 0.0
var _noise_t: float = 0.0


func _tick(delta: float, held: bool, _pressed: bool) -> void:
	_t += delta
	var thrusting := held and fuel > 0.0
	is_active = thrusting
	if thrusting:
		fuel = maxf(0.0, fuel - delta)
		holder.ignore_gravity_this_tick = true
		var links := maxi(0, Net.get_chain_bodies().size() - 1)
		var thrust := THRUST_ACCEL + THRUST_PER_LINK * float(links)
		var vy := holder.velocity.y
		var new_vy := vy
		if vy < MAX_RISE_SPEED:
			new_vy = minf(vy + thrust * delta, MAX_RISE_SPEED)
		holder.external_velocity.y += new_vy - vy
		var wobble := Vector3(sin(_t * 7.3) + 0.6 * sin(_t * 13.1), 0.0, cos(_t * 5.7) + 0.5 * sin(_t * 11.3))
		holder.external_velocity += wobble * WOBBLE_STRENGTH * delta
		_noise_t -= delta
		if _noise_t <= 0.0:
			_noise_t = 0.25
			holder.add_noise(12.0)  # it's a jet engine
	elif holder.is_on_floor():
		fuel = minf(FUEL_SECONDS, fuel + REFUEL_PER_SECOND * delta)


func charge() -> float:
	return fuel / FUEL_SECONDS
