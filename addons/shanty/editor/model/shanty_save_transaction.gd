@tool
class_name ShantySaveTransaction
extends RefCounted

## Writes several of the host's files all or nothing. **No target is touched
## until every output is staged.** Each output is first written beside its
## target (`ShantyFiles.text_staging_path()`, `resource_staging_path()`) and
## read back; only then does `commit()` move each staged file over its target.
## A failure while staging removes the staged files and leaves every target as
## it was; a failure while committing also writes back, from the bytes kept in
## memory, every target already replaced, and removes the targets that did not
## exist before.
##
## **A staged resource keeps its target's `ext_resource` ids.** The text saver
## keys each external resource's id by the path being written, so a file saved
## at its staging path would otherwise get a fresh id for every external
## resource and every `ExtResource()` naming one -- a one-field edit churning
## the whole file's diff. Before a resource is staged, every external resource
## it names is given, for the staging path, the id it has in the target; after
## a commit the target is given whatever the staging path ended up with (a new
## reference's fresh id), so the next save is stable too.

## How a staged file replaces its target: `(staged, target) -> Error`. A test
## swaps in one that fails, to prove the rollback.
var replace_file: Callable = ShantyFiles.replace
## Why staging or committing failed, for the status line.
var failure: String = ""

var _targets: PackedStringArray = []
var _staged: PackedStringArray = []
## Each target's bytes before the transaction, for the rollback.
var _originals: Array[PackedByteArray] = []
var _existed: Array[bool] = []
## The resource saved to each target, or null for text.
var _resources: Array[Resource] = []
## Resources given their file by `claim_paths()`, until a commit keeps it.
var _claimed: Array[Resource] = []


## Gives each resource of `paths` that has no file yet the one it is about to
## be saved at, before anything is staged: then one new resource naming another
## -- a new scene saying a new conversation -- is written as a reference to
## that file, not as a copy embedded in it. Unless the commit succeeds,
## `discard()` takes the paths back. **Two resources never claim one file**:
## false, claiming nothing and with `failure` naming the path, when they would.
func claim_paths(paths: Dictionary[Resource, String]) -> bool:
	var seen: Dictionary[String, bool] = {}
	for resource: Resource in paths:
		if seen.has(paths[resource]):
			return _fail("two new resources would both be saved as %s." % paths[resource])
		seen[paths[resource]] = true
	for resource: Resource in paths:
		if resource.resource_path.is_empty():
			ShantyFiles.take_over(resource, paths[resource])
			_claimed.append(resource)
	return true


## Stages `text` as the next content of `path`. False, with `failure` set, when
## the staged file could not be written or does not read back as written.
func stage_text(path: String, text: String) -> bool:
	var staged: String = ShantyFiles.text_staging_path(path)
	_remember(path, staged, null)
	var bytes: PackedByteArray = text.to_utf8_buffer()
	var error: Error = ShantyFiles.write_bytes(staged, bytes)
	if error != OK or ShantyFiles.read_bytes(staged) != bytes:
		return _fail("could not write %s (%s)." % [path, error_string(error)])
	return true


## Stages `resource` as the next content of `path`. The staged file starts as
## a copy of the original, so the saver finds the uid the file already carries
## and the replaced file keeps it; its `ext_resource` ids are the original's.
func stage_resource(resource: Resource, path: String) -> bool:
	var staged: String = ShantyFiles.resource_staging_path(path)
	_remember(path, staged, resource)
	var error: Error = OK
	if ShantyFiles.exists(path):
		error = ShantyFiles.copy(path, staged)
	if error == OK:
		_carry_ids(resource, path, staged)
		error = ShantyFiles.save_resource(resource, staged)
	if error != OK or ShantyFiles.read_bytes(staged).is_empty():
		return _fail("could not write %s (%s)." % [path, error_string(error)])
	return true


## Every staged file, in staging order: the editor may have noticed a staged
## resource as it was saved, and is told it is gone.
func staged_paths() -> PackedStringArray:
	return _staged.duplicate()


## Moves every staged file over its target. On a failure, puts every target
## back as it was and returns false with `failure` set.
func commit() -> bool:
	for index: int in _targets.size():
		var error: Error = replace_file.call(_staged[index], _targets[index])
		if error != OK or not ShantyFiles.exists(_targets[index]):
			_roll_back(index)
			return _fail("could not replace %s (%s)." % [_targets[index], error_string(error)])
	for index: int in _targets.size():
		if _resources[index] != null:
			ShantyFiles.take_over(_resources[index], _targets[index])
			_carry_ids(_resources[index], _staged[index], _targets[index])
	_claimed.clear()
	return true


## Removes every staged file still on disk and the ids kept for its path, and
## takes back every path `claim_paths()` gave that no commit kept.
func discard() -> void:
	for index: int in _staged.size():
		ShantyFiles.remove(_staged[index])
		if _resources[index] != null:
			_carry_ids(_resources[index], "", _staged[index])
	for resource: Resource in _claimed:
		resource.resource_path = ""
	_claimed.clear()


func _remember(path: String, staged: String, resource: Resource) -> void:
	_targets.append(path)
	_staged.append(staged)
	_existed.append(ShantyFiles.exists(path))
	_originals.append(ShantyFiles.read_bytes(path))
	_resources.append(resource)


## Restores targets `0..through`: the replace that failed may have removed its
## target before it could move the staged file in.
func _roll_back(through: int) -> void:
	for index: int in range(through + 1):
		if _existed[index]:
			ShantyFiles.write_bytes(_targets[index], _originals[index])
		else:
			ShantyFiles.remove(_targets[index])
	discard()


func _fail(reason: String) -> bool:
	failure = reason
	return false


## Gives every external resource `resource` names, for the file `to`, the id it
## has in the file `from`; an empty `from` clears the ids kept for `to`.
static func _carry_ids(resource: Resource, from: String, to: String) -> void:
	var source: String = ProjectSettings.localize_path(from) if not from.is_empty() else ""
	var target: String = ProjectSettings.localize_path(to)
	for external: Resource in _external_resources(resource):
		external.set_id_for_path(
			target, external.get_id_for_path(source) if not source.is_empty() else ""
		)


## Every resource saved in its own file that `resource` names, as the saver
## finds them: through stored properties, the resources built into the file,
## arrays, dictionaries and a typed collection's script.
static func _external_resources(resource: Resource) -> Array[Resource]:
	var found: Array[Resource] = []
	var visited: Dictionary[Resource, bool] = {resource: true}
	_collect_properties(resource, found, visited)
	return found


static func _collect_properties(
	resource: Resource, found: Array[Resource], visited: Dictionary[Resource, bool]
) -> void:
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			_collect(resource.get(property["name"]), found, visited)


static func _collect(
	value: Variant, found: Array[Resource], visited: Dictionary[Resource, bool]
) -> void:
	if value is Resource:
		var resource: Resource = value
		if visited.has(resource):
			return
		visited[resource] = true
		if resource.is_built_in():
			_collect_properties(resource, found, visited)
		else:
			found.append(resource)
	elif value is Array:
		var array: Array = value
		_collect(array.get_typed_script(), found, visited)
		for item: Variant in array:
			_collect(item, found, visited)
	elif value is Dictionary:
		var dictionary: Dictionary = value
		_collect(dictionary.get_typed_key_script(), found, visited)
		_collect(dictionary.get_typed_value_script(), found, visited)
		for key: Variant in dictionary:
			_collect(key, found, visited)
			_collect(dictionary[key], found, visited)
