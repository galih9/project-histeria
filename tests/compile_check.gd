extends Node
## Dev check: loads every script and scene in the project and reports failures.

func _ready() -> void:
	var failures := 0
	var files := _collect("res://", [])
	for path: String in files:
		var res := load(path)
		if res == null:
			print("FAIL load ", path)
			failures += 1
		elif res is GDScript and not (res as GDScript).can_instantiate() and not path.contains("tests/"):
			print("FAIL compile ", path)
			failures += 1
		elif res is PackedScene:
			var node := (res as PackedScene).instantiate()
			if node == null:
				print("FAIL instantiate ", path)
				failures += 1
			else:
				node.free()
	print("CHECKED %d files, %d failures" % [files.size(), failures])
	get_tree().quit(failures)

func _collect(dir: String, out: Array) -> Array:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "tools_tmp":
			_collect(dir.path_join(d), out)
	return out
