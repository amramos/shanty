@tool
class_name ShantyFiles
extends RefCounted

## The one script through which the Shanty tab reads and writes the host's own
## files: the CSV, the config, and the speakers, conversations, scenes and
## triggers in the folders the config names. Every path it is given comes from
## the host's config or the host's project, never from inside the addon, so
## this is the single place the addon loads a path it did not write itself --
## and the self-containment test lets exactly this file do so.

const BOM: String = "\uFEFF"
## Marks a file Save has staged but not yet moved over its target.
const STAGING_MARK: String = ".shanty-tmp"


## The file's text, read as UTF-8 bytes so nothing is normalised on the way in:
## line breaks stay as they are, and a byte-order mark is kept as a leading
## U+FEFF (the decoder alone would drop it). "" when it cannot be read.
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var text: String = bytes.get_string_from_utf8()
	var has_bom: bool = (
		bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF
	)
	if has_bom and not text.begins_with(BOM):
		return BOM + text
	return text


## Writes `text` as UTF-8 in place; a leading U+FEFF is written as the
## byte-order mark. Save never calls this on a host file: it stages through
## `ShantySaveTransaction`.
static func write_text(path: String, text: String) -> Error:
	return write_bytes(path, text.to_utf8_buffer())


## The file's bytes, or none when there is no file.
static func read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


static func write_bytes(path: String, bytes: PackedByteArray) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	var error: Error = file.get_error()
	file.close()
	return error


## Where a text file is staged before it replaces `path`. The suffix is no
## extension the editor imports, so a staged CSV is never imported.
static func text_staging_path(path: String) -> String:
	return path + STAGING_MARK


## Where a resource is staged before it replaces `path`: the saver chooses its
## format by extension, so the mark goes before it.
static func resource_staging_path(path: String) -> String:
	return "%s%s.%s" % [path.get_basename(), STAGING_MARK, path.get_extension()]


static func copy(from: String, to: String) -> Error:
	return DirAccess.copy_absolute(from, to)


## Moves `staged` over `target`, replacing it.
static func replace(staged: String, target: String) -> Error:
	return DirAccess.rename_absolute(staged, target)


static func remove(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


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


## Saves `resource` to `path` without making `path` its own.
static func save_resource(resource: Resource, path: String) -> Error:
	return ResourceSaver.save(resource, path)


## Makes `path` the resource's own, so a resource made this session is the one
## the editor's cache hands back from then on.
static func take_over(resource: Resource, path: String) -> void:
	if resource.resource_path != path:
		resource.take_over_path(path)


## Every `.tres` under `folder`, recursively, sorted. Hidden folders, and a
## staged file an interrupted Save left behind, are skipped.
static func list_resources(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if not folder.is_empty() and DirAccess.dir_exists_absolute(folder):
		_collect(folder, found)
	found.sort()
	return found


## A new instance of the script at `path`, or null when it is not a script that
## builds a Resource. Made the way the Inspector's "New" menu makes one -- the
## engine base first, then the script -- because inside the editor a script
## that is not `@tool` cannot be `new()`-ed, only attached.
static func instantiate(path: String) -> Resource:
	var script: Script = load_resource(path) as Script
	if script == null or not ClassDB.is_parent_class(script.get_instance_base_type(), "Resource"):
		return null
	var made: Resource = ClassDB.instantiate(script.get_instance_base_type()) as Resource
	if made != null:
		made.set_script(script)
	return made


## The path the project setting names: the addon's example config when the
## setting was never registered, "" when the host emptied it.
static func config_path() -> String:
	return String(
		ProjectSettings.get_setting(ShantyProjectConfig.SETTING, ShantyProjectConfig.DEFAULT_PATH)
	)


## Points the project setting at the config at `path`, in memory: the editor
## saves `project.godot`.
static func set_config_path(path: String) -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, path)


## The config the project setting names, or null with no setting or no file.
static func configured() -> ShantyProjectConfig:
	var path: String = config_path()
	if path.is_empty() or not exists(path):
		return null
	return load_resource(path) as ShantyProjectConfig


## Saves a new config at `path`, its CSV and every folder beside it, so the
## tab opens on it at once; the writer edits it in the Inspector from there.
## `ERR_ALREADY_EXISTS`, writing nothing, when a file is at `path`: an
## existing config is opened, never overwritten with a blank one.
static func create_config(path: String) -> Error:
	if exists(path):
		return ERR_ALREADY_EXISTS
	var made := ShantyProjectConfig.new()
	var folder: String = path.get_base_dir()
	made.csv_path = folder.path_join(ShantyProjectConfig.NEW_CSV_NAME)
	made.speakers_folder = folder
	made.conversations_folder = folder
	made.scenes_folder = folder
	made.triggers_folder = folder
	var error: Error = ResourceSaver.save(made, path)
	if error == OK:
		made.take_over_path(path)
	return error


static func _collect(folder: String, found: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "tres" and not file.contains(STAGING_MARK):
			found.append(folder.path_join(file))
	for child: String in DirAccess.get_directories_at(folder):
		if not child.begins_with("."):
			_collect(folder.path_join(child), found)
