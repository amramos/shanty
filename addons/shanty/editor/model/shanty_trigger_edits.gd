@tool
class_name ShantyTriggerEdits
extends RefCounted

## Edits to triggers, over a `ShantyEditorModel`. A trigger names one moment the
## host recognises; when the config lists `trigger_ids` that list is the whole
## set a trigger may name, and when it is empty any lower-case id is allowed.
## Each candidate is a scene from the scenes folder, a priority, `once`, and
## conditions edited in the Inspector. A trigger's file is named for the id it
## was made with; changing the id later leaves the file where it is.
##
## **Every id is a safe file name**, closed set or open: an id from the config
## that is not (`ShantyLintStory.is_safe_stem()`) is refused, so no id can put
## a trigger's file outside the triggers folder.

const ID_PATTERN: String = "^[a-z0-9_]+$"


static func find(model: ShantyEditorModel, id: StringName) -> StoryTriggerDefinition:
	for trigger: StoryTriggerDefinition in model.triggers:
		if trigger.trigger_id == id:
			return trigger
	return null


## True when the config names the whole set of trigger ids.
static func is_closed(model: ShantyEditorModel) -> bool:
	return model.config != null and not model.config.trigger_ids.is_empty()


## The ids a new trigger may take: in a closed set, those no trigger has yet;
## in an open one, nothing to list.
static func free_ids(model: ShantyEditorModel) -> PackedStringArray:
	var free: PackedStringArray = []
	if not is_closed(model):
		return free
	for id: String in model.config.trigger_ids:
		if allows(model, id) and find(model, StringName(id)) == null and not free.has(id):
			free.append(id)
	return free


## True when `id` may name a trigger: one of the closed set, or any lower-case
## id when the set is open -- and, either way, a safe file name.
static func allows(model: ShantyEditorModel, id: String) -> bool:
	return id_refusal(model, id).is_empty()


## Why `id` may not name a trigger, or "" when it may. Whether another trigger
## already has it is not asked here.
static func id_refusal(model: ShantyEditorModel, id: String) -> String:
	if not ShantyLintStory.is_safe_stem(id):
		return "'%s' cannot name a file: use letters, digits, _ and -" % id
	if is_closed(model) and not model.config.trigger_ids.has(id):
		return "'%s' is not one of the config's trigger ids" % id
	if not is_closed(model) and RegEx.create_from_string(ID_PATTERN).search(id) == null:
		return "'%s' is not a lower-case id" % id
	return ""


## A new trigger saved as `<triggers folder>/<id>.tres`. Null, changing
## nothing, for an id the set does not allow, a taken id, an existing file, or
## no config.
static func add_trigger(model: ShantyEditorModel, id: String) -> StoryTriggerDefinition:
	if model.config == null or model.config.triggers_folder.is_empty() or not allows(model, id):
		return null
	var path: String = model.config.triggers_folder.path_join(id + ".tres")
	if find(model, StringName(id)) != null or ShantyFiles.exists(path):
		return null
	var trigger := StoryTriggerDefinition.new()
	trigger.trigger_id = StringName(id)
	model.triggers.append(trigger)
	model.adopt(trigger, path)
	return trigger


## Renames the moment `trigger` answers. False for an id the set does not
## allow or another trigger has.
static func set_id(model: ShantyEditorModel, trigger: StoryTriggerDefinition, id: String) -> bool:
	var other: StoryTriggerDefinition = find(model, StringName(id))
	if not allows(model, id) or (other != null and other != trigger):
		return false
	trigger.trigger_id = StringName(id)
	model.touch(trigger)
	return true


## A new candidate at the end, playing `scene` (which may be null for now).
static func add_candidate(
	model: ShantyEditorModel, trigger: StoryTriggerDefinition, scene: CutsceneDefinition = null
) -> StoryCandidate:
	var candidate := StoryCandidate.new()
	candidate.cutscene = scene
	var candidates: Array[StoryCandidate] = trigger.candidates
	candidates.append(candidate)
	trigger.candidates = candidates
	model.touch(trigger)
	return candidate


## Moves candidate `from` to position `to`. Order matters only to a tie: the
## first authored of equal priorities wins.
static func move_candidate(
	model: ShantyEditorModel, trigger: StoryTriggerDefinition, from: int, to: int
) -> bool:
	var size: int = trigger.candidates.size()
	if from < 0 or from >= size or to < 0 or to >= size or from == to:
		return false
	var candidates: Array[StoryCandidate] = trigger.candidates
	var candidate: StoryCandidate = candidates[from]
	candidates.remove_at(from)
	candidates.insert(to, candidate)
	trigger.candidates = candidates
	model.touch(trigger)
	return true


static func remove_candidate(
	model: ShantyEditorModel, trigger: StoryTriggerDefinition, index: int
) -> bool:
	if index < 0 or index >= trigger.candidates.size():
		return false
	var candidates: Array[StoryCandidate] = trigger.candidates
	candidates.remove_at(index)
	trigger.candidates = candidates
	model.touch(trigger)
	return true


## Sets one value of a candidate (`cutscene`, `priority`, `once`) inside
## `trigger` and marks the trigger edited.
static func edit(
	model: ShantyEditorModel,
	trigger: StoryTriggerDefinition,
	candidate: StoryCandidate,
	property: StringName,
	value: Variant
) -> void:
	candidate.set(property, value)
	model.touch(trigger)


## Sets a candidate's priority from what the writer typed: any whole number a
## 64-bit int holds, as `StoryCandidate.priority` does -- the tab sets no range
## of its own. False, changing nothing, for anything else.
static func set_priority(
	model: ShantyEditorModel,
	trigger: StoryTriggerDefinition,
	candidate: StoryCandidate,
	text: String
) -> bool:
	var written: String = text.strip_edges()
	if not written.is_valid_int() or not _fits_int64(written):
		return false
	edit(model, trigger, candidate, &"priority", written.to_int())
	return true


## True when the whole number `written` is within a 64-bit int; `to_int()`
## would clamp one beyond it without a word to the writer.
static func _fits_int64(written: String) -> bool:
	var negative: bool = written.begins_with("-")
	var digits: String = written.trim_prefix("-").trim_prefix("+").lstrip("0")
	var limit: String = "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() != limit.length():
		return digits.length() < limit.length()
	return digits <= limit


## A new condition of the script at `script_path` on `candidate`; null when the
## script does not extend ShantyCondition.
static func add_condition(
	model: ShantyEditorModel,
	trigger: StoryTriggerDefinition,
	candidate: StoryCandidate,
	script_path: String
) -> ShantyCondition:
	var condition: ShantyCondition = ShantyFiles.instantiate(script_path) as ShantyCondition
	if condition == null:
		return null
	var conditions: Array[ShantyCondition] = candidate.conditions
	conditions.append(condition)
	candidate.conditions = conditions
	model.touch(trigger)
	return condition


static func remove_condition(
	model: ShantyEditorModel, trigger: StoryTriggerDefinition, candidate: StoryCandidate, index: int
) -> bool:
	if index < 0 or index >= candidate.conditions.size():
		return false
	var conditions: Array[ShantyCondition] = candidate.conditions
	conditions.remove_at(index)
	candidate.conditions = conditions
	model.touch(trigger)
	return true
