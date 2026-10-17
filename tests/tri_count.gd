extends SceneTree
## Prints triangle counts of the sculpted meshes (a performance check): -s res://tests/tri_count.gd

func _init() -> void:
	for k in 3:
		print("horde %d: %d tris" % [k, HordeMesh.mesh_for(k).get_faces().size() / 3])
	var bodies: Array = [["player", PlayerModel.new()], ["hire", HireBody.new()], ["pappy", PappyBody.new()], ["jumper", JumperBody.new()], ["tenant", RoofStalker.new()]]
	for b in bodies:
		var n: Node3D = b[1]
		if n is PlayerModel:
			(n as PlayerModel).build(0)
		elif n is RoofStalker:
			root.add_child(n)
		else:
			n.call("build")
		print("%s: %d tris" % [b[0], _count(n)])
		if b[0] == "jumper" or b[0] == "pappy":
			for c in n.find_children("*", "MeshInstance3D", true, false):
				print("   ", c.get_parent().name, " ", (c as MeshInstance3D).mesh.get_faces().size() / 3, " lods ", (c as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3 if (c as MeshInstance3D).mesh is ArrayMesh else -1)
		n.free()
	quit()


func _count(n: Node) -> int:
	var t := 0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		t += (c as MeshInstance3D).mesh.get_faces().size() / 3
	return t
