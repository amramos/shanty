extends GutTest

## The addon README names real things. Every `SHANTY_` key it shows is in the
## example's strings, and the three every host declares are all there; every
## class a gdscript block names is one Shanty or the tutorial declares; every
## `Shanty`/`Cutscene`/`Dialogue` name anywhere in it is a class, a file or a
## theme type; every `example/` twin and `res://addons/shanty/` path it points
## at exists; every key the tutorial says the tab will make is the one the
## default key scheme makes; and its version is `plugin.cfg`'s. The changelog's
## headings are each a version a release tag can carry. A rename that forgets
## the README fails here rather than in a reader's first half hour.

const README: String = "res://addons/shanty/README.md"
const CHANGELOG: String = "res://addons/shanty/CHANGELOG.md"
const PLUGIN_CFG: String = "res://addons/shanty/plugin.cfg"
const STRINGS: String = "res://addons/shanty/example/example_strings.csv"
const ADDON: String = "res://addons/shanty/"
## A Shanty class, or a name shaped like one of its data or UI classes.
const TYPE_PATTERN: String = (
	"\\b(Shanty[A-Za-z]+"
	+ "|[A-Z][A-Za-z]*(?:Definition|Step|Candidate|Record|Player|Choice|Line))\\b"
)
## A name in the addon's own families, in prose or code.
const FAMILY_PATTERN: String = "\\b(?:Shanty|Cutscene|Dialogue)[A-Z][A-Za-z]*\\b"
const ADDON_PATH_PATTERN: String = "res://addons/shanty/[A-Za-z0-9_./-]*[A-Za-z0-9_]"
## What CI accepts as a release tag: `v` and a semantic version.
const TAG_PATTERN: String = "^v(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$"
## A key the tab names under the default scheme, as the README spells one.
const SCHEME_KEY_PATTERN: String = "\\b(?:DLG|SPEAKER|SCENE_[A-Z]+)_[A-Z0-9_]*[A-Z0-9]\\b"
## Classes the tutorial's own scripts declare, which no installed addon has.
const TUTORIAL_CLASSES: Array[String] = [
	"StoryFlagCondition", "StoryFlagEffect", "StoryContext", "StorySpeakers"
]
## What the tutorial makes in the tab, in the order it makes it.
const TUTORIAL_SPEAKERS: PackedStringArray = ["keeper", "visitor"]
const TUTORIAL_CONVERSATION: String = "lamp_talk"
const TUTORIAL_LINES: int = 3
## The line, 1-based, that carries the tutorial's two replies.
const TUTORIAL_ASKING_LINE: int = 3
const TUTORIAL_REPLIES: int = 2
const TUTORIAL_SCENE: String = "lamp_scene"


func _readme() -> String:
	return FileAccess.get_file_as_string(README)


func _gdscript_blocks(text: String) -> Array[String]:
	var blocks: Array[String] = []
	var fence := RegEx.create_from_string("(?s)```gdscript\\n(.*?)```")
	for found: RegExMatch in fence.search_all(text):
		blocks.append(found.get_string(1))
	return blocks


## Every distinct match of `pattern` in `text`, in order of first appearance.
func _distinct(pattern: String, text: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for hit: RegExMatch in RegEx.create_from_string(pattern).search_all(text):
		if not found.has(hit.get_string()):
			found.append(hit.get_string())
	return found


func _global_classes() -> PackedStringArray:
	var names: PackedStringArray = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		names.append(String(entry["class"]))
	return names


## Every `.gd` and `.tscn` file name under `folder`, recursively, without its
## extension.
func _script_and_scene_names(folder: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "tscn"]:
			names.append(file.get_basename())
	for child: String in DirAccess.get_directories_at(folder):
		names.append_array(_script_and_scene_names(folder.path_join(child)))
	return names


## The keys the tab makes for the tutorial's speakers, lines, replies and
## scene under the default `ShantyKeyScheme`.
static func _tutorial_keys() -> PackedStringArray:
	var scheme := ShantyKeyScheme.new()
	var keys: PackedStringArray = []
	for speaker: String in TUTORIAL_SPEAKERS:
		keys.append(scheme.speaker_key(speaker))
	var prefix: String = scheme.prefix_for(TUTORIAL_CONVERSATION)
	for _line: int in TUTORIAL_LINES:
		keys.append(scheme.next_line_key(prefix, keys))
	var asking: String = scheme.line_key_for(prefix, TUTORIAL_ASKING_LINE)
	for _reply: int in TUTORIAL_REPLIES:
		keys.append(scheme.next_reply_key(asking, keys))
	keys.append(scheme.title_key(TUTORIAL_SCENE))
	keys.append(scheme.synopsis_key(TUTORIAL_SCENE))
	return keys


func test_every_example_key_the_readme_names_is_in_the_example_strings() -> void:
	var catalogue: String = FileAccess.get_file_as_string(STRINGS)
	var named: PackedStringArray = _distinct("\\bSHANTY_[A-Z0-9_]*[A-Z0-9]\\b", _readme())

	for key: String in ShantyHostContract.TRANSLATION_KEYS:
		assert_true(named.has(key), "the README names the host key %s" % key)
	for key: String in named:
		assert_true(catalogue.contains("\n%s," % key), "%s is in example_strings.csv" % key)


func test_every_class_the_tutorial_code_names_exists() -> void:
	var declared: PackedStringArray = _global_classes()
	declared.append_array(TUTORIAL_CLASSES)
	var type_names := RegEx.create_from_string(TYPE_PATTERN)
	var blocks: Array[String] = _gdscript_blocks(_readme())
	var checked: int = 0

	assert_gt(blocks.size(), 2, "the tutorial's scripts are gdscript blocks")
	for block: String in blocks:
		for found: RegExMatch in type_names.search_all(block):
			var name: String = found.get_string(1)
			assert_true(declared.has(name), "%s is a class" % name)
			checked += 1
	assert_gt(checked, 10, "the tutorial's code names Shanty's classes")


func test_every_shanty_name_in_the_prose_exists() -> void:
	var classes: PackedStringArray = _global_classes()
	var files: PackedStringArray = _script_and_scene_names(ADDON.trim_suffix("/"))
	var named: PackedStringArray = _distinct(FAMILY_PATTERN, _readme())

	assert_gt(named.size(), 40, "the README names Shanty's classes")
	for name: String in named:
		var known: bool = (
			classes.has(name)
			or files.has(name.to_snake_case())
			or ShantyHostContract.THEME_TYPE_VARIATIONS.has(StringName(name))
		)
		assert_true(known, "%s is a class, a file or a theme type" % name)


func test_every_twin_the_tutorial_points_at_exists() -> void:
	var twins := RegEx.create_from_string("`(example/[a-z_]+\\.(?:tres|tscn|gd|csv))`")
	var found_any: bool = false
	for found: RegExMatch in twins.search_all(_readme()):
		found_any = true
		var path: String = ADDON + found.get_string(1)
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
	assert_true(found_any, "the tutorial names its twins")


func test_every_addon_path_the_readme_names_exists() -> void:
	var paths: PackedStringArray = _distinct(ADDON_PATH_PATTERN, _readme())

	assert_gt(paths.size(), 2, "the README names files inside the addon")
	for path: String in paths:
		var exists: bool = FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
		assert_true(exists, "%s exists" % path)


func test_the_keys_the_tutorial_shows_are_the_default_schemes() -> void:
	var expected: PackedStringArray = _tutorial_keys()
	var prefix: String = ShantyKeyScheme.new().prefix_for(TUTORIAL_CONVERSATION)
	var shown: PackedStringArray = _distinct(SCHEME_KEY_PATTERN, _readme())

	for key: String in expected:
		assert_true(shown.has(key), "the tutorial shows %s, which the tab makes" % key)
	assert_true(shown.has(prefix), "the tutorial shows the default prefix %s" % prefix)
	for key: String in shown:
		var made: bool = expected.has(key) or key == prefix
		assert_true(made, "%s is a key or prefix the default scheme makes" % key)


func test_the_tutorial_key_reader() -> void:
	assert_eq(
		_tutorial_keys(),
		PackedStringArray(
			[
				"SPEAKER_KEEPER",
				"SPEAKER_VISITOR",
				"DLG_LAMP_TALK_01",
				"DLG_LAMP_TALK_02",
				"DLG_LAMP_TALK_03",
				"DLG_LAMP_TALK_03A",
				"DLG_LAMP_TALK_03B",
				"SCENE_TITLE_LAMP_SCENE",
				"SCENE_SYNOPSIS_LAMP_SCENE",
			]
		)
	)


func test_the_readme_version_is_the_plugin_version() -> void:
	var config := ConfigFile.new()
	assert_eq(config.load(PLUGIN_CFG), OK, "plugin.cfg loads")
	var version: String = String(config.get_value("plugin", "version", ""))

	assert_true(_readme().contains("**Version %s.**" % version), "the README says %s" % version)


func test_every_changelog_heading_is_a_tag_shaped_version() -> void:
	var tag := RegEx.create_from_string(TAG_PATTERN)
	var seen: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(CHANGELOG).split("\n"):
		if not line.begins_with("## "):
			continue
		var heading: String = line.substr(3).strip_edges()
		var version: String = heading.get_slice(" ", 0).trim_prefix("[").trim_suffix("]")
		assert_not_null(tag.search("v" + version), "'%s' can be tagged v%s" % [line, version])
		assert_false(seen.has(version), "%s has one section" % version)
		seen.append(version)
	assert_gt(seen.size(), 2, "the changelog has its sections")
