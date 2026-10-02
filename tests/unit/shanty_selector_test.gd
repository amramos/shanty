extends GutTest

## ShantySelector over Shanty-only fixtures: the highest priority
## among the candidates whose conditions hold and that have not played when
## `once`, the first authored on a tie, and null when nothing qualifies.


class Flag:
	extends ShantyCondition

	var holds: bool = true

	func evaluate(_context: ShantyContext) -> bool:
		return holds


func _candidate(scene_id: StringName, priority: int = 0, once: bool = true) -> StoryCandidate:
	var scene := CutsceneDefinition.new()
	scene.scene_id = scene_id
	var candidate := StoryCandidate.new()
	candidate.cutscene = scene
	candidate.priority = priority
	candidate.once = once
	return candidate


func _trigger(candidates: Array[StoryCandidate]) -> StoryTriggerDefinition:
	var trigger := StoryTriggerDefinition.new()
	trigger.trigger_id = &"test"
	trigger.candidates = candidates
	return trigger


func _played(scene_id: StringName) -> Array[PlayedSceneRecord]:
	var record := PlayedSceneRecord.new()
	record.scene_id = scene_id
	var records: Array[PlayedSceneRecord] = [record]
	return records


func _id(candidate: StoryCandidate) -> StringName:
	return candidate.cutscene.scene_id if candidate != null else &""


func test_the_highest_priority_wins_wherever_it_is_authored() -> void:
	var trigger := _trigger([_candidate(&"low", 1), _candidate(&"high", 5), _candidate(&"mid", 3)])
	assert_eq(_id(ShantySelector.select(trigger, null, [])), &"high")


func test_a_tie_goes_to_the_first_authored() -> void:
	var trigger := _trigger([_candidate(&"first", 2), _candidate(&"second", 2)])
	assert_eq(_id(ShantySelector.select(trigger, null, [])), &"first")


func test_a_candidate_whose_condition_fails_is_passed_over() -> void:
	var gated: StoryCandidate = _candidate(&"gated", 9)
	var closed := Flag.new()
	closed.holds = false
	gated.conditions.append(closed)
	var trigger := _trigger([gated, _candidate(&"open", 1)])
	assert_eq(_id(ShantySelector.select(trigger, null, [])), &"open")


func test_a_once_candidate_that_has_played_is_passed_over_and_a_repeating_one_is_not() -> void:
	var trigger := _trigger([_candidate(&"once", 5), _candidate(&"again", 1, false)])
	assert_eq(_id(ShantySelector.select(trigger, null, _played(&"once"))), &"again")
	assert_eq(
		_id(
			ShantySelector.select(
				_trigger([_candidate(&"again", 1, false)]), null, _played(&"again")
			)
		),
		&"again",
		"once = false plays every time it qualifies"
	)


func test_nothing_qualifying_is_null() -> void:
	assert_null(ShantySelector.select(null, null, []), "no trigger")
	assert_null(ShantySelector.select(_trigger([]), null, []), "no candidates")
	var empty := StoryCandidate.new()
	assert_null(ShantySelector.select(_trigger([empty, null]), null, []), "no scenes")
	assert_null(
		ShantySelector.select(_trigger([_candidate(&"once")]), null, _played(&"once")), "all played"
	)


func test_has_candidates_counts_only_candidates_with_a_scene() -> void:
	assert_false(ShantySelector.has_candidates(null))
	assert_false(ShantySelector.has_candidates(_trigger([StoryCandidate.new()])))
	assert_true(ShantySelector.has_candidates(_trigger([_candidate(&"any")])))
