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

	screen.call(&"_on_speaker_requested", "ana")
	screen.call(&"_on_conversation_requested", "talk")
	screen.call(&"_on_locale_requested", "de")
	screen.call(&"_save")
	screen.call(&"_open", true)

	assert_null((screen.call(&"model") as ShantyEditorModel).config)
	assert_string_contains((screen.get_node(^"%Status") as Label).text, "does not exist")
