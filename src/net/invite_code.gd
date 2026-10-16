class_name InviteCode
extends RefCounted
## Short invite codes friends paste instead of an IP address, e.g. "K7QM-2XR".
## A code is the host's public IPv4 address in base 32 (plus "-PORT" when not the default port).
## The alphabet skips 0/O and 1/I so a code survives being read out over voice chat.

const ALPHABET: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const DIGITS: int = 7  # 7 base-32 digits = 35 bits, room for a 32-bit IPv4 address
const MAX_IPV4: int = 0xFFFFFFFF
# Case-insensitive; under (?i) the classes still exclude i and o.
const CODE_PATTERN: String = "(?i)\\b([2-9A-HJ-NP-Z]{4})-([2-9A-HJ-NP-Z]{3})(?:-(\\d{1,5}))?\\b"
const IP_PATTERN: String = "\\b(\\d{1,3}(?:\\.\\d{1,3}){3})(?::(\\d{1,5}))?\\b"


static func encode(ip: String, port: int, default_port: int) -> String:
	var n := ip_to_int(ip)
	if n < 0:
		return ""
	var digits := ""
	for i in DIGITS:
		digits = ALPHABET[n & 31] + digits
		n >>= 5
	var code := digits.left(4) + "-" + digits.substr(4)
	if port != default_port:
		code += "-%d" % port
	return code


## Reads whatever a friend pasted: a code (any case, inside a longer message is fine), an IP
## address with an optional ":port", or a host name. Returns {"host": String, "port": int}, or {}
## when there's nothing usable.
static func parse(text: String, default_port: int) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	var m := RegEx.create_from_string(CODE_PATTERN).search(t)
	if m != null:
		return _from_code(m.get_string(1) + m.get_string(2), m.get_string(3), default_port)
	m = RegEx.create_from_string(IP_PATTERN).search(t)
	if m != null and m.get_string(1).is_valid_ip_address():
		return {"host": m.get_string(1), "port": _port_or(m.get_string(2), default_port)}
	# A bare code typed without its dash.
	var squashed := t.to_upper().replace(" ", "").replace("-", "")
	if squashed.length() == DIGITS and _all_in_alphabet(squashed):
		return _from_code(squashed, "", default_port)
	# Anything else without spaces could be a host name (Tailscale names, LAN names).
	if not t.contains(" ") and t.is_valid_filename():
		return {"host": t, "port": default_port}
	return {}


static func ip_to_int(ip: String) -> int:
	if not ip.is_valid_ip_address() or ip.contains(":"):
		return -1
	var n := 0
	for part in ip.split("."):
		n = (n << 8) | part.to_int()
	return n


static func int_to_ip(n: int) -> String:
	return "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]


## Private, carrier-grade NAT (100.64/10, also Tailscale) and loopback addresses can't be reached
## from the internet, so a code built from one would be useless.
static func is_public_ipv4(ip: String) -> bool:
	var n := ip_to_int(ip)
	if n < 0:
		return false
	var a := (n >> 24) & 255
	var b := (n >> 16) & 255
	if a == 10 or a == 127 or a == 0 or a >= 224:
		return false
	if a == 172 and b >= 16 and b <= 31:
		return false
	if a == 192 and b == 168:
		return false
	if a == 169 and b == 254:
		return false
	if a == 100 and b >= 64 and b <= 127:
		return false
	return true


static func _from_code(digits: String, port_text: String, default_port: int) -> Dictionary:
	var n := 0
	for ch in digits.to_upper():
		n = (n << 5) | ALPHABET.find(ch)
	if n > MAX_IPV4:
		return {}
	return {"host": int_to_ip(n), "port": _port_or(port_text, default_port)}


static func _port_or(text: String, default_port: int) -> int:
	var p := text.to_int()
	return p if p > 0 and p < 65536 else default_port


static func _all_in_alphabet(s: String) -> bool:
	for ch in s:
		if not ALPHABET.contains(ch):
			return false
	return true
