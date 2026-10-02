extends RefCounted

## Reads the addon's own files for the tests that guard what it holds. No
## `class_name`: the tests reach it through `preload()`, so the test tree spends
## no global names either.

const ADDON_ROOT: String = "res://addons/shanty/"


## Every file under `root` whose extension is in `extensions`, recursively,
## sorted. Godot's cache and import products are never listed.
static func list(root: String, extensions: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = []
	_collect(root, extensions, found)
	found.sort()
	return found


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


static func _collect(
	directory: String, extensions: PackedStringArray, found: PackedStringArray
) -> void:
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() in extensions:
			found.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		if child.begins_with("."):
			continue
		_collect(directory.path_join(child), extensions, found)
