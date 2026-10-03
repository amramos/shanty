@tool
class_name ShantyLintStory
extends RefCounted

## `ShantyLint`'s checks on scenes and triggers: a scene the player would refuse,
## and a trigger whose moment or candidates do not hold together. Pure, like the
## rest of `lint/`: everything it reads is handed in.
##
## **Asked of a working copy, never of the authored step.** Inside the editor a
## step loaded from disk carries a placeholder script that answers no method,
## so each step is copied into a fresh instance of its own script -- which does
## run there -- and that copy is asked `is_built()` and `is_well_formed()`, the
## same questions `CutsceneDefinition.is_playable()` asks before a scene plays.
## Outside the editor the authored step runs and is asked directly.

## A trigger id must also be a file name: the tab saves a new trigger as
## `<id>.tres` in the triggers folder, so an id is letters, digits, `_` and `-`
## -- never a separator, a dot or `..`.
const SAFE_STEM_PATTERN: String = "^[A-Za-z0-9_-]+$"


## A scene the player would refuse before it starts: a step this version does
## not build, or a step whose data cannot play safely (a conversation that can
## loop).
static func check_scenes(scenes: Array[CutsceneDefinition], issues: Array[ShantyLintIssue]) -> void:
	for scene: CutsceneDefinition in scenes:
		if scene == null:
			continue
		var where: String = ShantyLint.location_of(scene, scene.scene_id)
		for index: int in scene.steps.size():
			var step: CutsceneStep = scene.steps[index]
			if step == null:
				continue
			var reason: String = unplayable_reason(step)
			if not reason.is_empty():
				issues.append(
					ShantyLintIssue.error(
						ShantyLint.RULE_UNPLAYABLE_SCENE,
						"step %d: %s; the player refuses the whole scene" % [index + 1, reason],
						"",
						where
					)
				)


## Why `step` would make its scene unplayable, or "" when it would not.
static func unplayable_reason(step: CutsceneStep) -> String:
	var working: CutsceneStep = working_copy(step)
	if not working.is_built():
		return "%s is declared but not built in this version" % type_name(step)
	if not working.is_well_formed():
		if step is SayStep:
			return "its conversation can loop"
		return "%s holds data it cannot play" % type_name(step)
	return ""


## Triggers: an id the host's closed set does not name (or none), one id on two
## triggers, a trigger with no candidate, a candidate with no scene or one the
## scenes folder does not hold, and one scene on two candidates of a trigger.
static func check_triggers(
	config: ShantyProjectConfig,
	scenes: Array[CutsceneDefinition],
	triggers: Array[StoryTriggerDefinition],
	issues: Array[ShantyLintIssue]
) -> void:
	var allowed: PackedStringArray = config.trigger_ids if config != null else PackedStringArray()
	_check_config_ids(config, allowed, issues)
	var seen: Dictionary[StringName, bool] = {}
	for trigger: StoryTriggerDefinition in triggers:
		if trigger == null:
			continue
		var where: String = ShantyLint.location_of(trigger, trigger.trigger_id)
		_check_id(trigger, allowed, seen, where, issues)
		if trigger.candidates.is_empty():
			issues.append(
				ShantyLintIssue.warning(
					ShantyLint.RULE_EMPTY_TRIGGER,
					"no candidate: this moment always plays nothing",
					"",
					where
				)
			)
		_check_candidates(trigger, scenes, where, issues)


## True when `id` can name a file in a folder and nothing outside it.
static func is_safe_stem(id: String) -> bool:
	return RegEx.create_from_string(SAFE_STEM_PATTERN).search(id) != null


## A closed set's id that could not be a trigger's file name: the tab never
## offers it, so no trigger can be made for that moment.
static func _check_config_ids(
	config: ShantyProjectConfig, allowed: PackedStringArray, issues: Array[ShantyLintIssue]
) -> void:
	for id: String in allowed:
		if not is_safe_stem(id):
			(
				issues
				. append(
					(
						ShantyLintIssue
						. warning(
							ShantyLint.RULE_UNSAFE_TRIGGER_ID,
							(
								"the config's trigger id '%s' cannot name a file: use letters, digits, _ and -"
								% id
							),
							"",
							ShantyLint.location_of(config, &"config")
						)
					)
				)
			)


static func _check_id(
	trigger: StoryTriggerDefinition,
	allowed: PackedStringArray,
	seen: Dictionary[StringName, bool],
	where: String,
	issues: Array[ShantyLintIssue]
) -> void:
	var id: StringName = trigger.trigger_id
	if id.is_empty():
		issues.append(
			ShantyLintIssue.error(
				ShantyLint.RULE_UNKNOWN_TRIGGER, "the trigger has no id", "", where
			)
		)
		return
	if not allowed.is_empty() and not allowed.has(String(id)):
		issues.append(
			ShantyLintIssue.error(
				ShantyLint.RULE_UNKNOWN_TRIGGER,
				"'%s' is not one of the config's trigger ids" % id,
				"",
				where
			)
		)
	# Counted apart from the check above: an unknown id on two triggers is both.
	if seen.has(id):
		issues.append(
			ShantyLintIssue.error(
				ShantyLint.RULE_DUPLICATE_TRIGGER,
				"another trigger already has the id '%s'" % id,
				"",
				where
			)
		)
	seen[id] = true


static func _check_candidates(
	trigger: StoryTriggerDefinition,
	scenes: Array[CutsceneDefinition],
	where: String,
	issues: Array[ShantyLintIssue]
) -> void:
	var named: Array[CutsceneDefinition] = []
	for index: int in trigger.candidates.size():
		var candidate: StoryCandidate = trigger.candidates[index]
		if candidate == null:
			continue
		var at: String = "%s candidate %d" % [where, index + 1]
		var scene: CutsceneDefinition = candidate.cutscene
		if scene == null or not is_listed(scene, scenes):
			var problem: String = (
				"the candidate names no scene"
				if scene == null
				else "the scenes folder holds no '%s'" % scene.scene_id
			)
			issues.append(ShantyLintIssue.error(ShantyLint.RULE_UNKNOWN_SCENE, problem, "", at))
			continue
		if named.has(scene):
			# A warning, not an error: one scene behind two different gates is
			# a legitimate "either of these" -- but more often a slip.
			issues.append(
				ShantyLintIssue.warning(
					ShantyLint.RULE_DUPLICATE_CANDIDATE,
					"another candidate of this trigger already names '%s'" % scene.scene_id,
					"",
					at
				)
			)
		named.append(scene)


## True when `scene` is one of `scenes`, by identity or by file.
static func is_listed(scene: CutsceneDefinition, scenes: Array[CutsceneDefinition]) -> bool:
	if scenes.has(scene):
		return true
	if scene.resource_path.is_empty():
		return false
	for listed: CutsceneDefinition in scenes:
		if listed != null and listed.resource_path == scene.resource_path:
			return true
	return false


## Inside the editor, a fresh instance of `step`'s script holding a copy of its
## stored values: a real instance, where the authored one may be a placeholder.
## Outside it -- a game, a headless test -- `step` itself, whose script runs, so
## nothing is copied. `step` itself too when its script cannot be instanced.
## `in_editor` is for the tests, which run outside the editor.
static func working_copy(
	step: CutsceneStep, in_editor: bool = Engine.is_editor_hint()
) -> CutsceneStep:
	var script: GDScript = step.get_script() as GDScript
	if not in_editor or script == null:
		return step
	var copy: CutsceneStep = script.new() as CutsceneStep
	if copy == null:
		return step
	for property: Dictionary in step.get_property_list():
		var usage: int = int(property["usage"])
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			copy.set(property["name"], step.get(property["name"]))
	return copy


## A step's type as a writer knows it: its script's `class_name`, else the
## script's file name.
static func type_name(step: Resource) -> String:
	var script: Script = step.get_script() as Script
	if script == null:
		return step.get_class()
	if not String(script.get_global_name()).is_empty():
		return String(script.get_global_name())
	return script.resource_path.get_file().get_basename()
