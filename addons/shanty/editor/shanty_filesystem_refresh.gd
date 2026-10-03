@tool
extends RefCounted

## Tells the editor's filesystem about the files a Save wrote, without ever
## asking it to scan or import while it is already scanning or importing.
## While it is busy the paths wait, and the refresh runs once, on whichever of
## `filesystem_changed` or `resources_reimported` comes first after it settles.
##
## Then a file the filesystem does not know yet -- a new resource, a new CSV, a
## staged file that is gone again -- is `update_file()`d; a known CSV that
## changed is reimported, so its translations follow the edit; a known resource
## is `update_file()`d. Editor-only: the pane makes one only in the editor.

const CSV_EXTENSION: String = "csv"

var _files: EditorFileSystem = null
## Paths waiting for the filesystem to settle, in the order they were written.
var _pending: PackedStringArray = []


func _init(files: EditorFileSystem) -> void:
	_files = files


## Refreshes `paths` now, or as soon as the filesystem is idle.
func request(paths: PackedStringArray) -> void:
	for path: String in paths:
		if not _pending.has(path):
			_pending.append(path)
	if _is_busy():
		_wait()
	else:
		_flush()


func _is_busy() -> bool:
	return _files.is_scanning() or _files.is_importing()


## Connects once, one-shot, to both signals the filesystem settles with.
func _wait() -> void:
	if not _files.filesystem_changed.is_connected(_on_filesystem_changed):
		_files.filesystem_changed.connect(_on_filesystem_changed, CONNECT_ONE_SHOT)
	if not _files.resources_reimported.is_connected(_on_resources_reimported):
		_files.resources_reimported.connect(_on_resources_reimported, CONNECT_ONE_SHOT)


func _on_filesystem_changed() -> void:
	_settled()


func _on_resources_reimported(_paths: PackedStringArray) -> void:
	_settled()


## The first of the two signals has fired; the other is no longer wanted.
func _settled() -> void:
	if _files.filesystem_changed.is_connected(_on_filesystem_changed):
		_files.filesystem_changed.disconnect(_on_filesystem_changed)
	if _files.resources_reimported.is_connected(_on_resources_reimported):
		_files.resources_reimported.disconnect(_on_resources_reimported)
	if _is_busy():
		_wait()
	else:
		_flush()


func _flush() -> void:
	var paths: PackedStringArray = _pending
	_pending = PackedStringArray()
	var plan: Array[PackedStringArray] = split(paths, _files.get_file_type)
	for path: String in plan[0]:
		_files.update_file(path)
	if not plan[1].is_empty():
		_files.reimport_files(plan[1])


## `paths` as [to update, to reimport], given `type_of(path) -> String` (the
## filesystem's type, "" for a file it does not know): a known CSV still on disk
## is reimported, everything else updated, in order.
static func split(paths: PackedStringArray, type_of: Callable) -> Array[PackedStringArray]:
	var update: PackedStringArray = []
	var reimport: PackedStringArray = []
	for path: String in paths:
		var known: bool = not String(type_of.call(path)).is_empty()
		if known and path.get_extension() == CSV_EXTENSION and FileAccess.file_exists(path):
			reimport.append(path)
		else:
			update.append(path)
	return [update, reimport]
