extends SceneTree
## Writes LICENSES.txt for the friend build: the friend build ships the official Godot executable
## (renamed), and Godot's MIT license asks for its notice and the third-party notices to go along.
##   godot --headless --script tools/write_licenses.gd -- <output file>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("write_licenses: pass the output file after --")
		quit(1)
		return
	var lines := PackedStringArray()
	lines.append("CHAINS DEEZNUTS TOGETHER runs on the Godot Engine, https://godotengine.org")
	lines.append("\"CHAINS DEEZNUTS TOGETHER.exe\" is the official Godot %s executable, renamed." % String(Engine.get_version_info()["string"]))
	lines.append("Godot is free software under the MIT license below.")
	lines.append("The ceiling and carpet textures are CC0 1.0 (public domain) from TextureCan, https://www.texturecan.com")
	lines.append("The manor's ground, stone, wood, bark, roof, leaf and wallpaper textures are CC0 1.0 (public domain) from ambientCG, https://ambientcg.com")
	lines.append("")
	lines.append("==== Godot Engine ====")
	lines.append(Engine.get_license_text())
	lines.append("")
	lines.append("==== Third-party components in Godot ====")
	for info in Engine.get_copyright_info():
		lines.append("- %s" % info["name"])
		for part in info["parts"]:
			lines.append("  Files: %s" % ", ".join(PackedStringArray(part["files"])))
			for c in part["copyright"]:
				lines.append("  Copyright: %s" % c)
			lines.append("  License: %s" % part["license"])
	lines.append("")
	lines.append("==== License texts ====")
	var texts := Engine.get_license_info()
	for license_name in texts:
		lines.append("")
		lines.append("--- %s ---" % license_name)
		lines.append(String(texts[license_name]))
	var text := "\n".join(lines).replace("\r\n", "\n").replace("\n", "\r\n")
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	if f == null:
		printerr("write_licenses: can't write %s" % args[0])
		quit(1)
		return
	f.store_string(text)
	f.close()
	quit(0)
