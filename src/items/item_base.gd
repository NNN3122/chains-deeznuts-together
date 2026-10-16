class_name ItemBase
extends Node
## Server-side logic of a held item. One instance lives under the holding Player node and is
## ticked by the player every physics frame with the holder's "use" input. Subclasses override
## _tick(delta, held, pressed); "pressed" is true on the tick the button went down, or when a
## tap counter arrived (so a quick tap over a lossy link still counts).

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


## Another slot was picked: anything "on" (flashlight, jetpack) goes off.
func on_deselect() -> void:
	is_active = false
	_was_held = false


func on_select() -> void:
	pass


func server_tick(delta: float, use_held: bool, tapped: bool, reload_tapped: bool) -> void:
	if holder == null:
		return
	var pressed := (use_held and not _was_held) or tapped
	_was_held = use_held
	if reload_tapped:
		_reload()
	_tick(delta, use_held, pressed)


func _tick(_delta: float, _held: bool, _pressed: bool) -> void:
	pass


func _reload() -> void:
	pass


## 0..1 for the HUD bar (fuel, ammo, battery...).
func charge() -> float:
	return 1.0


## "8 / 24" for guns; empty for everything else.
func ammo_text() -> String:
	return ""


## What a dropped pickup remembers (ammo counts), restored by restore_state().
func carry_state() -> Dictionary:
	return {}


func restore_state(_state: Dictionary) -> void:
	pass


## Uses the item up (drinks, throwables).
func consume() -> void:
	if holder != null:
		holder.server_drop_item(false)


func fx() -> Effects:
	return Effects.find(holder)
