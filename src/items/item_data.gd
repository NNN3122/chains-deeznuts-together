class_name ItemData
extends Resource
## Data definition of an item. One .tres per item in src/items/data/; ItemRegistry finds them all.
## The logic script must extend ItemBase; it is instantiated when a player picks the item up.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: String = "item"
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var rarity: Rarity = Rarity.COMMON
@export var logic_script: GDScript
@export var hud_hint: String = "F to use"


func create_logic() -> ItemBase:
	if logic_script == null:
		push_error("ItemData '%s' has no logic_script" % id)
		return null
	var node: ItemBase = logic_script.new() as ItemBase
	if node == null:
		push_error("ItemData '%s': logic_script does not extend ItemBase" % id)
		return null
	node.setup(self)
	return node
