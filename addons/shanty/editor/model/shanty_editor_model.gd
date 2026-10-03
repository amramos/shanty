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
## and coverage never do. **Save is all or nothing**: every file is staged
## before any is replaced, and a failure at any point leaves every original
## byte on disk. Edits live in `ShantySpeakerEdits`, `ShantyConversationEdits`,
## `ShantySceneEdits` and `ShantyTriggerEdits`.

## Emitted after any edit, so the panes can redraw.
signal changed

## Why the last open left the model empty.
enum Problem { NONE, NO_SETTING, NO_FILE, NOT_A_CONFIG, NO_CSV_PATH }

## Null whenever `problem` is not `NONE`.
var config: ShantyProjectConfig = null
var problem: Problem = Problem.NONE
## One sentence about the last open: why it failed, or what to know; "" when
## there is nothing to say.
var status: String = ""
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
## Why the last `add_*` call of an edits class made nothing; "" after one that
## made something.
var refusal: String = ""

## Path -> hash when read; "" for a file that did not exist.
var _hashes: Dictionary[String, String] = {}
var _csv_dirty: bool = false
## Resources edited since the last save.
var _dirty: Array[Resource] = []
## Where each resource made this session will be saved.
var _new_paths: Dictionary[Resource, String] = {}


## Opens the config at `path` -- the project setting's value -- and everything
## it names. Anything but `Problem.NONE` leaves the model empty, with `config`
## null; `status` says what happened either way.
func open_path(path: String, fresh: bool = false) -> Problem:
	var loaded: ShantyProjectConfig = null
	if not path.is_empty() and ShantyFiles.exists(path):
		loaded = ShantyFiles.load_resource(path, fresh) as ShantyProjectConfig
	if path.is_empty():
		_refuse(Problem.NO_SETTING, "No Shanty config: %s is empty." % ShantyProjectConfig.SETTING)
	elif not ShantyFiles.exists(path):
		_refuse(Problem.NO_FILE, "No Shanty config: %s does not exist." % path)
	elif loaded == null:
		_refuse(Problem.NOT_A_CONFIG, "%s is not a ShantyProjectConfig." % path)
	else:
		open(loaded, fresh)
	return problem


## Reads everything `with_config` names. Returns "" or why it could not.
func open(with_config: ShantyProjectConfig, fresh: bool = false) -> String:
	if with_config == null:
		return _refuse(Problem.NOT_A_CONFIG, "No Shanty config to open.")
	if with_config.csv_path.is_empty():
		return _refuse(Problem.NO_CSV_PATH, "The Shanty config names no CSV: set its csv_path.")
	_reset()
	config = with_config
	document = ShantyCsvDocument.parse(ShantyFiles.read_text(config.csv_path))
	_hashes[config.csv_path] = ShantyFiles.hash_of(config.csv_path)
	_load_folders(fresh)
	var pair: PackedStringArray = document.opening_locales(config.source_locale)
	source_locale = pair[0]
	target_locale = pair[1]
	problem = Problem.NONE
	status = ""
	var missing: PackedStringArray = ShantyHostKeys.missing(document)
	if not ShantyFiles.exists(config.csv_path):
		status = "The CSV %s does not exist yet; Save creates it." % config.csv_path
	elif not missing.is_empty():
		status = (
			(
				"%s lacks %s: Config ▾ > Add host keys adds them, unless your game's own"
				+ " catalogue declares them."
			)
			% [config.csv_path, ", ".join(missing)]
		)
	changed.emit()
	return status


## Throws away every unsaved edit and reads the files again.
func reload() -> String:
	return open(config, true)


## Points the project setting at the config at `path` and opens it: what the
## tab does once Create config… has written one, from any state. "" when it
## did; otherwise why not, changing nothing -- `path` is not a config, or edits
## are unsaved, which opening another config would drop. Only sets the
## setting: the editor writes it to `project.godot`.
func switch_config(path: String) -> String:
	if is_dirty():
		return "Not switched to %s: Save or Reload first; the unsaved edits would be lost." % path
	var loaded: ShantyProjectConfig = null
	if ShantyFiles.exists(path):
		loaded = ShantyFiles.load_resource(path, true) as ShantyProjectConfig
	if loaded == null:
		return "Not switched: %s is not a ShantyProjectConfig." % path
	ShantyFiles.set_config_path(path)
	open(loaded, true)
	return ""


func locales() -> PackedStringArray:
	return document.locales()


func set_locales(source: String, target: String) -> void:
	source_locale = source
	target_locale = target
	changed.emit()


## The locales the Source dropdown offers: the config's `source_locale` first
## when the CSV has it, then the rest in header order.
func source_choices() -> PackedStringArray:
	var choices: PackedStringArray = locales()
	var preferred: String = config.source_locale if config != null else ""
	if choices.has(preferred):
		choices.remove_at(choices.find(preferred))
		choices.insert(0, preferred)
	return choices


## The locale a new column should be, while Source is empty: the config's
## `source_locale`. "" once there is a source.
func suggested_locale() -> String:
	if config == null or not source_locale.is_empty():
		return ""
	return config.source_locale


## Adds a locale column. It becomes the source while there is none -- a CSV
## with no locale column yet -- and otherwise the target while that is empty
## or the source. False when the name is not a locale code or exists.
func add_locale(locale: String) -> bool:
	if not document.add_locale(locale):
		return false
	_csv_dirty = true
	if source_locale.is_empty():
		source_locale = locale
	elif target_locale.is_empty() or target_locale == source_locale:
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


## Where a new `kind` (`speaker`, `scene`...) called `id` is saved,
## `<folder>/<id>.tres`; "" when it may not be made, with `refusal` saying why:
## no folder, an id another of its kind has (`taken`), or a path already
## claimed. **A path is claimed across kinds**: when the config points several
## folders at one place, a new scene and a new trigger with one id would
## otherwise both be saved as one file, the second over the first.
func new_path(kind: String, folder: String, id: String, taken: bool) -> String:
	refusal = ""
	if folder.is_empty():
		refusal = "the config names no %ss folder" % kind
		return ""
	if taken:
		refusal = "a %s '%s' exists" % [kind, id]
		return ""
	var path: String = folder.path_join(id + ".tres")
	var holder: Resource = _claimant(path)
	if holder != null:
		refusal = "%s is already the file of the %s" % [path, _describe(holder)]
	elif ShantyFiles.exists(path):
		refusal = "%s already exists" % path
	return path if refusal.is_empty() else ""


## True when a config is open and `id` matches `pattern`; otherwise false, with
## `refusal` saying which. The edits classes' first check before `new_path()`.
func accepts_id(id: String, pattern: String) -> bool:
	refusal = ""
	if config == null:
		refusal = "no Shanty config is open"
	elif RegEx.create_from_string(pattern).search(id) == null:
		refusal = "'%s' is not a lower-case id (a-z, 0-9, _)" % id
	return refusal.is_empty()


func is_dirty() -> bool:
	return _csv_dirty or not _dirty.is_empty()


func lint() -> Array[ShantyLintIssue]:
	return ShantyLint.check(document, config, speakers, conversations, scenes, triggers)


## Lints, refuses on an error or a stale file, then writes the CSV and every
## edited resource all or nothing.
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


## Stages every output, then commits them together (`ShantySaveTransaction`):
## any failure leaves every file as it was and every edit still unsaved.
func _write(issues: Array[ShantyLintIssue]) -> ShantySaveResult:
	var transaction := ShantySaveTransaction.new()
	var resources: Array[Resource] = _dirty.duplicate()
	var staged: bool = transaction.claim_paths(_new_paths)
	staged = (
		staged and (not _csv_dirty or transaction.stage_text(config.csv_path, document.to_text()))
	)
	for resource: Resource in resources:
		staged = staged and transaction.stage_resource(resource, path_of(resource))
	var committed: bool = staged and transaction.commit()
	transaction.discard()
	var result := ShantySaveResult.new()
	result.issues = issues
	result.staged_paths = transaction.staged_paths()
	if not committed:
		result.message = "Not saved: %s Every file is as it was." % transaction.failure
		return result
	if _csv_dirty:
		_hashes[config.csv_path] = ShantyFiles.hash_of(config.csv_path)
		result.csv_path = config.csv_path
		_csv_dirty = false
	for resource: Resource in resources:
		var path: String = path_of(resource)
		_hashes[path] = ShantyFiles.hash_of(path)
		_new_paths.erase(resource)
		result.resource_paths.append(path)
	_dirty.clear()
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


## Empties the model, records why, and returns the reason.
func _refuse(why: Problem, reason: String) -> String:
	_reset()
	problem = why
	status = reason
	changed.emit()
	return reason


## Forgets every file read and every edit made.
func _reset() -> void:
	config = null
	document = ShantyCsvDocument.new()
	speakers.clear()
	conversations.clear()
	scenes.clear()
	triggers.clear()
	source_locale = ""
	target_locale = ""
	key_prefixes.clear()
	refusal = ""
	_hashes.clear()
	_dirty.clear()
	_new_paths.clear()
	_csv_dirty = false


func _load_folders(fresh: bool) -> void:
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


## The resource this session holds whose file is `path`, saved or new, or null.
func _claimant(path: String) -> Resource:
	var held: Array[Resource] = []
	held.append_array(speakers)
	held.append_array(conversations)
	held.append_array(scenes)
	held.append_array(triggers)
	for resource: Resource in held:
		if path_of(resource) == path:
			return resource
	return null


## `scene 'lamp'`, `new trigger 'lamp'`: what `resource` is, for a message.
func _describe(resource: Resource) -> String:
	var kind: String = "resource"
	var id: String = ""
	if resource is SpeakerDefinition:
		kind = "speaker"
		id = String((resource as SpeakerDefinition).speaker_id)
	elif resource is ConversationDefinition:
		kind = "conversation"
		id = String((resource as ConversationDefinition).conversation_id)
	elif resource is CutsceneDefinition:
		kind = "scene"
		id = String((resource as CutsceneDefinition).scene_id)
	elif resource is StoryTriggerDefinition:
		kind = "trigger"
		id = String((resource as StoryTriggerDefinition).trigger_id)
	var unsaved: String = "new " if _new_paths.has(resource) else ""
	return "%s%s '%s'" % [unsaved, kind, id]
