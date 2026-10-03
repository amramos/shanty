@tool
class_name ShantyPlay
extends RefCounted

## What the tab's Play asks the preview host to play, written to
## `REQUEST_PATH` as a `ConfigFile` and read back by the preview host in the
## game window `EditorInterface.play_custom_scene()` opens: the scene, or the
## trigger whose choice to play, the locale, and the config the tab has open.
##
## **Play plays the files on disk.** The game window loads what is saved, so
## Play is refused while the tab holds unsaved edits rather than playing
## something other than what the writer sees.

const REQUEST_PATH: String = "user://shanty_preview.cfg"
const HOST_SCENE: String = "res://addons/shanty/editor/preview/preview_host.tscn"
const SECTION: String = "play"

## A `CutsceneDefinition` or a `StoryTriggerDefinition`.
var resource_path: String = ""
## The locale to play in; empty keeps the game's own.
var locale: String = ""
## The `ShantyProjectConfig` to play under; empty uses the project setting.
var config_path: String = ""


## Why `selected` cannot be played now, or "" when it can.
static func refusal(model: ShantyEditorModel, selected: Resource) -> String:
	if model.config == null:
		return "Nothing to play: no Shanty config is open."
	if not (selected is CutsceneDefinition or selected is StoryTriggerDefinition):
		return "Pick a scene, or a trigger, to play."
	if model.is_dirty() or selected.resource_path.is_empty():
		return "Save first: Play plays the files on disk."
	return ""


## The request for `selected` in `shown_locale`, under the tab's config.
static func for_selection(selected: Resource, shown_locale: String) -> ShantyPlay:
	var request := ShantyPlay.new()
	request.resource_path = selected.resource_path
	request.locale = shown_locale
	request.config_path = ShantyFiles.config_path()
	return request


func write(path: String = REQUEST_PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "resource_path", resource_path)
	file.set_value(SECTION, "locale", locale)
	file.set_value(SECTION, "config_path", config_path)
	return file.save(path)


## The request at `path`, or null when there is none or it names nothing.
static func read(path: String = REQUEST_PATH) -> ShantyPlay:
	var file := ConfigFile.new()
	if not FileAccess.file_exists(path) or file.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	var request := ShantyPlay.new()
	request.resource_path = String(file.get_value(SECTION, "resource_path", ""))
	request.locale = String(file.get_value(SECTION, "locale", ""))
	request.config_path = String(file.get_value(SECTION, "config_path", ""))
	return request if not request.resource_path.is_empty() else null


## The config this request names, or the project setting's when it names none.
func load_config() -> ShantyProjectConfig:
	var path: String = config_path if not config_path.is_empty() else ShantyFiles.config_path()
	return ShantyFiles.load_resource(path) as ShantyProjectConfig


## One line for the output: an effect or condition's type and stored values,
## `example_effect {flag: lamp_lit, value: true}`.
static func describe(resource: Resource) -> String:
	if resource == null:
		return "(none)"
	var values: PackedStringArray = []
	for property: Dictionary in resource.get_property_list():
		var usage: int = int(property["usage"])
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			values.append("%s: %s" % [property["name"], resource.get(property["name"])])
	return "%s {%s}" % [ShantyLintStory.type_name(resource), ", ".join(values)]
