class_name RunSave
extends RefCounted
## The host's building run, saved at every checkpoint past B4's start so a group can stop and pick
## it up another day (the user: "save the last checkpoint reached so the host can pick up the run
## there"). One run per machine: the building's seed (the same layout), the checkpoint, and the
## layoffs and clock so far. A finished run clears it; a new run only replaces it once it reaches a
## checkpoint of its own, so starting one by mistake doesn't throw the old run away.

const VERSION: int = 1
static var path: String = "user://run_save.cfg"  # tests point it somewhere else


## {seed, checkpoint, wipes, seconds, saved_unix} or {} when there's nothing to continue.
static func load_run() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("run", "version", 0)) != VERSION:
		return {}
	var index := int(cfg.get_value("run", "checkpoint", 0))
	if index < 1:
		return {}
	return {
		"seed": int(cfg.get_value("run", "seed", YellowRooms.DEFAULT_SEED)),
		"checkpoint": index,
		"wipes": int(cfg.get_value("run", "wipes", 0)),
		"seconds": float(cfg.get_value("run", "seconds", 0.0)),
		"saved_unix": int(cfg.get_value("run", "saved_unix", 0)),
	}


static func save_run(seed_value: int, checkpoint: int, wipes: int, seconds: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "version", VERSION)
	cfg.set_value("run", "seed", seed_value)
	cfg.set_value("run", "checkpoint", checkpoint)
	cfg.set_value("run", "wipes", wipes)
	cfg.set_value("run", "seconds", seconds)
	cfg.set_value("run", "saved_unix", int(Time.get_unix_time_from_system()))
	cfg.save(path)


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Where checkpoint `index` of the building is, for the title: "Level 2, the Kitchen".
static func place(index: int) -> String:
	if index < YellowRooms.FLOORS:
		return "Level 1, %s" % YellowRooms.FLOOR_NAMES[maxi(index, 0)]
	var p := index - YellowRooms.FLOORS
	if p < Pizzeria.FLOORS:
		return "Level 2, the %s" % Pizzeria.FLOOR_NAMES[p].capitalize()
	var r := p - Pizzeria.FLOORS
	if r == 0:
		return "Level 3, the roof"
	if r <= HordeArena.CHECKPOINT_ROOFS.size():
		return "Level 3, roof %d" % HordeArena.CHECKPOINT_ROOFS[r - 1]
	if r == HordeArena.CHECKPOINT_ROOFS.size() + 1:
		return "Level 3, the helipad"
	return "Level 4, Ashgrave Manor"


## "2 hours ago", "yesterday", for the title.
static func age(saved_unix: int) -> String:
	var s := maxi(0, int(Time.get_unix_time_from_system()) - saved_unix)
	if s < 90:
		return "just now"
	if s < 3600:
		return "%d minutes ago" % (s / 60)
	if s < 7200:
		return "an hour ago"
	if s < 86400:
		return "%d hours ago" % (s / 3600)
	if s < 172800:
		return "yesterday"
	return "%d days ago" % (s / 86400)
