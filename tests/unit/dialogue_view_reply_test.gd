extends GutTest

## DialogueView's reply mode over Shanty-only fixtures: a line that
## asks reads like any other -- revealed, then waiting under the continue marker
## -- and the next tap hands the bar to the reply speaker: the line's own
## `reply_speaker_id` first, the host's setting otherwise. A speaker the provider
## does not know leaves the asker and the question on the bar.


class FixtureProvider:
	extends ShantySpeakerProvider

	func resolve(speaker_id: StringName) -> ShantySpeaker:
		if speaker_id not in [&"asker", &"host_reply", &"line_reply"]:
			return super.resolve(speaker_id)
		var speaker := ShantySpeaker.new()
		speaker.display_name = "Name of %s" % speaker_id
		return speaker


const VIEW_SCENE: PackedScene = preload("res://addons/shanty/ui/dialogue_view.tscn")

var _view: DialogueView
var _settings: ShantyViewSettings


func before_each() -> void:
	_view = VIEW_SCENE.instantiate()
	add_child_autofree(_view)
	_settings = ShantyViewSettings.new()
	_settings.text_speed_chars_per_second = 0.0
	_settings.reply_speaker_id = &"host_reply"
	_view.configure(FixtureProvider.new(), _settings)


func _asking(reply_speaker_id: StringName) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_id = &"asker"
	line.text_key = "ASK"
	line.reply_speaker_id = reply_speaker_id
	for reply: String in ["ASK_YES", "ASK_NO"]:
		var choice := DialogueChoice.new()
		choice.text_key = reply
		line.choices.append(choice)
	return line


## Shows `line` (instantly, per before_each) and taps once to hand it over.
func _show_and_answer(line: DialogueLine) -> void:
	_view.show_line(line)
	_view.handle_tap()


func _marker_visible() -> bool:
	return (_view.find_child("ContinueMarker", true, false) as Control).visible


func _name_plate() -> String:
	return (_view.find_child("NamePlate", true, false) as Label).text


func _line_text() -> String:
	return (_view.find_child("Line", true, false) as RichTextLabel).text


func test_a_line_naming_its_own_reply_speaker_overrides_the_host() -> void:
	_show_and_answer(_asking(&"line_reply"))

	assert_true(_view.is_replying())
	assert_eq(_name_plate(), "Name of line_reply")
	assert_eq(_line_text(), ShantyText.render(DialogueView.REPLY_PLACEHOLDER_KEY))
	assert_eq(_view.choice_buttons().size(), 2)


func test_a_line_naming_nobody_hands_the_turn_to_the_host_setting() -> void:
	_show_and_answer(_asking(&""))

	assert_eq(_name_plate(), "Name of host_reply")
	assert_eq(_line_text(), ShantyText.render(DialogueView.REPLY_PLACEHOLDER_KEY))


func test_an_unknown_reply_speaker_keeps_the_asker_and_still_offers_replies() -> void:
	_show_and_answer(_asking(&"nobody_known"))

	assert_eq(_name_plate(), "Name of asker")
	assert_eq(_line_text(), ShantyText.render("ASK"), "the question stays")
	assert_eq(_view.choice_buttons().size(), 2)


func test_no_reply_speaker_anywhere_keeps_the_asker() -> void:
	_settings.reply_speaker_id = &""
	_show_and_answer(_asking(&""))

	assert_eq(_name_plate(), "Name of asker")
	assert_eq(_view.choice_buttons().size(), 2)


func test_the_question_types_under_its_asker_before_the_turn_changes() -> void:
	_settings.text_speed_chars_per_second = 1.0
	_view.show_line(_asking(&"line_reply"))

	assert_false(_view.is_replying(), "still the asker's line while it types")
	assert_eq(_name_plate(), "Name of asker")
	assert_eq(_view.choice_buttons().size(), 0)
	_view.handle_tap()
	assert_false(_view.is_replying(), "the first tap only finishes the question")
	assert_eq(_line_text(), ShantyText.render("ASK"))
	assert_true(_marker_visible(), "and it waits like any finished line")
	_view.handle_tap()
	assert_true(_view.is_replying(), "the next tap hands the turn over")
	assert_eq(_name_plate(), "Name of line_reply")
	assert_false(_marker_visible())


## Instant text is where the question used to vanish unread.
func test_an_instant_question_waits_for_a_tap_before_the_turn_changes() -> void:
	_view.show_line(_asking(&"line_reply"))

	assert_false(_view.is_replying())
	assert_eq(_name_plate(), "Name of asker")
	assert_eq(_line_text(), ShantyText.render("ASK"), "the question is on the bar, whole")
	assert_true(_marker_visible())
	assert_false(_view.is_waiting_for_choice())


func test_auto_advance_never_moves_past_a_question() -> void:
	_settings.auto_advance = true
	var advanced: Array[bool] = [false]
	_view.advance_requested.connect(func() -> void: advanced[0] = true)
	_view.show_line(_asking(&"line_reply"))
	await wait_seconds(DialogueView.AUTO_ADVANCE_DELAY + 0.3)

	assert_false(advanced[0])
	assert_false(_view.is_replying(), "still waiting for the tap")


func test_open_replies_hands_over_at_once_for_a_skip() -> void:
	_settings.text_speed_chars_per_second = 1.0
	_view.show_line(_asking(&"line_reply"))
	_view.open_replies()

	assert_true(_view.is_replying())
	assert_eq(_view.choice_buttons().size(), 2)


func test_the_first_reply_holds_focus_and_the_mark() -> void:
	_show_and_answer(_asking(&""))
	await wait_process_frames(1)

	var buttons: Array[Button] = _view.choice_buttons()
	assert_true(buttons[0].has_focus())
	assert_true((buttons[0] as ShantyChoiceButton).is_marked())
	assert_false((buttons[1] as ShantyChoiceButton).is_marked())


func test_a_line_without_replies_never_enters_reply_mode() -> void:
	var line := DialogueLine.new()
	line.speaker_id = &"asker"
	line.text_key = "SAY"
	_view.show_line(line)

	assert_false(_view.is_replying())
	assert_eq(_name_plate(), "Name of asker")
	assert_eq(_line_text(), ShantyText.render("SAY"))
