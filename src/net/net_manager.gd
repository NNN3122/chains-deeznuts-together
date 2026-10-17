extends Node
## Autoload "Net": solo / host / join, spawning players, pickups and thrown objects, and the
## peer lifecycle. Host-authoritative: the server (peer 1) owns and simulates every body; clients
## send input by RPC (see player.gd) and render replicated state.
## Solo uses OfflineMultiplayerPeer: the same server code path, no sockets, no firewall prompt.

signal players_changed
signal connection_failed(reason: String)
signal disconnected_from_game(reason: String)
signal invite_changed
## Client: the host's world is built differently from ours (another seed, or the Loading Lot).
## Main rebuilds the world with this config and joins again.
signal world_mismatch(config: Dictionary)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 6
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const REJECT_GRACE: float = 0.6  # seconds between telling a joiner why and dropping them

var local_name: String = "Player"
var is_solo: bool = false
## How the world is built: {"seed": int, "arena": bool, "horde": int}. The host picks it; every
## peer must build the same, so a joiner whose config differs is told the host's and rebuilds.
var world_config: Dictionary = default_world_config()
## What the host shows friends: {"state": "opening" | "ready" | "failed" | "off", "code",
## "lan", "tailscale", "port", "reason"}. Empty when not hosting.
var invite: Dictionary = {}
var port_opener: PortOpener
var _build_id: String = ""
var players_root: Node3D
var spawner: MultiplayerSpawner
var pickups_root: Node3D
var pickup_spawner: MultiplayerSpawner
var thrown_root: Node3D
var thrown_spawner: MultiplayerSpawner
var ballast: Ballast
var _next_join_index: int = 0
var _spawn_counter: int = 0
var _registered: Dictionary = {}


static func default_world_config() -> Dictionary:
	return {"seed": YellowRooms.DEFAULT_SEED, "arena": false, "horde": HordeArena.HORDE_COUNT}


## A fresh building every run: a random seed (the tests pass --seed for a fixed one).
static func random_world_config(arena: bool) -> Dictionary:
	var cfg := default_world_config()
	cfg["seed"] = randi() % 900000 + 1000
	cfg["arena"] = arena
	return cfg


static func same_world(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("seed", 0)) == int(b.get("seed", 0)) and bool(a.get("arena", false)) == bool(b.get("arena", false)) and int(a.get("horde", 0)) == int(b.get("horde", 0))


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	port_opener = PortOpener.new()
	port_opener.name = "PortOpener"
	add_child(port_opener)
	port_opener.finished.connect(_on_port_opened)


func bind_world(world: Node3D) -> void:
	players_root = world.get_node("Players")
	spawner = world.get_node("PlayerSpawner")
	pickups_root = world.get_node("Pickups")
	pickup_spawner = world.get_node("PickupSpawner")
	thrown_root = world.get_node("Thrown")
	thrown_spawner = world.get_node("ThrownSpawner")
	ballast = world.get_node("Ballast")
	_next_join_index = 0
	_spawn_counter = 0
	_registered.clear()


func unbind_world() -> void:
	players_root = null
	spawner = null
	pickups_root = null
	pickup_spawner = null
	thrown_root = null
	thrown_spawner = null
	ballast = null


func start_solo(player_name: String) -> Error:
	local_name = player_name
	is_solo = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_spawn_player_for(1, player_name)
	return OK


func host(port: int, player_name: String) -> Error:
	local_name = player_name
	is_solo = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_spawn_player_for(1, player_name)
	_begin_invite(port)
	return OK


func join(ip: String, port: int, player_name: String) -> Error:
	local_name = player_name
	is_solo = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_registered.clear()
	is_solo = false
	Voice.reset()
	port_opener.close()
	if not invite.is_empty():
		invite = {}
		invite_changed.emit()


# --- Invites --------------------------------------------------------------------------------

func _begin_invite(port: int) -> void:
	var local := PortOpener.local_addresses()
	invite = {"state": "opening", "code": "", "lan": local["lan"], "tailscale": local["tailscale"], "port": port, "reason": ""}
	# Headless runs are tests; they must never touch the router.
	if not Settings.open_router_port or DisplayServer.get_name() == "headless":
		invite["state"] = "off"
	else:
		port_opener.open(port)
	invite_changed.emit()


func _on_port_opened(result: Dictionary) -> void:
	if invite.is_empty():
		return
	if port_opener.lan_address != "":
		invite["lan"] = port_opener.lan_address
	if result.get("ok", false):
		invite["state"] = "ready"
		invite["code"] = InviteCode.encode(String(result["external_ip"]), int(invite["port"]), DEFAULT_PORT)
	else:
		invite["state"] = "failed"
		invite["reason"] = String(result.get("reason", ""))
	invite_changed.emit()


## What COPY INVITE puts on the clipboard. The join box finds the code inside the sentence.
func invite_text() -> String:
	if invite.get("state", "") == "ready":
		return "Join my CHAINS DEEZNUTS TOGETHER game! Invite code: %s" % invite["code"]
	var addr := String(invite.get("tailscale", ""))
	if addr == "":
		addr = String(invite.get("lan", ""))
	if addr != "" and int(invite.get("port", DEFAULT_PORT)) != DEFAULT_PORT:
		addr += ":%d" % int(invite["port"])
	return addr


# --- Build check ----------------------------------------------------------------------------

## Fingerprint of the game code. Host and friends must match: the level is generated from code,
## so a different copy builds a different building. Joiners with another build are turned away.
## The friend build exports scripts as text (export_presets.cfg) so this matches the source.
func get_build_id() -> String:
	if _build_id == "":
		var files: PackedStringArray = []
		_collect_scripts("res://src", files)
		files.sort()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		for f in files:
			ctx.update(f.to_utf8_buffer())
			ctx.update(FileAccess.get_file_as_bytes(f))
		_build_id = ctx.finish().hex_encode().left(12)
	return _build_id


## Test hook: pretend to be another build (main.gd --fake-build=X).
func set_build_id_override(id: String) -> void:
	_build_id = id


func _collect_scripts(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect_scripts(dir.path_join(d), out)


## Players sorted by join order; this order IS the chain order.
func get_players() -> Array[Player]:
	var out: Array[Player] = []
	if players_root == null or not is_instance_valid(players_root):
		return out
	for c in players_root.get_children():
		if c is Player and not c.is_queued_for_deletion():
			out.append(c)
	out.sort_custom(func(a: Player, b: Player) -> bool: return a.join_index < b.join_index)
	return out


## Everything on the Line: the players, plus the Ballast when it's switched on (solo).
func get_chain_bodies() -> Array[ChainBody]:
	var out: Array[ChainBody] = []
	for p in get_players():
		out.append(p)
	if ballast != null and is_instance_valid(ballast) and ballast.active:
		out.append(ballast)
	return out


func get_local_player() -> Player:
	return find_player(multiplayer.get_unique_id())


func find_player(peer_id: int) -> Player:
	for p in get_players():
		if p.peer_id == peer_id:
			return p
	return null


func _process(_delta: float) -> void:
	# The Ballast keeps a lone player company, and leaves as soon as anyone joins.
	if ballast == null or not is_instance_valid(ballast) or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var players := get_players()
	var want := players.size() == 1
	if want != ballast.active:
		var near := players[0].global_position + Vector3(1.2, 0.3, 0.0) if not players.is_empty() else Vector3.ZERO
		ballast.set_active(want, near)


# --- Peer lifecycle -------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		GameState.sync_state_to_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_registered.erase(id)
	var node := find_player(id)
	if node != null:
		if node.is_grabbed() and node.grabbed_by != null:
			node.grabbed_by.call("release", false)
		node.server_drop_all()  # what they carried stays on the floor for the rest of the Line
		node.queue_free()
	players_changed.emit()


func _on_connected_to_server() -> void:
	register_player.rpc_id(1, local_name, get_build_id(), world_config)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit("Couldn't connect. Is the host running, and is the IP right?")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_registered.clear()
	disconnected_from_game.emit("The host left the game.")


@rpc("any_peer", "call_remote", "reliable")
func register_player(player_name: String, build: String, config: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0 or _registered.has(id):
		return
	if build != get_build_id():
		print("Net: turned away peer %d (build %s, host has %s)" % [id, build.left(12), get_build_id()])
		_rpc_rejected.rpc_id(id, "Your copy of the game is a different version from the host's. Ask them to send you the latest one.")
		GameState.post_message_local("%s tried to join with a different version of the game. Send them your latest copy." % player_name.strip_edges().left(16), 6.0)
		_drop_later(id)
		return
	if not same_world(config, world_config):
		# Their building isn't ours: send them the recipe. They hang up, rebuild, and come back.
		print("Net: peer %d built world %s, we have %s; sending ours" % [id, config, world_config])
		_rpc_wrong_world.rpc_id(id, world_config)
		_drop_later(id)
		return
	_spawn_player_for(id, player_name)
	GameState.post_message("%s clocked in." % player_name.strip_edges(), 3.0)


## The joiner usually hangs up on its own first.
func _drop_later(id: int) -> void:
	get_tree().create_timer(REJECT_GRACE).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.get_peers().has(id):
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id))


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	print("Net: the host turned us away: %s" % reason)
	disconnected_from_game.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_wrong_world(config: Dictionary) -> void:
	print("Net: the host's world is %s; rebuilding and joining again" % config)
	world_mismatch.emit(config)


func _spawn_player_for(peer_id: int, player_name: String) -> void:
	if spawner == null or not is_instance_valid(spawner):
		push_error("Net: no spawner bound; build the world before hosting")
		return
	_registered[peer_id] = true
	var index := _next_join_index
	_next_join_index += 1
	var clean_name := player_name.strip_edges()
	if clean_name == "":
		clean_name = "Player %d" % (index + 1)
	spawner.spawn({"peer_id": peer_id, "name": clean_name, "join_index": index, "pos": _spawn_position_for(index)})
	players_changed.emit()


## A fresh lobby lines up at the checkpoint. A late joiner whose chain partner (the current last
## player) is out of reach drops in on top of that partner instead of being yanked across the map.
func _spawn_position_for(index: int) -> Vector3:
	var slot := index % MAX_PLAYERS
	var facing := GameState.checkpoint_facing
	var right := Vector3(cos(facing), 0.0, -sin(facing))
	var lineup := GameState.checkpoint_position + right * (float(slot) * 1.0 - 2.5) + Vector3(0.0, 0.2, 0.0)
	var existing := get_players()
	if existing.is_empty():
		return lineup
	var last := existing[existing.size() - 1]
	if last.global_position.distance_to(lineup) <= 4.5:
		return lineup
	return last.global_position + Vector3(0.0, 2.2, 0.0)


## Spawn function run by the player spawner on EVERY peer.
func spawn_player_node(data: Variant) -> Node:
	var d: Dictionary = data
	var p := PLAYER_SCENE.instantiate() as Player
	p.name = str(d["peer_id"])
	p.peer_id = int(d["peer_id"])
	p.display_name = String(d["name"])
	p.join_index = int(d["join_index"])
	var pos: Vector3 = d["pos"]
	p.position = pos
	p.synced_position = pos
	p.synced_yaw = GameState.checkpoint_facing
	return p


# --- Pickups and thrown objects (server spawns, every peer builds) ---------------------------------

## state: what a dropped item remembers (ammo counts), handed back to whoever picks it up.
func spawn_pickup(item_id: String, pos: Vector3, ignore_peer: int, state: Dictionary = {}) -> void:
	if pickup_spawner == null or not multiplayer.is_server():
		return
	_spawn_counter += 1
	pickup_spawner.spawn({"id": item_id, "pos": pos, "n": _spawn_counter, "ignore": ignore_peer, "until": Time.get_ticks_msec() + ItemPickup.REPICK_DELAY_MS, "state": state})


func spawn_pickup_node(data: Variant) -> Node:
	var d: Dictionary = data
	var p := ItemPickup.new()
	p.name = "Pickup_%s_%d" % [d["id"], int(d["n"])]
	p.item_id = String(d["id"])
	p.position = d["pos"]
	p.ignore_peer = int(d["ignore"])
	p.ignore_until_msec = int(d["until"])
	p.carry_state = d.get("state", {})
	return p


func spawn_thrown(kind: String, pos: Vector3, vel: Vector3, owner_peer: int) -> void:
	if thrown_spawner == null or not multiplayer.is_server():
		return
	_spawn_counter += 1
	thrown_spawner.spawn({"kind": kind, "pos": pos, "vel": vel, "owner": owner_peer, "n": _spawn_counter})


func spawn_thrown_node(data: Variant) -> Node:
	var d: Dictionary = data
	var t := Thrown.new()
	t.name = "Thrown_%s_%d" % [d["kind"], int(d["n"])]
	t.kind = String(d["kind"])
	t.position = d["pos"]
	t.synced_position = d["pos"]
	t.vel = d["vel"]
	t.owner_peer = int(d["owner"])
	return t
