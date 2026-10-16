class_name ItemBase
extends Node
## Server-side logic of a held item. One instance lives under the holding Player node and is
## ticked by the player every physics frame with the holder's "use" input. Subclasses override
## _tick(delta, held, pressed); "pressed" is true only on the tick the button went down.

var data: ItemData
var holder: Player
var is_active: bool = false  # replicated through the player's SFLAG_USING_ITEM
var _was_held: bool = false


func setup(item_data: ItemData) -> void:
	data = item_data


func on_equip(player: Player) -> void:
	holder = player


func on_unequip() -> void:
	holder = null
	is_active = false


func server_tick(delta: float, use_held: bool) -> void:
	if holder == null:
		return
	var pressed := use_held and not _was_held
	_was_held = use_held
	_tick(delta, use_held, pressed)
	if holder != null:
		holder.item_charge = charge()


func _tick(_delta: float, _held: bool, _pressed: bool) -> void:
	pass


## 0..1 for the HUD bar (fuel, ammo, battery...).
func charge() -> float:
	return 1.0


## Uses the item up (drinks, throwables).
func consume() -> void:
	if holder != null:
		holder.server_drop_item(false)


func fx() -> Effects:
	return Effects.find(holder)
