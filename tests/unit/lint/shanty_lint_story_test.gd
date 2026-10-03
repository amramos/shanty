extends GutTest

## ShantyLint's scene and trigger rules (ShantyLintStory), one at a time, over a
## clean scene and trigger that each test breaks in exactly one way.

const CSV: String = "keys,en\nSPEAKER_ANA,Ana\nTALK_01,Hello.\nTITLE,A title\n"


func _speakers() -> Array[SpeakerDefinition]:
	var speaker := SpeakerDefinition.new()
	speaker.speaker_id = &"ana"
	speaker.name_key = "SPEAKER_ANA"
	return [speaker]


func _conversation() -> ConversationDefinition:
	var line := DialogueLine.new()
	line.speaker_id = &"ana"
	line.text_key = "TALK_01"
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = &"talk"
	conversation.lines = [line]
	return conversation


func _scene(id: StringName = &"opening") -> CutsceneDefinition:
	var say := SayStep.new()
	say.conversation = _conversation()
	var scene := CutsceneDefinition.new()
	scene.scene_id = id
	scene.title_key = "TITLE"
	scene.steps = [BackdropStep.new(), FadeStep.new(), say]
	return scene


func _trigger(id: StringName, scenes: Array[CutsceneDefinition]) -> StoryTriggerDefinition:
	var trigger := StoryTriggerDefinition.new()
	trigger.trigger_id = id
	for scene: CutsceneDefinition in scenes:
		var candidate := StoryCandidate.new()
		candidate.cutscene = scene
		trigger.candidates.append(candidate)
	return trigger


func _check(
	scenes: Array[CutsceneDefinition],
	triggers: Array[StoryTriggerDefinition],
	config: ShantyProjectConfig = ShantyProjectConfig.new()
) -> Array[ShantyLintIssue]:
	return ShantyLint.check(ShantyCsvDocument.parse(CSV), config, _speakers(), [], scenes, triggers)


func _rules(issues: Array[ShantyLintIssue]) -> PackedStringArray:
	var rules: PackedStringArray = []
	for issue: ShantyLintIssue in issues:
		rules.append("%s:%s" % [issue.rule, "error" if issue.is_error() else "warning"])
	return rules


func test_a_clean_scene_and_trigger_lint_clean() -> void:
	var scene: CutsceneDefinition = _scene()

	assert_eq(_rules(_check([scene], [_trigger(&"start", [scene])])), PackedStringArray())


func test_an_unbuilt_step_makes_the_scene_unplayable() -> void:
	for unbuilt: CutsceneStep in [AnimateStep.new(), VideoStep.new()]:
		var scene: CutsceneDefinition = _scene()
		scene.steps.append(unbuilt)
		var issues: Array[ShantyLintIssue] = _check([scene], [])

		assert_eq(_rules(issues), PackedStringArray(["unplayable_scene:error"]))
		assert_string_contains(issues[0].message, "step 4")
		assert_string_contains(issues[0].message, ShantyLintStory.type_name(unbuilt))


func test_a_say_step_whose_conversation_loops_makes_the_scene_unplayable() -> void:
	var scene: CutsceneDefinition = _scene()
	var conversation: ConversationDefinition = (scene.steps[2] as SayStep).conversation
	var line: DialogueLine = conversation.lines[0]
	line.label = &"top"
	var choice := DialogueChoice.new()
	choice.text_key = "TALK_01"
	choice.jump_label = &"top"
	line.choices = [choice]
	var issues: Array[ShantyLintIssue] = _check([scene], [])

	assert_eq(_rules(issues), PackedStringArray(["unplayable_scene:error"]))
	assert_string_contains(issues[0].message, "can loop")
	assert_false(scene.is_playable(), "the lint and the player agree")


func test_in_the_editor_the_check_asks_a_working_copy_that_holds_the_steps_values() -> void:
	var fade := FadeStep.new()
	fade.to_black = false
	fade.duration = 0.25
	var copy: FadeStep = ShantyLintStory.working_copy(fade, true) as FadeStep

	assert_ne(copy, fade, "a fresh instance, which runs even where the authored one cannot")
	assert_false(copy.to_black)
	assert_eq(copy.duration, 0.25)


func test_outside_the_editor_the_check_asks_the_step_itself() -> void:
	var fade := FadeStep.new()

	assert_false(Engine.is_editor_hint(), "the suite runs outside the editor")
	assert_same(ShantyLintStory.working_copy(fade), fade, "its script runs: nothing is copied")


func test_a_trigger_id_outside_a_closed_set_is_an_error() -> void:
	var scene: CutsceneDefinition = _scene()
	var config := ShantyProjectConfig.new()
	config.trigger_ids = ["start", "door_opened"]

	assert_eq(_rules(_check([scene], [_trigger(&"start", [scene])], config)), PackedStringArray())
	assert_eq(
		_rules(_check([scene], [_trigger(&"elsewhere", [scene])], config)),
		PackedStringArray(["unknown_trigger:error"])
	)
	assert_eq(
		_rules(_check([scene], [_trigger(&"elsewhere", [scene])])),
		PackedStringArray(),
		"an empty set allows any id"
	)
	assert_eq(
		_rules(_check([scene], [_trigger(&"", [scene])])),
		PackedStringArray(["unknown_trigger:error"]),
		"no id is an error either way"
	)


func test_two_triggers_with_one_id_are_an_error() -> void:
	var scene: CutsceneDefinition = _scene()

	assert_eq(
		_rules(_check([scene], [_trigger(&"start", [scene]), _trigger(&"start", [scene])])),
		PackedStringArray(["duplicate_trigger:error"])
	)


func test_an_unknown_id_on_two_triggers_is_both_unknown_and_duplicated() -> void:
	var scene: CutsceneDefinition = _scene()
	var config := ShantyProjectConfig.new()
	config.trigger_ids = ["start"]
	var triggers: Array[StoryTriggerDefinition] = [
		_trigger(&"elsewhere", [scene]), _trigger(&"elsewhere", [scene])
	]

	assert_eq(
		_rules(_check([scene], triggers, config)),
		PackedStringArray(
			["unknown_trigger:error", "unknown_trigger:error", "duplicate_trigger:error"]
		)
	)


func test_a_config_trigger_id_that_cannot_name_a_file_is_flagged() -> void:
	var scene: CutsceneDefinition = _scene()
	var config := ShantyProjectConfig.new()
	config.trigger_ids = ["start", "../outside", "a/b", "", "fine-Id_2"]
	var issues: Array[ShantyLintIssue] = _check([scene], [_trigger(&"start", [scene])], config)

	assert_eq(
		_rules(issues),
		PackedStringArray(
			[
				"unsafe_trigger_id:warning",
				"unsafe_trigger_id:warning",
				"unsafe_trigger_id:warning",
			]
		)
	)
	assert_string_contains(issues[0].message, "'../outside'")
	for id: String in ["start", "fine-Id_2", "Door-1"]:
		assert_true(ShantyLintStory.is_safe_stem(id), id)
	for id: String in ["../outside", "..", ".", "a/b", "a\\b", "", "a.b", "res://x"]:
		assert_false(ShantyLintStory.is_safe_stem(id), id)


func test_a_trigger_with_no_candidate_is_a_warning() -> void:
	assert_eq(
		_rules(_check([_scene()], [_trigger(&"start", [])])),
		PackedStringArray(["empty_trigger:warning"])
	)


func test_a_candidate_with_no_scene_or_one_outside_the_folder_is_an_error() -> void:
	var listed: CutsceneDefinition = _scene()
	var elsewhere: CutsceneDefinition = _scene(&"elsewhere")
	var trigger: StoryTriggerDefinition = _trigger(&"start", [listed, elsewhere])
	trigger.candidates.append(StoryCandidate.new())
	var issues: Array[ShantyLintIssue] = _check([listed], [trigger])

	assert_eq(_rules(issues), PackedStringArray(["unknown_scene:error", "unknown_scene:error"]))
	assert_string_contains(issues[0].message, "elsewhere")
	assert_string_contains(issues[1].message, "no scene")


func test_one_scene_on_two_candidates_is_a_warning() -> void:
	var scene: CutsceneDefinition = _scene()

	assert_eq(
		_rules(_check([scene], [_trigger(&"start", [scene, scene])])),
		PackedStringArray(["duplicate_candidate:warning"])
	)


func test_a_scene_is_known_by_its_file_as_well_as_by_identity() -> void:
	var listed: CutsceneDefinition = _scene()
	listed.resource_path = "res://story/opening.tres"
	var copy: CutsceneDefinition = _scene()
	copy.resource_path = "res://story/opening_copy.tres"

	assert_true(ShantyLintStory.is_listed(listed, [listed]))
	assert_false(ShantyLintStory.is_listed(copy, [listed]))
