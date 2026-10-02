extends GutTest

## CutscenePlayer's record over Shanty-only fixtures: a reply is
## remembered under its conversation and its line, so two conversations in one
## scene that reuse a text key keep both answers, and a replay can find each.

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")

var _player: CutscenePlayer
var _record: PlayedSceneRecord = null


func before_each() -> void:
	_record = null
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.finished.connect(
		func(record: PlayedSceneRecord, _effects: Array[ShantyEffect]) -> void: _record = record
	)


func _asking(conversation_id: StringName) -> ConversationDefinition:
	var line := DialogueLine.new()
	line.text_key = "ASK"
	for reply: String in ["ASK_YES", "ASK_NO"]:
		var choice := DialogueChoice.new()
		choice.text_key = reply
		line.choices.append(choice)
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = conversation_id
	conversation.lines.append(line)
	return conversation


func _say(conversation: ConversationDefinition) -> SayStep:
	var step := SayStep.new()
	step.conversation = conversation
	return step


## The question waits, revealed, for the tap that hands it to the reply turn;
## then the reply is pressed.
func _answer(index: int) -> void:
	var view: DialogueView = _player.dialogue_view()
	await wait_until(
		func() -> bool:
			return (
				view.current_line() != null
				and not view.current_line().choices.is_empty()
				and not view.is_revealing()
			),
		3.0
	)
	view.handle_tap()
	await wait_until(func() -> bool: return view.choice_buttons().size() == 2, 3.0)
	view.choice_buttons()[index].pressed.emit()


func test_one_text_key_in_two_conversations_keeps_both_answers() -> void:
	var scene := CutsceneDefinition.new()
	scene.scene_id = &"two_questions"
	scene.steps.append(_say(_asking(&"first")))
	scene.steps.append(_say(_asking(&"second")))
	var settings := ShantyViewSettings.new()
	settings.text_speed_chars_per_second = 0.0

	_player.play(scene, null, null, settings)
	await _answer(1)
	await _answer(0)
	await wait_until(func() -> bool: return _record != null, 3.0)

	assert_not_null(_record, "the scene finished")
	if _record == null:
		return
	var expected: Dictionary[String, int] = {"first/ASK": 1, "second/ASK": 0}
	assert_eq(_record.choices, expected)


## The record carries what a replay list shows, as the scene stood when played,
## so the entry survives the scene's file going away or its flag going off.
func test_the_record_keeps_the_scenes_title_synopsis_and_flag() -> void:
	var scene := CutsceneDefinition.new()
	scene.scene_id = &"titled"
	scene.title_key = "TITLE_KEY"
	scene.synopsis_key = "SYNOPSIS_KEY"
	scene.remembered = true
	scene.steps.append(_say(_asking(&"only")))
	var settings := ShantyViewSettings.new()
	settings.text_speed_chars_per_second = 0.0

	_player.play(scene, null, null, settings)
	await _answer(0)
	await wait_until(func() -> bool: return _record != null, 3.0)

	assert_not_null(_record, "the scene finished")
	if _record == null:
		return
	assert_eq(_record.title_key, "TITLE_KEY")
	assert_eq(_record.synopsis_key, "SYNOPSIS_KEY")
	assert_true(_record.remembered)
