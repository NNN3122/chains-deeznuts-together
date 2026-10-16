class_name PortOpener
extends Node
## While hosting, asks the home router over UPnP to forward the game port to this PC, so friends
## can join over the internet with an invite code: no manual port forwarding, no VPN.
## Router calls block for up to a few seconds, so each one runs on a worker thread. The mapping
## carries a lease that is renewed while hosting and is removed on leave and quit, so a crash
## doesn't leave the port open for good.

signal finished(result: Dictionary)  # {"ok": bool, "external_ip": String, "reason": String}

const DISCOVER_MS: int = 2000  # how long to listen for the router, milliseconds
const LEASE_SECONDS: int = 4 * 60 * 60  # router forgets the mapping after this unless renewed
const RENEW_SECONDS: float = 60.0 * 60.0  # renew well inside the lease
const MAPPING_NAME: String = "CHAINS DEEZNUTS TOGETHER"

var lan_address: String = ""  # this PC's address on the home network, as the router sees it
var _upnp: UPNP
var _thread: Thread
var _port: int = 0
var _mapped: bool = false
var _renew_t: float = 0.0


func _ready() -> void:
	set_process(false)


func open(port: int) -> void:
	close()
	_port = port
	_run(_open_job.bind(port))


## Removes the mapping. Blocks briefly (a finished discovery plus one router call).
func close() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _mapped and _upnp != null:
		_upnp.delete_port_mapping(_port, "UDP")
	_mapped = false
	_upnp = null
	_port = 0
	set_process(false)


func _exit_tree() -> void:
	close()


func _process(delta: float) -> void:
	if _thread != null:
		if _thread.is_alive():
			return
		var result: Dictionary = _thread.wait_to_finish()
		_thread = null
		_on_job_done(result)
	if _mapped:
		_renew_t += delta
		if _renew_t >= RENEW_SECONDS:
			_renew_t = 0.0
			_run(_renew_job.bind(_upnp, _port))


func _run(job: Callable) -> void:
	_thread = Thread.new()
	_thread.start(job)
	set_process(true)


func _on_job_done(result: Dictionary) -> void:
	if result.get("renewal", false):
		return
	if result.get("ok", false):
		_upnp = result["upnp"]
		_mapped = true
		_renew_t = 0.0
	lan_address = String(result.get("lan", ""))
	result.erase("upnp")
	finished.emit(result)


func _open_job(port: int) -> Dictionary:
	var u := UPNP.new()
	var err := u.discover(DISCOVER_MS, 2, "InternetGatewayDevice")
	var gw := u.get_gateway()
	if err != UPNP.UPNP_RESULT_SUCCESS or gw == null or not gw.is_valid_gateway():
		return {"ok": false, "reason": "no_router"}
	var lan := gw.igd_our_addr
	var res := u.add_port_mapping(port, port, MAPPING_NAME, "UDP", LEASE_SECONDS)
	if res == UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED:
		res = u.add_port_mapping(port, port, MAPPING_NAME, "UDP", 0)
	if res != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "reason": "refused", "lan": lan}
	var external := u.query_external_address()
	if not InviteCode.is_public_ipv4(external):
		# Another router or the ISP sits in front of this one: the mapping can't help.
		u.delete_port_mapping(port, "UDP")
		return {"ok": false, "reason": "double_nat", "lan": lan}
	return {"ok": true, "upnp": u, "external_ip": external, "lan": lan}


func _renew_job(u: UPNP, port: int) -> Dictionary:
	u.add_port_mapping(port, port, MAPPING_NAME, "UDP", LEASE_SECONDS)
	return {"renewal": true}


## This PC's home-network and Tailscale addresses, for friends in the same house or tailnet.
static func local_addresses() -> Dictionary:
	var out := {"lan": "", "tailscale": ""}
	var fallback := ""
	for a in IP.get_local_addresses():
		var n := InviteCode.ip_to_int(a)
		if n < 0:
			continue
		var first := (n >> 24) & 255
		var second := (n >> 16) & 255
		if first == 100 and second >= 64 and second <= 127:
			out["tailscale"] = a
		elif first == 192 and second == 168:
			out["lan"] = a if out["lan"] == "" else out["lan"]
		elif first == 10 or (first == 172 and second >= 16 and second <= 31):
			# Often a virtual adapter (WSL, Hyper-V); only used when nothing better shows up.
			fallback = a if fallback == "" else fallback
	if out["lan"] == "":
		out["lan"] = fallback
	return out
