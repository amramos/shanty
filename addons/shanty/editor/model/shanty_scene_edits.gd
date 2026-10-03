@tool
class_name ShantySceneEdits
extends RefCounted

## Edits to scenes, over a `ShantyEditorModel`. A scene's title and synopsis are
## keys in the same CSV as every line, named by the scheme's scene patterns and
## given their rows as one contiguous block after the other scenes' rows. Its
## steps are added, inserted, moved and removed here; a step's still or
## conversation is set here too (`set_step_property()`), its other values in the
## Inspector, and each step is summarised for its row by `summary()`.

const ID_PATTERN: String = "^[a-z0-9_]+$"
## The two key properties a scene carries, in the order their rows are written.
const KEY_PROPERTIES: Array[StringName] = [&"title_key", &"synopsis_key"]


static func find(model: ShantyEditorModel, id: StringName) -> CutsceneDefinition:
	for scene: CutsceneDefinition in model.scenes:
		if scene.scene_id == id:
			return scene
	return null


## A new scene saved as `<scenes folder>/<id>.tres`, its title and synopsis keys
## named by the scheme with their two rows together after the other scenes'.
## Null, changing nothing and with `model.refusal` saying why, for a bad or
## taken id, a file that exists or that anything else this session claimed, or
## no config.
static func add_scene(model: ShantyEditorModel, id: String) -> CutsceneDefinition:
	if not model.accepts_id(id, ID_PATTERN):
		return null
	var path: String = model.new_path(
		"scene", model.config.scenes_folder, id, find(model, StringName(id)) != null
	)
	if path.is_empty():
		return null
	var scene := CutsceneDefinition.new()
	scene.scene_id = StringName(id)
	model.scenes.append(scene)
	for property: StringName in KEY_PROPERTIES:
		add_key(model, scene, property)
	model.adopt(scene, path)
	return scene


## Every title and synopsis key the model's scenes name, in list order.
static func scene_keys(model: ShantyEditorModel) -> PackedStringArray:
	var keys: PackedStringArray = []
	for scene: CutsceneDefinition in model.scenes:
		for property: StringName in KEY_PROPERTIES:
			var key: String = scene.get(property)
			if not key.is_empty():
				keys.append(key)
	return keys


## Gives `scene` its title or synopsis key (`property`), named by the scheme,
## and a row after the last scene row -- or shares the row when the CSV already
## has that key. False when the scene already has one.
static func add_key(
	model: ShantyEditorModel, scene: CutsceneDefinition, property: StringName
) -> bool:
	if not KEY_PROPERTIES.has(property) or not String(scene.get(property)).is_empty():
		return false
	var scheme: ShantyKeyScheme = model.config.scheme()
	var id: String = String(scene.scene_id)
	var key: String = scheme.title_key(id) if property == &"title_key" else scheme.synopsis_key(id)
	if not model.document.has_key(key):
		model.add_row(key, model.document.last_of(scene_keys(model)))
	scene.set(property, key)
	model.touch(scene)
	return true


## Takes `scene`'s title or synopsis key away, and its row when nothing else
## names it. A scene with no synopsis shows none.
static func remove_key(
	model: ShantyEditorModel, scene: CutsceneDefinition, property: StringName
) -> bool:
	var key: String = scene.get(property) if KEY_PROPERTIES.has(property) else ""
	if key.is_empty():
		return false
	scene.set(property, "")
	if not scene_keys(model).has(key) and not _named_elsewhere(model, key):
		model.remove_row(key)
	model.touch(scene)
	return true


## Sets one of the scene's own values (`skippable`, `remembered`).
static func edit(
	model: ShantyEditorModel, scene: CutsceneDefinition, property: StringName, value: Variant
) -> void:
	scene.set(property, value)
	model.touch(scene)


## A new step of the script at `script_path` at the end of the scene.
static func add_step(
	model: ShantyEditorModel, scene: CutsceneDefinition, script_path: String
) -> CutsceneStep:
	return insert_step_after(model, scene, scene.steps.size() - 1, script_path)


## A new step of the script at `script_path` straight after step `index` (at
## the start for -1). Null, changing nothing, for an index outside the scene, a
## script that is not a step, or a step type this version does not build.
static func insert_step_after(
	model: ShantyEditorModel, scene: CutsceneDefinition, index: int, script_path: String
) -> CutsceneStep:
	if index < -1 or index >= scene.steps.size():
		return null
	var step: CutsceneStep = ShantyFiles.instantiate(script_path) as CutsceneStep
	if step == null or not ShantyLintStory.working_copy(step).is_built():
		return null
	var steps: Array[CutsceneStep] = scene.steps
	steps.insert(index + 1, step)
	scene.steps = steps
	model.touch(scene)
	return step


## Moves step `from` to position `to`; every other step keeps its order.
static func move_step(
	model: ShantyEditorModel, scene: CutsceneDefinition, from: int, to: int
) -> bool:
	var size: int = scene.steps.size()
	if from < 0 or from >= size or to < 0 or to >= size or from == to:
		return false
	var steps: Array[CutsceneStep] = scene.steps
	var step: CutsceneStep = steps[from]
	steps.remove_at(from)
	steps.insert(to, step)
	scene.steps = steps
	model.touch(scene)
	return true


static func remove_step(model: ShantyEditorModel, scene: CutsceneDefinition, index: int) -> bool:
	if index < 0 or index >= scene.steps.size():
		return false
	var steps: Array[CutsceneStep] = scene.steps
	steps.remove_at(index)
	scene.steps = steps
	model.touch(scene)
	return true


## Sets one value of step `index` -- a Backdrop's `texture`, a Say's
## `conversation` -- and marks the scene edited. False, changing nothing, for an
## index outside the scene, a property the step does not have, or a value the
## property cannot hold.
static func set_step_property(
	model: ShantyEditorModel,
	scene: CutsceneDefinition,
	index: int,
	property: StringName,
	value: Variant
) -> bool:
	if index < 0 or index >= scene.steps.size() or scene.steps[index] == null:
		return false
	var step: CutsceneStep = scene.steps[index]
	if not _has_property(step, property):
		return false
	var before: Variant = step.get(property)
	step.set(property, value)
	if step.get(property) != value:
		step.set(property, before)
		return false
	model.touch(scene)
	return true


## The conversation a Say step plays, or null for any other step.
static func conversation_of(step: CutsceneStep) -> ConversationDefinition:
	return (step as SayStep).conversation if step is SayStep else null


## One line for a step's row: `Say: lamp_talk`, `Backdrop: dawn.png, letterbox`,
## `Fade in 0.5 s`. Read from the step's values only, so it is right for a step
## the editor loaded as a placeholder.
static func summary(step: CutsceneStep) -> String:
	if step == null:
		return "(empty step)"
	if step is SayStep:
		var conversation: ConversationDefinition = conversation_of(step)
		var id: String = String(conversation.conversation_id) if conversation != null else ""
		return "Say: %s" % (id if not id.is_empty() else "(no conversation)")
	if step is BackdropStep:
		var backdrop: BackdropStep = step
		var still: String = _file_name(backdrop.texture, "ground colour")
		return "Backdrop: %s%s" % [still, ", letterbox" if backdrop.letterbox else ""]
	if step is FadeStep:
		var fade: FadeStep = step
		return "Fade %s %s s" % ["out" if fade.to_black else "in", _seconds(fade.duration)]
	if step is WaitStep:
		var wait: WaitStep = step
		return "Wait %s s%s" % [_seconds(wait.seconds), ", no tap" if wait.uninterruptible else ""]
	if step is PanStep:
		var pan: PanStep = step
		return (
			"Pan (%d, %d) → (%d, %d), %s s"
			% [
				pan.from_offset.x,
				pan.from_offset.y,
				pan.to_offset.x,
				pan.to_offset.y,
				_seconds(pan.duration)
			]
		)
	if step is MusicStep:
		var music: MusicStep = step
		if music.mode == MusicStep.Mode.DUCK:
			return "Music: duck %s dB, %s s" % [_seconds(music.duck_db), _seconds(music.duration)]
		if music.stream == null:
			return "Music: silence"
		return "Music: swap to %s" % _file_name(music.stream, "")
	return ShantyLintStory.type_name(step)


## `0.5`, `2`: a whole number of seconds without its `.0`.
static func _seconds(value: float) -> String:
	var text: String = String.num(value, 2)
	return text.trim_suffix(".0")


static func _file_name(resource: Resource, fallback: String) -> String:
	if resource == null:
		return fallback
	var file: String = resource.resource_path.get_file()
	return file if not file.is_empty() and not file.contains("::") else resource.get_class()


static func _has_property(step: CutsceneStep, property: StringName) -> bool:
	for entry: Dictionary in step.get_property_list():
		if StringName(entry["name"]) == property:
			return true
	return false


## True when a speaker or a conversation names `key`, so its row must stay.
static func _named_elsewhere(model: ShantyEditorModel, key: String) -> bool:
	for speaker: SpeakerDefinition in model.speakers:
		if speaker.name_key == key:
			return true
	for conversation: ConversationDefinition in model.conversations:
		if ShantyConversationEdits.keys_of(conversation).has(key):
			return true
	return false
