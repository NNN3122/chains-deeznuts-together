class_name HuntGrounds
extends Node3D
## What a ground-walking hunter (HollowHire and its kin) needs from the level it hunts in: a grid
## of cells it walks between (centre to centre, it never collides with anything), routes over that
## grid, the cells it patrols, and where it won't follow you. YellowRooms (the office maze, one grid
## per floor) and Manor (the estate's grounds, one grid) implement it. Every method here is a
## neutral default; the levels override them.


## The middle of cell c on floor i, at floor height.
func cell_center(_i: int, _c: Vector2i) -> Vector3:
	return Vector3.ZERO


## The cell a position is in (clamped to the grid).
func cell_of(_p: Vector3) -> Vector2i:
	return Vector2i.ZERO


## Cells to walk from one to another, both ends included; empty when there is no way.
func route(_i: int, _from: Vector2i, _to: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	return none


## Where a hunter on floor i likes to walk.
func patrol_cells(_i: int) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	return none


## A cell it never goes into (a Break Room).
func is_safe_cell(_i: int, _c: Vector2i) -> bool:
	return false


## A position where it won't take you (a Break Room, inside the freight car).
func is_safe_spot(_p: Vector3) -> bool:
	return false


## Server: a hunter saw someone and screamed; the level decides who answers.
func hire_callout(_caller: HollowHire, _target: Player) -> void:
	pass


## Any cell of the grid, for a wander with nowhere better to go.
func random_cell(_rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i.ZERO
