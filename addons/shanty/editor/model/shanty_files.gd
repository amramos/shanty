@tool
class_name ShantyFiles
extends RefCounted

## The one script through which the Shanty tab reads and writes the host's own
## files: the CSV, the config, and the speakers, conversations, scenes and
## triggers in the folders the config names. Every path it is given comes from
## the host's config or the host's project, never from inside the addon, so
## this is the single place the addon loads a path it did not write itself --
## and the self-containment test lets exactly this file do so.


## The file's text, read as UTF-8 bytes so nothing is normalised on the way in.
## "" when it cannot be read.
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_bytes(path).get_string_from_utf8()


## Writes `text` as UTF-8, without a byte-order mark.
static func write_text(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(text.to_utf8_buffer())
	file.close()
	return OK


## The SHA-256 of the file's bytes, or "" when there is no file.
static func hash_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path)


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## The resource at `path`. `fresh` re-reads the file over any cached copy, so a
## reload after someone else's edit sees their edit.
static func load_resource(path: String, fresh: bool = false) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	var mode: ResourceLoader.CacheMode = (
		ResourceLoader.CACHE_MODE_REPLACE if fresh else ResourceLoader.CACHE_MODE_REUSE
	)
	return ResourceLoader.load(path, "", mode)


## Saves `resource` to `path` and makes `path` its own, so a resource made this
## session is the one the editor's cache hands back from then on.
static func save_resource(resource: Resource, path: String) -> Error:
	var error: Error = ResourceSaver.save(resource, path)
	if error == OK and resource.resource_path != path:
		resource.take_over_path(path)
	return error


## Every `.tres` under `folder`, recursively, sorted. Hidden folders are skipped.
static func list_resources(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if not folder.is_empty() and DirAccess.dir_exists_absolute(folder):
		_collect(folder, found)
	found.sort()
	return found


## A new instance of the script at `path`, or null when it is not a script that
## builds a Resource.
static func instantiate(path: String) -> Resource:
	var script: Script = load_resource(path) as Script
	if script == null or not script.can_instantiate():
		return null
	return script.new() as Resource


## The config the project setting names, or null with no setting or no file.
static func configured() -> ShantyProjectConfig:
	var path: String = String(ProjectSettings.get_setting(ShantyProjectConfig.SETTING, ""))
	if path.is_empty():
		return null
	return load_resource(path) as ShantyProjectConfig


static func _collect(folder: String, found: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "tres":
			found.append(folder.path_join(file))
	for child: String in DirAccess.get_directories_at(folder):
		if not child.begins_with("."):
			_collect(folder.path_join(child), found)
