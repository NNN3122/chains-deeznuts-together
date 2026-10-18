extends Node
## Autoload "GameState": shared run state (checkpoint, objective, layoffs, escape, stats) plus the
## input map. Host-authoritative: only the server changes state, pushing every change to clients
## with call_local RPCs so the host sees exactly what everyone else sees.

signal message_posted(text: String, seconds: float)
signal escaped_changed(escaped: bool)
signal checkpoint_changed(index: int)
signal objective_changed(text: String)
signal layoff_started(count: int, reason: String)
signal tasks_changed

enum ChainConfig { LINE, RING, PAIRS }

## The current floor's task list under the objective: [[text, done], ...]. Server-owned,
## pushed to everyone (and to late joiners with the rest of the state).
var tasks: Array = []
var _tips_shown: Dictionary = {}  # server: tip keys already shown this run

var chain_config: ChainConfig = ChainConfig.LINE
var checkpoint_index: int = 0
var checkpoint_position: Vector3 = Vector3.ZERO
var checkpoint_facing: float = 0.0
var spawn_position: Vector3 = Vector3.ZERO
var objective: String = ""
var escaped: bool = false
var wipes: int = 0
var run_seconds: float = 0.0
var final_time: float = 0.0
var final_jerks: int = 0
var escape_line: String = ""  # the end screen's line about how the run ended
var ui_blocking: bool = false  # local: a menu is open, so the game ignores your input


func _ready() -> void:
	_setup_input_map()


func _process(delta: float) -> void:
	if not escaped and get_tree().get_first_node_in_group("level") != null:
		run_seconds += delta


## Called on every peer when a world is built, before any network traffic.
func reset_run(spawn: Vector3, facing: float, first_objective: String) -> void:
	spawn_position = spawn
	checkpoint_index = 0
	checkpoint_position = spawn
	checkpoint_facing = facing
	objective = first_objective
	escaped = false
	wipes = 0
	run_seconds = 0.0
	final_time = 0.0
	final_jerks = 0
	escape_line = ""
	tasks = []
	_tips_shown.clear()
	objective_changed.emit(objective)
	tasks_changed.emit()


## Server only. A fresh task list for the current stretch of the building.
func set_tasks(texts: PackedStringArray) -> void:
	if not multiplayer.is_server():
		return
	_rpc_tasks.rpc(texts, 0)


## Server only. Ticks a task off (once) and tells everyone.
func complete_task(i: int) -> void:
	if not multiplayer.is_server() or i < 0 or i >= tasks.size() or bool(tasks[i][1]):
		return
	_rpc_task_done.rpc(i)



## Server only. Rewords a task (a running count) without touching its done flag.
func set_task_text(i: int, text: String) -> void:
	if not multiplayer.is_server() or i < 0 or i >= tasks.size():
		return
	_rpc_task_text.rpc(i, text)


@rpc("authority", "call_local", "reliable")
func _rpc_task_text(i: int, text: String) -> void:
	if i < 0 or i >= tasks.size():
		return
	tasks[i][0] = text
	tasks_changed.emit()

func task_done(i: int) -> bool:
	return i >= 0 and i < tasks.size() and bool(tasks[i][1])


func all_tasks_done() -> bool:
	for t in tasks:
		if not bool(t[1]):
			return false
	return not tasks.is_empty()


@rpc("authority", "call_local", "reliable")
func _rpc_tasks(texts: PackedStringArray, done_mask: int) -> void:
	tasks = []
	for i in texts.size():
		tasks.append([texts[i], (done_mask >> i) & 1 == 1])
	tasks_changed.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_task_done(i: int) -> void:
	if i < 0 or i >= tasks.size():
		return
	tasks[i][1] = true
	tasks_changed.emit()
	post_message_local("DONE: %s" % String(tasks[i][0]), 3.5)


func _task_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for t in tasks:
		out.append(String(t[0]))
	return out


func _task_mask() -> int:
	var m := 0
	for i in tasks.size():
		if bool(tasks[i][1]):
			m |= 1 << i
	return m


## Server only. Records a newer checkpoint and tells everyone.
func set_checkpoint(index: int, position: Vector3, facing: float, new_objective: String) -> void:
	if not multiplayer.is_server() or index <= checkpoint_index:
		return
	_rpc_checkpoint.rpc(index, position, facing, new_objective)


@rpc("authority", "call_local", "reliable")
func _rpc_checkpoint(index: int, position: Vector3, facing: float, new_objective: String) -> void:
	checkpoint_index = index
	checkpoint_position = position
	checkpoint_facing = facing
	objective = new_objective
	checkpoint_changed.emit(index)
	objective_changed.emit(objective)
	post_message_local("CLOCKED IN. Checkpoint saved.", 3.0)


## Server: an instruction shown once per run (the first grab by each monster, say). After that
## the moment plays without words on the screen: text mid-scare kills the fear.
func post_tip(key: String, text: String, seconds: float = 3.0) -> void:
	if not multiplayer.is_server() or _tips_shown.has(key):
		return
	_tips_shown[key] = true
	post_message(text, seconds)


func post_message(text: String, seconds: float = 3.0) -> void:
	if not multiplayer.is_server():
		return
	_rpc_message.rpc(text, seconds)


@rpc("authority", "call_local", "reliable")
func _rpc_message(text: String, seconds: float) -> void:
	post_message_local(text, seconds)


func post_message_local(text: String, seconds: float = 3.0) -> void:
	message_posted.emit(text, seconds)


## Server only. Everyone is sent back to the last checkpoint (the level does the teleport).
func layoff(reason: String) -> void:
	if not multiplayer.is_server():
		return
	_rpc_layoff.rpc(wipes + 1, reason)


@rpc("authority", "call_local", "reliable")
func _rpc_layoff(total: int, reason: String) -> void:
	wipes = total
	layoff_started.emit(total, reason)


## Any peer: ask the host to bring the group back to the last checkpoint (pause menu "Stuck?").
func request_regroup(requester: String) -> void:
	if multiplayer.is_server():
		_do_regroup(requester)
	else:
		_rpc_request_regroup.rpc_id(1, requester)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_regroup(requester: String) -> void:
	if multiplayer.is_server():
		_do_regroup(requester.left(24))


func _do_regroup(requester: String) -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("regroup"):
		level.call("regroup", requester)
		for p in Net.get_players():
			p.set_unchained(false)  # back at the checkpoint, everyone is on the Line


## Server only. Everyone made it into the elevator.
## line: what the end screen says about how you got out.
func set_escaped(line: String = "") -> void:
	if not multiplayer.is_server() or escaped:
		return
	var chain := get_tree().get_first_node_in_group("chain")
	var jerks: int = chain.get("jerks") if chain != null else 0
	_rpc_escaped.rpc(run_seconds, jerks, line)


@rpc("authority", "call_local", "reliable")
func _rpc_escaped(time: float, jerks: int, line: String) -> void:
	escaped = true
	final_time = time
	final_jerks = jerks
	escape_line = line
	escaped_changed.emit(true)


## Server only. Lets a late joiner catch up.
func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_full_state.rpc_id(peer_id, checkpoint_index, checkpoint_position, checkpoint_facing, objective, escaped, wipes, run_seconds)
	_rpc_tasks.rpc_id(peer_id, _task_texts(), _task_mask())


@rpc("authority", "call_remote", "reliable")
func _rpc_full_state(index: int, position: Vector3, facing: float, obj: String, is_escaped: bool, total_wipes: int, seconds: float) -> void:
	checkpoint_index = index
	checkpoint_position = position
	checkpoint_facing = facing
	objective = obj
	wipes = total_wipes
	run_seconds = seconds
	objective_changed.emit(objective)
	if is_escaped and not escaped:
		escaped = true
		escaped_changed.emit(true)


# --- Input map -------------------------------------------------------------------------------

func _setup_input_map() -> void:
	_add_keys("move_forward", [KEY_W])
	_add_keys("move_back", [KEY_S])
	_add_keys("move_left", [KEY_A])
	_add_keys("move_right", [KEY_D])
	_add_keys("walk_forward_alt", [KEY_UP])
	_add_keys("walk_back_alt", [KEY_DOWN])
	_add_keys("turn_left", [KEY_LEFT, KEY_Q])
	_add_keys("turn_right", [KEY_RIGHT, KEY_E])
	_add_keys("look_up", [KEY_PAGEUP])
	_add_keys("look_down", [KEY_PAGEDOWN])
	_add_keys("jump", [KEY_SPACE])
	_add_keys("run", [KEY_SHIFT])
	_add_keys("brace", [KEY_CTRL, KEY_C])
	_add_keys("use_item", [KEY_F])
	_add_keys("drop_item", [KEY_G])
	_add_keys("reload", [KEY_T])
	_add_keys("slot_1", [KEY_1])
	_add_keys("slot_2", [KEY_2])
	_add_keys("slot_3", [KEY_3])
	_add_keys("slot_4", [KEY_4])
	_add_keys("toggle_camera", [KEY_V])
	_add_keys("auto_run", [KEY_R])
	_add_keys("help", [KEY_H, KEY_F1])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])


func _add_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	# Bound by physical position (WASD on any layout) AND by key label, because remote-desktop
	# tools can inject keys without scancodes, which physical bindings miss.
	for k in keys:
		var physical := InputEventKey.new()
		physical.physical_keycode = k
		InputMap.action_add_event(action, physical)
		var logical := InputEventKey.new()
		logical.keycode = k
		InputMap.action_add_event(action, logical)
