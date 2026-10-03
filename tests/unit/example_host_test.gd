extends GutTest

## The example host inside the addon, played headlessly: proof that Shanty
## works with no other code at all. A first playing applies the
## chosen reply's effect to the host's own context and keeps the record; a
## replay of that record applies nothing.

const HOST_SCENE: PackedScene = preload("res://addons/shanty/example/example_host.tscn")
const ExampleHost := preload("res://addons/shanty/example/example_host.gd")
const CONVERSATION: ConversationDefinition = preload(
	"res://addons/shanty/example/example_conversation.tres"
)
const KEEPER_FLAG: StringName = &"example_keeper_lit_lamp"
const VISITOR_FLAG: StringName = &"example_visitor_lit_lamp"
## Taps a playing may need from its first line to its end; a hang fails rather
## than spinning forever.
const TAP_LIMIT: int = 40

var _host: ExampleHost


func before_each() -> void:
	_host = HOST_SCENE.instantiate()
	add_child_autofree(_host)
	_host.settings.text_speed_chars_per_second = 0.0
	_host.settings.reduced_motion = true


func _button(node_name: String) -> Button:
	return _host.find_child(node_name, true, false) as Button


## Taps the bar, a frame or two apart, until `done` holds. False on a hang.
func _tap_until(done: Callable) -> bool:
	for attempt: int in TAP_LIMIT:
		if done.call():
			return true
		var player: CutscenePlayer = _host.player()
		if player != null:
			player.dialogue_view().handle_tap()
		await wait_process_frames(2)
	return done.call()


func _replies_offered() -> bool:
	var player: CutscenePlayer = _host.player()
	return player != null and player.dialogue_view().choice_buttons().size() == 2


## Plays the scene from the Play button and takes the second reply.
func _play_choosing_the_second_reply() -> void:
	_button("PlayButton").pressed.emit()
	assert_not_null(_host.player(), "Play opens a player")
	assert_true(await _tap_until(_replies_offered), "the question's two replies are offered")
	_host.player().dialogue_view().choice_buttons()[1].pressed.emit()
	assert_true(
		await _tap_until(func() -> bool: return _host.last_record != null),
		"the scene finishes after the reply"
	)


func test_a_first_playing_applies_the_chosen_reply_and_keeps_the_record() -> void:
	await _play_choosing_the_second_reply()

	assert_true(_host.context.has_key(KEEPER_FLAG), "the second reply's effect is applied")
	assert_false(_host.context.has_key(VISITOR_FLAG), "the reply not taken changes nothing")
	assert_eq(_host.effects_applied, 1)
	var record: PlayedSceneRecord = _host.last_record
	assert_eq(record.scene_id, &"shanty_example_lamp")
	assert_eq(record.playthrough_ordinal, 1, "the context's chapter is recorded")
	assert_true(record.remembered, "the scene's flags are snapshotted onto the record")
	var key: String = PlayedSceneRecord.choice_key(&"shanty_example_lamp", "SHANTY_EXAMPLE_LINE_3")
	assert_eq(record.choices.get(key, -1), 1, "the record holds the reply taken")
	assert_null(_host.player(), "the host frees its player once the scene ends")


func test_the_example_reads_its_own_strings_and_speakers() -> void:
	_button("PlayButton").pressed.emit()
	var view_ready: Callable = func() -> bool:
		return _host.player() != null and _host.player().dialogue_view().current_line() != null
	assert_true(await _tap_until(view_ready), "the first line is shown")
	var view: DialogueView = _host.player().dialogue_view()

	assert_eq(view.current_line().text_key, "SHANTY_EXAMPLE_LINE_1", "the flagged line is shown")
	assert_ne(view.speaker_name(), "SHANTY_EXAMPLE_SPEAKER_KEEPER", "the name key resolves")
	assert_false(view.line_text().contains("SHANTY_EXAMPLE"), "the line key resolves")
	assert_false(view.line_text().contains("[hl]"), "the highlight tag is markup, not text")


func test_a_replay_of_the_record_applies_nothing() -> void:
	await _play_choosing_the_second_reply()
	var record: PlayedSceneRecord = _host.last_record
	_host.context.flags.erase(KEEPER_FLAG)
	watch_signals(_host)
	var offered: Array[int] = [0]

	_button("ReplayButton").pressed.emit()
	assert_true(_host.player().is_replay(), "the second button opens a replay")
	var closed: Callable = func() -> bool:
		if _host.player() != null:
			offered[0] = maxi(offered[0], _host.player().dialogue_view().choice_buttons().size())
		return _host.player() == null
	assert_true(await _tap_until(closed), "the replay reaches its end")

	assert_signal_emitted(_host, "replayed")
	assert_signal_not_emitted(_host, "played", "a replay is never a new playing")
	assert_false(_host.context.has_key(KEEPER_FLAG), "no effect is applied again")
	assert_eq(_host.effects_applied, 1)
	assert_same(_host.last_record, record, "the record is not rewritten")
	assert_eq(offered[0], 0, "a replay speaks the recorded reply and offers none")


func test_every_key_the_example_uses_is_in_its_finished_languages() -> void:
	var keys := PackedStringArray(
		[
			"SHANTY_EXAMPLE_PLAY",
			"SHANTY_EXAMPLE_REPLAY",
			"SHANTY_EXAMPLE_TITLE",
			"SHANTY_EXAMPLE_SYNOPSIS",
			"SHANTY_EXAMPLE_SPEAKER_KEEPER",
			"SHANTY_EXAMPLE_SPEAKER_VISITOR",
			"SHANTY_HOLD_TO_SKIP",
			"SHANTY_REPLY_PLACEHOLDER",
			"SHANTY_READING_AGAIN",
		]
	)
	for line: DialogueLine in CONVERSATION.lines:
		keys.append(line.text_key)
		for choice: DialogueChoice in line.choices:
			keys.append(choice.text_key)
	var translations: Array[Translation] = ExampleHost.load_translations(ExampleHost.STRINGS_PATH)
	var locales := PackedStringArray()
	for translation: Translation in translations:
		locales.append(translation.locale)
		# `fr` is deliberately partial: it gives the Shanty tab's coverage strip a gap to show.
		if translation.locale == "fr":
			continue
		for key: String in keys:
			var message: String = String(translation.get_message(key))
			assert_false(message.is_empty(), "%s has %s" % [translation.locale, key])

	assert_eq(
		locales,
		PackedStringArray(["en", "pt_BR", "fr"]),
		"the `_notes` and `_flags` columns are skipped"
	)
	var french: Translation = translations[2]
	assert_eq(String(french.get_message("SHANTY_EXAMPLE_LINE_1")).is_empty(), false)
	assert_eq(
		String(french.get_message("SHANTY_EXAMPLE_LINE_3")), "", "an empty cell adds no message"
	)
	assert_false(ShantyRunner.has_cycle(CONVERSATION))
