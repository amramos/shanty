extends GutTest

## ShantyRunner over Shanty-only fixtures: the tests never load a host's data.
## The load-bearing case is the last group: a skipped conversation must return
## exactly the effects a played one does.


## A condition that never holds, so a gated line can be proved skipped.
class NeverCondition:
	extends ShantyCondition

	func evaluate(_context: ShantyContext) -> bool:
		return false


## A condition that holds when the context holds `key`.
class HeldCondition:
	extends ShantyCondition

	var key: StringName = &""

	func evaluate(context: ShantyContext) -> bool:
		return context.has_key(key)


class KeyContext:
	extends ShantyContext

	var keys: Array[StringName] = []

	func has_key(id: StringName) -> bool:
		return keys.has(id)


func _line(text_key: String, label: StringName = &"") -> DialogueLine:
	var line := DialogueLine.new()
	line.text_key = text_key
	line.label = label
	line.effects.append(ShantyEffect.new())
	return line


func _choice(text_key: String, jump_label: StringName = &"") -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.text_key = text_key
	choice.jump_label = jump_label
	choice.effects.append(ShantyEffect.new())
	return choice


func _conversation(lines: Array[DialogueLine]) -> ConversationDefinition:
	var conversation := ConversationDefinition.new()
	conversation.lines = lines
	return conversation


## a -> b (two replies: one jumps to d, one falls through to c) -> c -> d.
func _branching() -> ConversationDefinition:
	var question: DialogueLine = _line("b")
	question.choices.append(_choice("b_fall_through"))
	question.choices.append(_choice("b_jump", &"end_label"))
	return _conversation([_line("a"), question, _line("c"), _line("d", &"end_label")])


func _played_keys(runner: ShantyRunner) -> PackedStringArray:
	var keys := PackedStringArray()
	while not runner.is_finished():
		keys.append(runner.current().text_key)
		if runner.awaits_choice():
			runner.choose(0)
		else:
			runner.advance()
	return keys


func test_a_linear_conversation_advances_line_by_line_and_finishes() -> void:
	var runner := ShantyRunner.new()
	runner.start(_conversation([_line("one"), _line("two"), _line("three")]), null)

	assert_eq(_played_keys(runner), PackedStringArray(["one", "two", "three"]))
	assert_true(runner.is_finished())
	assert_null(runner.current())
	assert_eq(runner.collected_effects().size(), 3, "one effect per line shown")


func test_advance_is_refused_while_a_reply_is_owed() -> void:
	var runner := ShantyRunner.new()
	runner.start(_branching(), null)
	runner.advance()

	runner.advance()

	assert_eq(runner.current().text_key, "b", "still on the question")
	assert_push_error("waiting for a choice")


func test_a_reply_without_a_jump_falls_through_to_the_next_line() -> void:
	var runner := ShantyRunner.new()
	runner.start(_branching(), null)
	runner.advance()

	runner.choose(0)

	var expected: Dictionary[String, int] = {"b": 0}
	assert_eq(runner.current().text_key, "c")
	assert_eq(runner.choices_taken(), expected)


func test_a_reply_with_a_jump_continues_from_the_labelled_line() -> void:
	var runner := ShantyRunner.new()
	runner.start(_branching(), null)
	runner.advance()

	runner.choose(1)

	assert_eq(runner.current().text_key, "d", "c was jumped over")
	runner.advance()
	assert_true(runner.is_finished())
	# a, b, the reply, d: c's effect was never collected.
	assert_eq(runner.collected_effects().size(), 4)


func test_a_jump_to_a_missing_label_ends_the_conversation_loudly() -> void:
	var question: DialogueLine = _line("q")
	question.choices.append(_choice("nowhere", &"no_such_label"))
	var runner := ShantyRunner.new()
	runner.start(_conversation([question, _line("after")]), null)

	runner.choose(0)

	assert_true(runner.is_finished())
	assert_push_error("no line is labelled")


func test_a_line_whose_conditions_fail_is_skipped_with_its_effects() -> void:
	var gated: DialogueLine = _line("gated")
	gated.conditions.append(NeverCondition.new())
	var runner := ShantyRunner.new()
	runner.start(_conversation([_line("first"), gated, _line("last")]), null)

	assert_eq(_played_keys(runner), PackedStringArray(["first", "last"]))
	assert_eq(runner.collected_effects().size(), 2)


func test_a_condition_reads_the_context_the_host_passed() -> void:
	var gated: DialogueLine = _line("only_with_the_key")
	var condition := HeldCondition.new()
	condition.key = &"heard_the_bell"
	gated.conditions.append(condition)
	var context := KeyContext.new()

	var without := ShantyRunner.new()
	without.start(_conversation([gated]), context)
	context.keys.append(&"heard_the_bell")
	var with_key := ShantyRunner.new()
	with_key.start(_conversation([gated]), context)

	assert_true(without.is_finished())
	assert_eq(with_key.current().text_key, "only_with_the_key")


func test_a_conversation_whose_first_lines_are_gated_starts_on_the_first_that_holds() -> void:
	var gated: DialogueLine = _line("gated")
	gated.conditions.append(NeverCondition.new())
	var runner := ShantyRunner.new()

	runner.start(_conversation([gated, _line("opener")]), null)

	assert_eq(runner.current().text_key, "opener")


func test_an_empty_or_null_conversation_is_finished_at_once() -> void:
	var empty := ShantyRunner.new()
	empty.start(_conversation([]), null)
	var missing := ShantyRunner.new()
	missing.start(null, null)

	assert_true(empty.is_finished())
	assert_true(missing.is_finished())
	assert_eq(missing.collected_effects().size(), 0)


# --- Skipping is playing, faster ---------------------------------------------


func test_skipping_a_linear_conversation_returns_the_same_effects_as_playing_it() -> void:
	var conversation: ConversationDefinition = _conversation([_line("a"), _line("b"), _line("c")])
	var played := ShantyRunner.new()
	played.start(conversation, null)
	_played_keys(played)
	var skipped := ShantyRunner.new()
	skipped.start(conversation, null)

	assert_true(skipped.skip_to_end(), "nothing asked for a reply")
	assert_eq(skipped.collected_effects(), played.collected_effects())


func test_a_skip_stops_on_a_reply_and_never_answers_for_the_player() -> void:
	var runner := ShantyRunner.new()
	runner.start(_branching(), null)

	assert_false(runner.skip_to_end(), "a reply is owed")
	assert_eq(runner.current().text_key, "b")
	assert_eq(runner.choices_taken().size(), 0)


func test_skip_then_reply_then_skip_matches_playing_through_for_every_reply() -> void:
	for reply: int in 2:
		var conversation: ConversationDefinition = _branching()
		var played := ShantyRunner.new()
		played.start(conversation, null)
		while not played.is_finished():
			if played.awaits_choice():
				played.choose(reply)
			else:
				played.advance()
		var skipped := ShantyRunner.new()
		skipped.start(conversation, null)
		skipped.skip_to_end()
		skipped.choose(reply)
		assert_true(skipped.skip_to_end())

		assert_eq(skipped.collected_effects(), played.collected_effects(), "reply %d" % reply)
		assert_eq(skipped.choices_taken(), played.choices_taken(), "reply %d" % reply)


func test_a_gated_line_is_skipped_by_a_skip_exactly_as_by_play() -> void:
	var gated: DialogueLine = _line("gated")
	gated.conditions.append(NeverCondition.new())
	var conversation: ConversationDefinition = _conversation([_line("a"), gated, _line("b")])
	var played := ShantyRunner.new()
	played.start(conversation, null)
	_played_keys(played)
	var skipped := ShantyRunner.new()
	skipped.start(conversation, null)
	skipped.skip_to_end()

	assert_eq(skipped.collected_effects(), played.collected_effects())
	assert_false(skipped.collected_effects().has(gated.effects[0]))


# --- Shape checks writers lean on --------------------------------------------


func test_a_backward_jump_is_reported_as_a_cycle() -> void:
	var question: DialogueLine = _line("again?")
	question.choices.append(_choice("yes", &"top"))
	question.choices.append(_choice("no"))

	assert_true(ShantyRunner.has_cycle(_conversation([_line("top", &"top"), question])))
	assert_false(ShantyRunner.has_cycle(_branching()), "forward jumps are not cycles")
	assert_false(ShantyRunner.has_cycle(null))


func test_a_jump_back_that_loops_only_once_a_gate_fails_is_a_cycle() -> void:
	# 0 jumps to the gated line 2; while it fails the runner falls through to 3,
	# which jumps back to 0 -- a loop no reply edge alone shows.
	var opener: DialogueLine = _line("opener", &"top")
	opener.choices.append(_choice("on", &"gated"))
	var gated: DialogueLine = _line("gated", &"gated")
	gated.conditions.append(NeverCondition.new())
	gated.choices.append(_choice("out", &"end"))
	var again: DialogueLine = _line("again")
	again.choices.append(_choice("back", &"top"))
	var conversation: ConversationDefinition = _conversation(
		[opener, _line("unreached"), gated, again, _line("end", &"end")]
	)

	assert_true(ShantyRunner.has_cycle(conversation))


func test_start_refuses_a_conversation_that_loops() -> void:
	var question: DialogueLine = _line("again?")
	question.choices.append(_choice("yes", &"top"))
	var conversation: ConversationDefinition = _conversation([_line("top", &"top"), question])
	conversation.conversation_id = &"looping"
	var runner := ShantyRunner.new()

	var started: bool = runner.start(conversation, null)

	assert_push_error("looping")
	assert_false(started, "refused")
	assert_true(runner.is_finished(), "a refused conversation is already over")
	assert_true(runner.skip_to_end(), "so a skip has nothing to walk")
	assert_eq(runner.collected_effects().size(), 0, "and nothing was collected")
	assert_true(runner.start(_branching(), null), "an acyclic conversation starts")


func test_index_of_label_finds_the_labelled_line() -> void:
	var conversation: ConversationDefinition = _branching()

	assert_eq(ShantyRunner.index_of_label(conversation, &"end_label"), 3)
	assert_eq(ShantyRunner.index_of_label(conversation, &"absent"), -1)
	assert_eq(ShantyRunner.index_of_label(conversation, &""), -1)
