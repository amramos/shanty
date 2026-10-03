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
##
## **A request is checked, and played once.** The preview host takes the file
## (`take()` removes it as it reads it), so running the host again without the
## tab plays nothing; and it plays only a request whose three fields are all
## there, each path a canonical `res://` path to a file of the type expected
## (`check()`). A request is a file anything could write, and the host loads
## what it names.

const REQUEST_PATH: String = "user://shanty_preview.cfg"
const HOST_SCENE: String = "res://addons/shanty/editor/preview/preview_host.tscn"
const SECTION: String = "play"
const RESOURCE_FIELD: String = "resource_path"
const LOCALE_FIELD: String = "locale"
const CONFIG_FIELD: String = "config_path"
const RES_SCHEME: String = "res://"

## A `CutsceneDefinition` or a `StoryTriggerDefinition`.
var resource_path: String = ""
## The locale to play in.
var locale: String = ""
## The `ShantyProjectConfig` to play under.
var config_path: String = ""
## Set by `check()` once the request holds: the config it names, and the scene
## or trigger to play.
var config: ShantyProjectConfig = null
var target: Resource = null

## The fields the file did not hold as text, in `fields()` order.
var _missing: PackedStringArray = []
var _unreadable: bool = false


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


## Every field a request must hold.
static func fields() -> PackedStringArray:
	return PackedStringArray([RESOURCE_FIELD, LOCALE_FIELD, CONFIG_FIELD])


func write(path: String = REQUEST_PATH) -> Error:
	var file := ConfigFile.new()
	for field: String in fields():
		file.set_value(SECTION, field, get(field))
	return file.save(path)


## The request at `path`, or null when there is no file. A field the file does
## not hold as text is left empty and named by `check()`.
static func read(path: String = REQUEST_PATH) -> ShantyPlay:
	if not FileAccess.file_exists(path):
		return null
	var request := ShantyPlay.new()
	var file := ConfigFile.new()
	if file.parse(FileAccess.get_file_as_string(path)) != OK:
		request._unreadable = true
		return request
	for field: String in fields():
		var value: Variant = (
			file.get_value(SECTION, field) if file.has_section_key(SECTION, field) else null
		)
		if value is String:
			request.set(field, value)
		else:
			request._missing.append(field)
	return request


## The request at `path`, removing the file as it is read: a request is played
## once. Null when there is none.
static func take(path: String = REQUEST_PATH) -> ShantyPlay:
	var request: ShantyPlay = read(path)
	if request != null:
		ShantyFiles.remove(path)
	return request


## Why this request cannot be played, or "" when it can; then `config` and
## `target` hold what it names. Each way a request fails has its own reason.
func check() -> String:
	config = null
	target = null
	if _unreadable:
		return "Nothing to play: the request is not one the Shanty tab wrote."
	for field: String in fields():
		if _missing.has(field) or String(get(field)).is_empty():
			return "Nothing to play: the request names no %s." % field
	var refused: String = _path_refusal(config_path, "config")
	if refused.is_empty():
		refused = _path_refusal(resource_path, "scene or trigger")
	if not refused.is_empty():
		return refused
	var loaded_config: ShantyProjectConfig = (
		ShantyFiles.load_resource(config_path) as ShantyProjectConfig
	)
	if loaded_config == null:
		return "Refused: %s is not a ShantyProjectConfig." % config_path
	var loaded: Resource = ShantyFiles.load_resource(resource_path)
	if not (loaded is CutsceneDefinition or loaded is StoryTriggerDefinition):
		return "Refused: %s is not a scene or a trigger." % resource_path
	config = loaded_config
	target = loaded
	return ""


## Why `path` may not be loaded as the request's `what`, or "" when it may: a
## canonical `res://` path -- no other scheme, no absolute path, no `.` or
## `..` part, no empty part, no backslash -- to a file that exists.
static func _path_refusal(path: String, what: String) -> String:
	if not path.begins_with(RES_SCHEME):
		return (
			"Refused: the %s %s is not a res:// path; Play loads only the project's own files."
			% [what, path]
		)
	var parts: PackedStringArray = path.trim_prefix(RES_SCHEME).split("/")
	if path.contains("\\") or parts.has("") or parts.has(".") or parts.has(".."):
		return "Refused: the %s %s is not a canonical res:// path." % [what, path]
	if not ResourceLoader.exists(path):
		return "Refused: the %s %s does not exist." % [what, path]
	return ""


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
