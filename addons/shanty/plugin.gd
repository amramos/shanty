@tool
extends EditorPlugin

## Shanty's editor entry point: a **Shanty** tab beside 2D, 3D and Script, where
## a writer edits speakers and conversations against the host's translation
## CSV. The runtime never needs the plugin -- every class registers through
## `class_name` -- so a game plays its scenes whether or not it is enabled.
##
## The tab reads the host's `ShantyProjectConfig`, named by the project setting
## `shanty/config_path`, which this plugin registers.

const MAIN_SCREEN: PackedScene = preload("res://addons/shanty/editor/shanty_main_screen.tscn")
## Loaded when asked for, not preloaded: on a project's first import the
## plugin runs before the SVG has been imported, and then it has no icon yet.
const ICON_PATH: String = "res://addons/shanty/editor/shanty_icon.svg"
const MainScreen := preload("res://addons/shanty/editor/shanty_main_screen.gd")

var _screen: MainScreen = null


func _enter_tree() -> void:
	_register_setting()
	_screen = MAIN_SCREEN.instantiate()
	EditorInterface.get_editor_main_screen().add_child(_screen)
	_make_visible(false)
	_screen.start()


func _exit_tree() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _screen != null:
		_screen.visible = visible


func _get_plugin_name() -> String:
	return "Shanty"


func _get_plugin_icon() -> Texture2D:
	if not ResourceLoader.exists(ICON_PATH):
		return null
	return load(ICON_PATH) as Texture2D


## Adds `shanty/config_path` to Project Settings with an empty default, so a
## host sees where to point it. A value the host already set is kept.
static func _register_setting() -> void:
	var setting: String = ShantyProjectConfig.SETTING
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, "")
	ProjectSettings.set_initial_value(setting, "")
	ProjectSettings.set_as_basic(setting, true)
	(
		ProjectSettings
		. add_property_info(
			{
				"name": setting,
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_FILE,
				"hint_string": "*.tres",
			}
		)
	)
