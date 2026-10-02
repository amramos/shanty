extends GutTest

## Trigger edits over the model: an id from the config's closed set or, with no
## set, any lower-case id; candidates added, moved and removed without touching
## the others; their scene, priority, `once` and conditions; and Save writing the
## trigger, refused like any other file someone changed on disk.

const Fixture := preload("res://tests/support/editor_fixture.gd")

var _model: ShantyEditorModel
var _scene: CutsceneDefinition


func before_each() -> void:
	_model = Fixture.open_model()
	_scene = ShantySceneEdits.add_scene(_model, "opening")


func after_each() -> void:
	_model = null
	_scene = null


func after_all() -> void:
	Fixture.remove()


func test_with_no_set_any_lower_case_id_makes_a_trigger() -> void:
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "door_opened")

	assert_false(ShantyTriggerEdits.is_closed(_model))
	assert_eq(trigger.trigger_id, &"door_opened")
	assert_eq(_model.path_of(trigger), Fixture.TRIGGERS + "/door_opened.tres")
	assert_null(ShantyTriggerEdits.add_trigger(_model, "door_opened"), "a taken id is refused")
	assert_null(ShantyTriggerEdits.add_trigger(_model, "Door Opened"))
	assert_eq(ShantyTriggerEdits.free_ids(_model), PackedStringArray(), "nothing to list")


func test_a_closed_set_is_the_only_source_of_ids() -> void:
	_model.config.trigger_ids = ["chapter_start", "door_opened"]

	assert_true(ShantyTriggerEdits.is_closed(_model))
	assert_null(ShantyTriggerEdits.add_trigger(_model, "elsewhere"), "outside the set")
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "door_opened")
	assert_not_null(trigger)
	assert_eq(ShantyTriggerEdits.free_ids(_model), PackedStringArray(["chapter_start"]))
	assert_false(ShantyTriggerEdits.set_id(_model, trigger, "elsewhere"))
	assert_true(ShantyTriggerEdits.set_id(_model, trigger, "chapter_start"))
	assert_eq(ShantyTriggerEdits.free_ids(_model), PackedStringArray(["door_opened"]))


func test_candidates_are_added_moved_and_removed_without_touching_the_others() -> void:
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "start")
	var first: StoryCandidate = ShantyTriggerEdits.add_candidate(_model, trigger, _scene)
	var second: StoryCandidate = ShantyTriggerEdits.add_candidate(_model, trigger)
	var third: StoryCandidate = ShantyTriggerEdits.add_candidate(_model, trigger)

	assert_true(ShantyTriggerEdits.move_candidate(_model, trigger, 2, 0))
	assert_eq(trigger.candidates, [third, first, second] as Array[StoryCandidate])
	assert_false(ShantyTriggerEdits.move_candidate(_model, trigger, 0, 3))
	assert_true(ShantyTriggerEdits.remove_candidate(_model, trigger, 0))
	assert_eq(trigger.candidates, [first, second] as Array[StoryCandidate])
	assert_false(ShantyTriggerEdits.remove_candidate(_model, trigger, 2))


func test_a_candidates_values_and_conditions_are_edited() -> void:
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "start")
	var candidate: StoryCandidate = ShantyTriggerEdits.add_candidate(_model, trigger)
	ShantyTriggerEdits.edit(_model, trigger, candidate, &"cutscene", _scene)
	ShantyTriggerEdits.edit(_model, trigger, candidate, &"priority", 3)
	ShantyTriggerEdits.edit(_model, trigger, candidate, &"once", false)

	assert_eq(candidate.cutscene, _scene)
	assert_eq(candidate.priority, 3)
	assert_false(candidate.once)
	assert_not_null(
		ShantyTriggerEdits.add_condition(_model, trigger, candidate, Fixture.CONDITION_SCRIPT)
	)
	assert_null(ShantyTriggerEdits.add_condition(_model, trigger, candidate, Fixture.EFFECT_SCRIPT))
	assert_eq(candidate.conditions.size(), 1)
	assert_true(ShantyTriggerEdits.remove_condition(_model, trigger, candidate, 0))
	assert_eq(candidate.conditions.size(), 0)


func test_a_saved_trigger_round_trips_with_its_candidates() -> void:
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "start")
	var candidate: StoryCandidate = ShantyTriggerEdits.add_candidate(_model, trigger, _scene)
	ShantyTriggerEdits.edit(_model, trigger, candidate, &"priority", 2)
	ShantyTriggerEdits.add_condition(_model, trigger, candidate, Fixture.CONDITION_SCRIPT)
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	var reopened := ShantyEditorModel.new()
	reopened.open(Fixture.config(), true)
	var loaded: StoryTriggerDefinition = ShantyTriggerEdits.find(reopened, &"start")
	assert_not_null(loaded)
	assert_eq(loaded.candidates.size(), 1)
	assert_eq(loaded.candidates[0].priority, 2)
	assert_eq(loaded.candidates[0].cutscene.scene_id, &"opening")
	assert_eq(loaded.candidates[0].conditions.size(), 1)
	assert_eq(ShantyLint.errors_in(reopened.lint()), [] as Array[ShantyLintIssue])


func test_a_trigger_changed_on_disk_refuses_the_save() -> void:
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "start")
	assert_true(_model.save().saved)
	var theirs := StoryTriggerDefinition.new()
	theirs.trigger_id = &"their_moment"
	ResourceSaver.save(theirs, Fixture.TRIGGERS + "/start.tres")
	ShantyTriggerEdits.add_candidate(_model, trigger, _scene)
	var result: ShantySaveResult = _model.save()

	assert_false(result.saved)
	assert_eq(result.stale_paths, PackedStringArray([Fixture.TRIGGERS + "/start.tres"]))


func test_lint_marks_a_candidate_with_no_scene() -> void:
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(_model, "start")
	ShantyTriggerEdits.add_candidate(_model, trigger)
	var rules: Array[StringName] = []
	for issue: ShantyLintIssue in ShantyLint.errors_in(_model.lint()):
		rules.append(issue.rule)

	assert_eq(rules, [ShantyLint.RULE_UNKNOWN_SCENE] as Array[StringName])
	assert_false(_model.save().saved, "an error refuses Save")
