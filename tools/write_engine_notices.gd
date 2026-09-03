extends SceneTree

func _initialize() -> void:
	var file = FileAccess.open("res://assets/engine_notices.txt", FileAccess.WRITE)
	if file == null:
		printerr("Could not write engine notices")
		quit(1)
		return
	file.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n")
	file.store_string(Engine.get_license_text() + "\n\n")
	file.store_string("THIRD-PARTY COPYRIGHT NOTICES\n\n")
	for entry in Engine.get_copyright_info():
		file.store_string(str(entry.name) + "\n")
		for part in entry.parts:
			for copyright in part.copyright:
				file.store_string(str(copyright) + "\n")
			file.store_string("License: " + str(part.license) + "\n\n")
	file.store_string("THIRD-PARTY LICENSE TEXTS\n\n")
	var licenses = Engine.get_license_info()
	for name in licenses:
		var separator = "\n" if name == licenses.keys()[-1] else "\n\n"
		file.store_string(str(name) + "\n" + str(licenses[name]).strip_edges() + separator)
	file.close()
	print("Engine notices written")
	quit(0)
