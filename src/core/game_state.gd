extends Node
## Autoload "GameState": shared run state (checkpoint, objective, layoffs, escape, stats) plus the
## input map. Host-authoritative: only the server changes state, pushing every change to clients
## with call_local RPCs so the host sees exactly what everyone else sees.

signal message_posted(text: String, seconds: float)
signal escaped_changed(escaped: bool)
signal checkpoint_changed(index: int)
signal objective_changed(text: String)
signal layoff_started(count: int, reason: String)

enum ChainConfig { LINE, RING, PAIRS }

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
	objective_changed.emit(objective)


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


## Server only. Everyone made it into the elevator.
func set_escaped() -> void:
	if not multiplayer.is_server() or escaped:
		return
	var chain := get_tree().get_first_node_in_group("chain")
	var jerks: int = chain.get("jerks") if chain != null else 0
	_rpc_escaped.rpc(run_seconds, jerks)


@rpc("authority", "call_local", "reliable")
func _rpc_escaped(time: float, jerks: int) -> void:
	escaped = true
	final_time = time
	final_jerks = jerks
	escaped_changed.emit(true)


## Server only. Lets a late joiner catch up.
func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_full_state.rpc_id(peer_id, checkpoint_index, checkpoint_position, checkpoint_facing, objective, escaped, wipes, run_seconds)


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
