extends GutTest

## The Shanty tab instantiated with no editor running, as a test runs it: it
## opens the configured project, and with no usable config it shows the empty
## state and says why, without touching `EditorInterface` or a null config.

const MAIN_SCREEN: PackedScene = preload("res://addons/shanty/editor/shanty_main_screen.tscn")

var _saved_setting: Variant = null


func before_each() -> void:
	_saved_setting = ProjectSettings.get_setting(ShantyProjectConfig.SETTING)


func after_each() -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, _saved_setting)


func _started_screen() -> Control:
	var screen: Control = MAIN_SCREEN.instantiate()
	add_child_autofree(screen)
	screen.call(&"start")
	return screen


func test_the_tab_opens_the_configured_example_headlessly() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")

	assert_not_null(model.config)
	assert_eq(model.conversations.size(), 1)
	assert_string_contains((screen.get_node(^"%Status") as Label).text, "example_strings.csv")


func test_an_empty_setting_shows_the_empty_state_and_says_why() -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, "")
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")

	assert_null(model.config)
	var status: String = (screen.get_node(^"%Status") as Label).text
	assert_string_contains(status, "No Shanty config")
	assert_string_contains(status, "Create config")
	var hint: Label = screen.get_node(^"%Hint")
	assert_true(hint.visible)
	assert_string_contains(hint.text, "No Shanty config is open")


func test_requests_without_a_config_are_answered_not_crashed_on() -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, "res://nowhere/config.tres")
	var screen: Control = _started_screen()

	for kind: StringName in [&"speaker", &"conversation", &"scene", &"trigger"]:
		screen.call(&"_on_create_requested", kind, "ana")
	screen.call(&"_play")
	screen.call(&"_on_locale_requested", "de")
	screen.call(&"_save")
	screen.call(&"_open", true)

	assert_null((screen.call(&"model") as ShantyEditorModel).config)
	assert_string_contains((screen.get_node(^"%Status") as Label).text, "does not exist")


func test_each_kind_picked_shows_its_own_form_and_the_preview_follows() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	# The speaker form is left out: its texture picker exists only in the editor.
	var forms: Dictionary[String, Resource] = {
		"LineTable": model.conversations[0],
		"ScenePane": model.scenes[0],
		"TriggerPane": model.triggers[0],
	}
	for form: String in forms:
		screen.call(&"_select", forms[form])
		for other: String in forms:
			assert_eq((screen.get_node("%" + other) as Control).visible, other == form, "%s" % form)
		assert_false((screen.get_node(^"%SpeakerForm") as Control).visible)

	screen.call(&"_select", model.scenes[0])
	var line: RichTextLabel = (screen.get_node(^"%BarPreview").call(&"view") as Control).get_node(
		^"%Line"
	)
	assert_string_contains(line.text, "lamp", "a scene previews its first said line")
	model.set_text("SHANTY_EXAMPLE_LINE_1", "en", "Words typed a moment ago.")
	assert_eq(line.text, "Words typed a moment ago.", "the preview follows the typing")


func test_play_is_refused_with_its_reason_while_edits_are_unsaved() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	screen.call(&"_select", model.scenes[0])
	model.set_text("SHANTY_EXAMPLE_LINE_1", "en", "Unsaved.")
	screen.call(&"_play")

	assert_string_contains((screen.get_node(^"%Status") as Label).text, "Save first")
