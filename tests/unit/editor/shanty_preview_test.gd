extends GutTest

## The line preview over the example: `ShantyPreviewModel` resolves the
## speaker, face, text and replies from the tab's CSV, and the preview pane
## draws them in the real `DialogueView` scene exactly as a playing view draws
## the same line -- the text, the name, the face and the replies.

const BarPreview := preload("res://addons/shanty/editor/shanty_bar_preview.gd")
const ExampleHost := preload("res://addons/shanty/example/example_host.gd")
const VIEW_SCENE: PackedScene = preload("res://addons/shanty/ui/dialogue_view.tscn")
const HIGHLIGHT: String = "[color=#eda12b]"

var _model: ShantyEditorModel
var _conversation: ConversationDefinition
var _translations: Array[Translation] = []
var _previous_highlight: Color


func before_each() -> void:
	_model = ShantyEditorModel.new()
	_model.open(ShantyFiles.configured(), true)
	_conversation = _model.conversations[0]
	_previous_highlight = ShantyText.highlight_colour()


func after_each() -> void:
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	ShantyText.set_highlight_colour(_previous_highlight)
	TranslationServer.set_locale("en")


func _line(index: int) -> DialogueLine:
	return _conversation.lines[index]


func test_a_line_resolves_its_speaker_and_its_text_from_the_csv() -> void:
	var preview := ShantyPreviewModel.for_line(_model, _line(0), "en")

	assert_eq(preview.speaker_name, _model.text("SHANTY_EXAMPLE_SPEAKER_KEEPER", "en"))
	assert_null(preview.face, "the example's speakers draw no face: the flat plate")
	assert_string_contains(preview.text, HIGHLIGHT + "lamp[/color]", "[hl] in the config's colour")
	assert_false(preview.empty_cell)
	assert_eq(ShantyText.highlight_colour(), _previous_highlight, "the shared colour is put back")


func test_a_name_token_is_spelled_by_the_speaker_in_the_shown_locale() -> void:
	var english := ShantyPreviewModel.for_line(_model, _line(1), "en")
	var portuguese := ShantyPreviewModel.for_line(_model, _line(1), "pt_BR")

	assert_false(english.text.contains("{name:"), english.text)
	assert_string_contains(english.text, _model.text("SHANTY_EXAMPLE_SPEAKER_KEEPER", "en"))
	assert_string_contains(portuguese.text, _model.text("SHANTY_EXAMPLE_SPEAKER_KEEPER", "pt_BR"))


func test_an_empty_cell_is_reported_not_filled_in() -> void:
	var french := ShantyPreviewModel.for_line(_model, _line(2), "fr")

	assert_true(french.empty_cell, "the example's French column stops before the question")
	assert_eq(french.text, "")


func test_the_reply_turn_is_the_reply_speakers_with_the_replies_as_buttons_read() -> void:
	var question := ShantyPreviewModel.for_line(_model, _line(2), "en")
	var turn := ShantyPreviewModel.for_line(_model, _line(2), "en", true)

	assert_false(question.replying)
	assert_eq(question.replies, PackedStringArray(), "the question alone")
	assert_true(turn.replying)
	assert_eq(turn.speaker_name, _model.text("SHANTY_EXAMPLE_SPEAKER_VISITOR", "en"))
	assert_eq(turn.text, _model.text("SHANTY_REPLY_PLACEHOLDER", "en"))
	assert_eq(
		turn.replies,
		PackedStringArray(
			[
				_model.text("SHANTY_EXAMPLE_LINE_3_A", "en"),
				_model.text("SHANTY_EXAMPLE_LINE_3_B", "en"),
			]
		)
	)


func test_the_line_to_show_follows_what_is_picked() -> void:
	assert_eq(ShantyPreviewModel.line_for(_conversation), _line(0))
	assert_eq(ShantyPreviewModel.line_for(_model.scenes[0]), _line(0), "a scene's first said line")
	assert_null(ShantyPreviewModel.line_for(_model.speakers[0]))
	assert_null(ShantyPreviewModel.line_for(null))


func test_the_stage_theme_lays_the_host_theme_over_the_engine_default() -> void:
	var config := ShantyProjectConfig.new()
	var theme: Theme = ShantyPreviewModel.stage_theme(config)

	assert_true(theme.has_stylebox(&"panel", &"PanelContainer"), "the default is underneath")
	assert_false(theme.is_type_variation(&"ShantyBar", &"PanelContainer"), "the example has none")


## The pane, instanced as the tab instances it, showing `line`.
func _pane(line: DialogueLine, reply_turn: bool = false) -> Control:
	var pane: BarPreview = BarPreview.new()
	add_child_autofree(pane)
	pane.build()
	pane.show_theme(_model.config)
	(pane.get(&"_reply") as CheckButton).button_pressed = reply_turn
	pane.show_line(_model, line)
	return pane.view()


## A playing DialogueView showing `line` whole, with the example's strings in
## the TranslationServer and the config's highlight colour.
func _real_view(line: DialogueLine) -> DialogueView:
	_translations = ExampleHost.load_translations(ExampleHost.STRINGS_PATH)
	for translation: Translation in _translations:
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	ShantyText.set_highlight_colour(_model.config.highlight_colour)
	var view: DialogueView = VIEW_SCENE.instantiate()
	add_child_autofree(view)
	var settings := ShantyViewSettings.new()
	settings.text_speed_chars_per_second = 0.0
	view.configure(ShantyPreviewSpeakers.from_folder(_model.config.speakers_folder), settings)
	view.show_line(line)
	return view


func _drawn(view: Control) -> Dictionary:
	var name_plate: Label = view.get_node(^"%NamePlate")
	var replies: PackedStringArray = []
	for button: Node in view.get_node(^"%Choices").get_children():
		if not button.is_queued_for_deletion():
			replies.append((button as Button).text)
	return {
		"line": (view.get_node(^"%Line") as RichTextLabel).text,
		"name": name_plate.text,
		"variation": name_plate.theme_type_variation,
		"face": (view.get_node(^"%Face") as TextureRect).texture,
		"plate": (view.get_node(^"%PlateName") as Label).visible,
		"replies": replies,
	}


func test_the_preview_draws_a_line_as_a_playing_view_does() -> void:
	for index: int in _conversation.lines.size():
		var preview: Dictionary = _drawn(_pane(_line(index)))
		var real: Dictionary = _drawn(_real_view(_line(index)))

		assert_eq(preview, real, "line %d" % (index + 1))


func test_the_preview_draws_the_reply_turn_as_a_playing_view_does() -> void:
	var real_view: DialogueView = _real_view(_line(2))
	real_view.handle_tap()
	await wait_process_frames(1)
	var preview: Dictionary = _drawn(_pane(_line(2), true))
	var real: Dictionary = _drawn(real_view)

	assert_eq(preview["replies"], real["replies"])
	assert_eq(preview["replies"].size(), 2)
	assert_eq(preview["name"], real["name"])
	assert_eq(preview["line"], real["line"])
