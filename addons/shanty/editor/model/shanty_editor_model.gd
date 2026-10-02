@tool
class_name ShantyEditorModel
extends RefCounted

## Everything the Shanty tab knows and does, with no editor and no node: the
## host's config, its CSV as a `ShantyCsvDocument`, the authored resources from
## the config's folders, the two locales the writer is looking at, and Save.
## The panes only bind to it, so what Save writes is proven headlessly.
##
## **Save never overwrites what it has not seen.** Each file's hash is taken
## when it is read; a file that changed on disk since then refuses the whole
## save before anything is written. **Lint errors refuse it too**; warnings
## and coverage never do. Edits to speakers and conversations live in
## `ShantySpeakerEdits` and `ShantyConversationEdits`.

## Emitted after any edit, so the panes can redraw.
signal changed

var config: ShantyProjectConfig = null
var document: ShantyCsvDocument = ShantyCsvDocument.new()
var speakers: Array[SpeakerDefinition] = []
var conversations: Array[ConversationDefinition] = []
var scenes: Array[CutsceneDefinition] = []
var triggers: Array[StoryTriggerDefinition] = []
## The locale the writer writes in, and the one shown beside it.
var source_locale: String = ""
var target_locale: String = ""
## A conversation's key prefix as the writer set it, before any of its keys
## exists to infer it from (`ShantyConversationEdits.prefix_of()`).
var key_prefixes: Dictionary[ConversationDefinition, String] = {}

## Path -> hash when read; "" for a file that did not exist.
var _hashes: Dictionary[String, String] = {}
var _csv_dirty: bool = false
## Resources edited since the last save.
var _dirty: Array[Resource] = []
## Where each resource made this session will be saved.
var _new_paths: Dictionary[Resource, String] = {}


## Reads everything `with_config` names. Returns "" or why it could not.
func open(with_config: ShantyProjectConfig, fresh: bool = false) -> String:
	if with_config == null:
		return "No Shanty config: set the project setting %s." % ShantyProjectConfig.SETTING
	config = with_config
	_hashes.clear()
	_dirty.clear()
	_new_paths.clear()
	key_prefixes.clear()
	_csv_dirty = false
	document = ShantyCsvDocument.parse(ShantyFiles.read_text(config.csv_path))
	_hashes[config.csv_path] = ShantyFiles.hash_of(config.csv_path)
	_load_folders(fresh)
	_choose_locales()
	changed.emit()
	if not ShantyFiles.exists(config.csv_path):
		return "The CSV %s does not exist yet; Save creates it." % config.csv_path
	return ""


## Throws away every unsaved edit and reads the files again.
func reload() -> String:
	return open(config, true)


func locales() -> PackedStringArray:
	return document.locales()


func set_locales(source: String, target: String) -> void:
	source_locale = source
	target_locale = target
	changed.emit()


## Adds a locale column. False when the name is not a locale code or exists.
func add_locale(locale: String) -> bool:
	if not document.add_locale(locale):
		return false
	_csv_dirty = true
	if target_locale.is_empty() or target_locale == source_locale:
		target_locale = locale
	changed.emit()
	return true


func coverage() -> Array[ShantyLocaleCoverage]:
	return document.coverage()


func text(key: String, locale: String) -> String:
	return document.text(key, locale)


func set_text(key: String, locale: String, value: String) -> bool:
	return _edit_csv(document.set_text(key, locale, value))


func notes(key: String) -> String:
	return document.notes(key)


func set_notes(key: String, value: String) -> bool:
	return _edit_csv(document.set_notes(key, value))


func flags(key: String) -> PackedStringArray:
	return document.flags(key)


func set_flag(key: String, flag: String, on: bool) -> bool:
	return _edit_csv(document.set_flag(key, flag, on))


## Adds a row for `key` after `after_key`'s (or at the end). False if it exists.
func add_row(key: String, after_key: String = "") -> bool:
	return _edit_csv(document.append_row(key, after_key))


func remove_row(key: String) -> bool:
	return _edit_csv(document.remove_row(key))


## Marks `resource` as edited, so the next Save writes it.
func touch(resource: Resource) -> void:
	if resource != null and not _dirty.has(resource):
		_dirty.append(resource)
	changed.emit()


## Registers a resource made this session, to be saved at `path`.
func adopt(resource: Resource, path: String) -> void:
	_new_paths[resource] = path
	_hashes[path] = ShantyFiles.hash_of(path)
	touch(resource)


## The file `resource` lives in, or will once saved.
func path_of(resource: Resource) -> String:
	return _new_paths.get(resource, resource.resource_path)


func is_dirty() -> bool:
	return _csv_dirty or not _dirty.is_empty()


func lint() -> Array[ShantyLintIssue]:
	return ShantyLint.check(document, config, speakers, conversations, scenes)


## Lints, refuses on an error or a stale file, then writes the CSV and every
## edited resource. Nothing is written unless everything may be.
func save() -> ShantySaveResult:
	var issues: Array[ShantyLintIssue] = lint()
	var errors: int = ShantyLint.errors_in(issues).size()
	if errors > 0:
		var blocked := ShantySaveResult.refused(
			"Not saved: lint found %d error%s." % [errors, "" if errors == 1 else "s"]
		)
		blocked.issues = issues
		return blocked
	var stale: PackedStringArray = stale_paths()
	if not stale.is_empty():
		var refused := ShantySaveResult.refused(
			(
				"Not saved: %s changed on disk since it was read. Reload to see the change."
				% ", ".join(stale)
			)
		)
		refused.stale_paths = stale
		refused.issues = issues
		return refused
	return _write(issues)


## Every file Save would write whose content changed on disk since it was read.
func stale_paths() -> PackedStringArray:
	var stale: PackedStringArray = []
	for path: String in _paths_to_write():
		if ShantyFiles.hash_of(path) != _hashes.get(path, ""):
			stale.append(path)
	return stale


func _paths_to_write() -> PackedStringArray:
	var paths: PackedStringArray = []
	if _csv_dirty:
		paths.append(config.csv_path)
	for resource: Resource in _dirty:
		paths.append(path_of(resource))
	return paths


func _write(issues: Array[ShantyLintIssue]) -> ShantySaveResult:
	var result := ShantySaveResult.new()
	result.issues = issues
	if _csv_dirty:
		var error: Error = ShantyFiles.write_text(config.csv_path, document.to_text())
		if error != OK:
			return ShantySaveResult.refused("Could not write %s (%s)." % [config.csv_path, error])
		_hashes[config.csv_path] = ShantyFiles.hash_of(config.csv_path)
		result.csv_path = config.csv_path
		_csv_dirty = false
	for resource: Resource in _dirty.duplicate():
		var path: String = path_of(resource)
		var error: Error = ShantyFiles.save_resource(resource, path)
		if error != OK:
			result.message = "Could not write %s (%s)." % [path, error]
			return result
		_hashes[path] = ShantyFiles.hash_of(path)
		_new_paths.erase(resource)
		_dirty.erase(resource)
		result.resource_paths.append(path)
	result.saved = true
	var count: int = result.resource_paths.size() + (0 if result.csv_path.is_empty() else 1)
	result.message = "Saved %d file%s." % [count, "" if count == 1 else "s"]
	changed.emit()
	return result


func _edit_csv(done: bool) -> bool:
	if done:
		_csv_dirty = true
		changed.emit()
	return done


func _load_folders(fresh: bool) -> void:
	speakers.clear()
	conversations.clear()
	scenes.clear()
	triggers.clear()
	var seen: Dictionary[String, bool] = {}
	for folder: String in config.content_folders():
		for path: String in ShantyFiles.list_resources(folder):
			if seen.has(path):
				continue
			seen[path] = true
			var resource: Resource = ShantyFiles.load_resource(path, fresh)
			if _keep(resource):
				_hashes[path] = ShantyFiles.hash_of(path)


## Files the resource into its list. False for anything that is not Shanty data.
func _keep(resource: Resource) -> bool:
	if resource is SpeakerDefinition:
		speakers.append(resource)
	elif resource is ConversationDefinition:
		conversations.append(resource)
	elif resource is CutsceneDefinition:
		scenes.append(resource)
	elif resource is StoryTriggerDefinition:
		triggers.append(resource)
	else:
		return false
	return true


func _choose_locales() -> void:
	var available: PackedStringArray = document.locales()
	source_locale = config.source_locale if available.has(config.source_locale) else ""
	if source_locale.is_empty() and not available.is_empty():
		source_locale = available[0]
	target_locale = ""
	for locale: String in available:
		if locale != source_locale:
			target_locale = locale
			break
