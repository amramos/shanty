extends GutTest

## CutscenePlayer's replay over Shanty-only fixtures, so a replay can never
## rewrite a flag: every reply is answered from
## the record and *spoken* by the reply speaker as an ordinary line -- their name,
## the reply typing out, a tap to go on -- never offered as a button and never
## shown with the placeholder. The replay ends on `replay_finished` with no record
## and no effects, never on `finished`, wearing the READING AGAIN mark
## throughout. A record that cannot answer a line ends the replay's dialogue
## there; a skip answers from the record without stopping.

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")


class Grant:
	extends ShantyEffect


class CastProvider:
	extends ShantySpeakerProvider

	func resolve(speaker_id: StringName) -> ShantySpeaker:
		if speaker_id not in [&"asker", &"listener"]:
			return super.resolve(speaker_id)
		var speaker := ShantySpeaker.new()
		speaker.display_name = "Name of %s" % speaker_id
		return speaker


var _player: CutscenePlayer
var _finished_count: int = 0
var _replayed: bool = false
var _choices_made: Array[int] = []


func before_each() -> void:
	_finished_count = 0
	_replayed = false
	_choices_made = []
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.finished.connect(
		func(_record: PlayedSceneRecord, _effects: Array[ShantyEffect]) -> void:
			_finished_count += 1
	)
	_player.replay_finished.connect(func() -> void: _replayed = true)
	_player.dialogue_view().choice_made.connect(
		func(index: int) -> void: _choices_made.append(index)
	)


## Asks, then branches: reply 0 goes on to "AFTER_YES", reply 1 jumps to "NO".
func _scene() -> CutsceneDefinition:
	var ask := DialogueLine.new()
	ask.speaker_id = &"asker"
	ask.text_key = "ASK"
	ask.effects.append(Grant.new())
	for reply: String in ["YES", "NO"]:
		var choice := DialogueChoice.new()
		choice.text_key = reply
		choice.effects.append(Grant.new())
		ask.choices.append(choice)
	ask.choices[1].jump_label = &"no"
	var after_yes := DialogueLine.new()
	after_yes.text_key = "AFTER_YES"
	var after_no := DialogueLine.new()
	after_no.label = &"no"
	after_no.text_key = "AFTER_NO"
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = &"replayed"
	conversation.lines = [ask, after_yes, after_no] as Array[DialogueLine]
	var say := SayStep.new()
	say.conversation = conversation
	var scene := CutsceneDefinition.new()
	scene.scene_id = &"replayed_scene"
	scene.steps.append(say)
	return scene


func _record(answer: int) -> PlayedSceneRecord:
	var record := PlayedSceneRecord.new()
	record.scene_id = &"replayed_scene"
	if answer >= 0:
		record.choices[PlayedSceneRecord.choice_key(&"replayed", "ASK")] = answer
	return record


func _settings(chars_per_second: float = 0.0) -> ShantyViewSettings:
	var settings := ShantyViewSettings.new()
	settings.text_speed_chars_per_second = chars_per_second
	settings.reply_speaker_id = &"listener"
	return settings


func _replay(answer: int, chars_per_second: float = 0.0) -> void:
	_player.play_replay(
		_scene(), _record(answer), null, CastProvider.new(), _settings(chars_per_second)
	)


func _marker_visible() -> bool:
	return (_player.find_child("ContinueMarker", true, false) as Control).visible


## Taps past the question until the recorded reply is on the bar.
func _reach_the_reply() -> void:
	var view: DialogueView = _player.dialogue_view()
	await wait_until(func() -> bool: return view.current_line() != null, 2.0)
	view.handle_tap()
	await wait_until(func() -> bool: return view.is_speaking_recorded_reply(), 2.0)


func test_the_recorded_reply_is_spoken_by_the_reply_speaker() -> void:
	_replay(1)
	await _reach_the_reply()
	var view: DialogueView = _player.dialogue_view()

	assert_true(view.is_speaking_recorded_reply(), "the record's reply takes the bar")
	assert_eq(view.speaker_name(), "Name of listener", "under the reply speaker's name")
	assert_eq(view.line_text(), "NO", "as a line, in the reply's own words")
	assert_ne(view.line_text(), tr(DialogueView.REPLY_PLACEHOLDER_KEY), "never the placeholder")
	assert_eq(view.choice_buttons().size(), 0, "never offered as a button")
	assert_true(_marker_visible(), "and waits for a tap like any line")
	assert_eq(_choices_made, [] as Array[int])


func test_the_spoken_reply_types_out_like_any_line() -> void:
	# Slow enough that the two-letter reply is still typing when it is checked.
	_replay(0, 2.0)
	var view: DialogueView = _player.dialogue_view()
	await wait_until(func() -> bool: return view.current_line() != null, 2.0)
	view.handle_tap()
	view.handle_tap()
	await wait_until(func() -> bool: return view.is_speaking_recorded_reply(), 2.0)

	assert_true(view.is_revealing(), "the reply is typing")
	assert_false(_marker_visible(), "no marker until it has finished")
	view.handle_tap()
	assert_false(view.is_revealing(), "a tap finishes it, as on any line")
	assert_true(view.is_speaking_recorded_reply(), "the finishing tap does not also move on")


func test_a_replay_follows_the_recorded_branch_and_returns_nothing() -> void:
	_replay(1)
	await _reach_the_reply()
	var view: DialogueView = _player.dialogue_view()
	view.handle_tap()
	await wait_until(
		func() -> bool:
			return view.current_line() != null and view.current_line().text_key == "AFTER_NO",
		2.0
	)
	assert_eq(view.current_line().text_key, "AFTER_NO", "the branch the reader took")
	assert_eq(view.speaker_name(), "", "the next line is the next line's own")
	view.handle_tap()
	await wait_until(func() -> bool: return _replayed, 2.0)

	assert_true(_replayed, "the replay finished")
	assert_eq(_finished_count, 0, "never as a playing a host would record or apply")
	assert_eq(_choices_made, [] as Array[int], "the bar never asked")


## The same scene with a second conversation after the first, and a wait between
## them that is not dialogue.
func _scene_with_more() -> CutsceneDefinition:
	var scene: CutsceneDefinition = _scene()
	var pause := WaitStep.new()
	pause.seconds = 0.05
	scene.steps.append(pause)
	var later := DialogueLine.new()
	later.text_key = "LATER"
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = &"later"
	conversation.lines = [later] as Array[DialogueLine]
	var say := SayStep.new()
	say.conversation = conversation
	scene.steps.append(say)
	return scene


func test_a_record_with_no_answer_ends_the_dialogue_there() -> void:
	var seen: Array[String] = []
	var view: DialogueView = _player.dialogue_view()
	view.line_completed.connect(func() -> void: seen.append(view.current_line().text_key))
	_player.play_replay(_scene_with_more(), _record(-1), null, CastProvider.new(), _settings())
	await wait_until(func() -> bool: return view.current_line() != null, 2.0)

	assert_eq(view.current_line().text_key, "ASK", "the question is read")
	view.handle_tap()
	assert_false(view.is_speaking_recorded_reply(), "nothing is put in the listener's mouth")
	assert_eq(view.choice_buttons().size(), 0, "and nothing is offered")
	await wait_until(func() -> bool: return _replayed, 3.0)

	assert_true(_replayed, "the replay still finished, its wait included")
	assert_eq(seen, ["ASK"] as Array[String], "no branch was followed and nothing more was said")
	assert_eq(_choices_made, [] as Array[int])
	assert_eq(_finished_count, 0)


func test_a_skipped_replay_answers_from_the_record_and_ends() -> void:
	_replay(0)
	await wait_process_frames(2)
	_player.skip()
	await wait_until(func() -> bool: return _replayed, 3.0)

	assert_true(_replayed, "a skip walks past the recorded reply as past any line")
	assert_eq(_finished_count, 0)
	assert_eq(_choices_made, [] as Array[int], "and the bar never asked")


func test_a_replay_wears_its_mark_and_a_playing_does_not() -> void:
	var mark: Label = _player.find_child("ReadingAgain", true, false)
	_replay(0)
	await wait_process_frames(2)
	assert_true(mark.visible, "READING AGAIN while the replay runs")
	assert_eq(mark.text, tr(CutscenePlayer.READING_AGAIN_KEY))
	_player.stop_replay()
	assert_false(mark.visible, "gone when it ends")

	_player.play(_scene(), null, CastProvider.new(), _settings())
	await wait_process_frames(2)
	assert_false(mark.visible, "a first playing is not a reading")


func test_stopping_a_replay_ends_it_as_a_replay_and_only_a_replay() -> void:
	_replay(1)
	await _reach_the_reply()
	_player.stop_replay()

	assert_true(_replayed, "replay_finished, as at its end")
	assert_false(_player.is_running())
	assert_false(_player.dialogue_view().visible, "the bar is down")
	assert_eq(_finished_count, 0)

	_player.play(_scene(), null, CastProvider.new(), _settings())
	await wait_process_frames(2)
	_player.stop_replay()
	assert_true(_player.is_running(), "a first playing has no such exit")
