class_name ItemRegistry
extends RefCounted
## Finds every ItemData resource in src/items/data/ by itself, so adding an item is one .tres
## plus one logic script and nothing else.

const DATA_DIR: String = "res://src/items/data/"

static var _by_id: Dictionary = {}


static func get_data(id: String) -> ItemData:
	if _by_id.is_empty():
		_scan()
	return _by_id.get(id) as ItemData


static func all_ids() -> Array:
	if _by_id.is_empty():
		_scan()
	return _by_id.keys()


static func _scan() -> void:
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("ItemRegistry: cannot open %s" % DATA_DIR)
		return
	for f in dir.get_files():
		var file := f.trim_suffix(".remap")  # exported builds list resources as *.tres.remap
		if not file.ends_with(".tres"):
			continue
		var res := load(DATA_DIR + file) as ItemData
		if res != null:
			_by_id[res.id] = res
