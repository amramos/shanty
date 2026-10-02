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
## and the replaced file keeps it.
func stage_resource(resource: Resource, path: String) -> bool:
	var staged: String = ShantyFiles.resource_staging_path(path)
	_remember(path, staged, resource)
	var error: Error = OK
	if ShantyFiles.exists(path):
		error = ShantyFiles.copy(path, staged)
	if error == OK:
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
	return true


## Removes every staged file still on disk.
func discard() -> void:
	for staged: String in _staged:
		ShantyFiles.remove(staged)


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
