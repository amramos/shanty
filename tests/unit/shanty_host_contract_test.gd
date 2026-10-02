extends GutTest

## ShantyHostContract is the truth about what a host provides: every theme type
## variation, theme item and translation key the addon's scenes and scripts
## really use is in it, and nothing it lists is unused. A variation renamed in a
## scene, a colour looked up in a script, or a key added to a label fails here
## before a host's screen quietly falls back to defaults.
##
## **Uses, not mentions.** A name counts only where the engine will look it up:
## a `theme_type_variation` a scene or script assigns, the item and type of a
## `get_theme_*`/`has_theme_*` call, and the key a `tr()`-like call or a
## translated scene `text` reads. Constants are followed to their values
## (tests/support/gd_source.gd), so a name kept in a constant still counts.

const AddonFiles := preload("res://tests/support/addon_files.gd")
const GdSource := preload("res://tests/support/gd_source.gd")
const CONTRACT_PATH: String = "res://addons/shanty/core/shanty_host_contract.gd"
## The example is a host, not the addon: its own keys are not the contract.
const EXAMPLE_ROOT: String = "res://addons/shanty/example/"
const NODE_PATTERN: String = '^\\[node name="[^"]*" type="([A-Za-z0-9_]+)"'
const SCENE_VARIATION_PATTERN: String = '(?m)^theme_type_variation = &"([A-Za-z0-9_]+)"$'
## A translated scene property holding a key rather than placeholder words.
const SCENE_KEY_PATTERN: String = (
	"(?m)^(?:text|tooltip_text|placeholder_text)" + ' = "([A-Z][A-Z0-9_]+)"$'
)
const THEME_LOOKUP: String = (
	"\\b(?:get|has)_theme_" + "(color|stylebox|font_size|font|constant|icon)(?=\\()"
)
## A lookup's kind, as a theme `.tres` spells it.
const THEME_KINDS: Dictionary[String, String] = {
	"color": "colors",
	"stylebox": "styles",
	"font_size": "font_sizes",
	"font": "fonts",
	"constant": "constants",
	"icon": "icons",
}
const TRANSLATION_LOOKUP: String = (
	"(?:\\b(?:tr|atr|tr_n|atr_n)" + "|ShantyText\\.render|TranslationServer\\.translate)"
)


## The addon's runtime files with these extensions, minus the example and the
## contract itself.
func _runtime_files(extensions: PackedStringArray) -> PackedStringArray:
	var files: PackedStringArray = []
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, extensions):
		if not path.begins_with(EXAMPLE_ROOT) and path != CONTRACT_PATH:
			files.append(path)
	return files


func _sorted(names: Array) -> PackedStringArray:
	var sorted := PackedStringArray()
	for name: Variant in names:
		if not sorted.has(String(name)):
			sorted.append(String(name))
	sorted.sort()
	return sorted


## Every `theme_type_variation` a scene or a script assigns. A script's
## assignment must name at least one variation through a constant or a literal;
## what else it may hold (a speaker's own variation) is the host's data.
func _assigned_variations() -> PackedStringArray:
	var names: Array[String] = []
	var scene_variation := RegEx.create_from_string(SCENE_VARIATION_PATTERN)
	for path: String in _runtime_files(["tscn", "tres"]):
		for found: RegExMatch in scene_variation.search_all(AddonFiles.read(path)):
			names.append(found.get_string(1))
	for path: String in _runtime_files(["gd"]):
		var source: String = GdSource.strip_comments(AddonFiles.read(path))
		for value: String in GdSource.assigned_values(source, "theme_type_variation"):
			var resolved: PackedStringArray = GdSource.resolve(value, source)
			assert_false(resolved.is_empty(), "%s: `%s` names a variation" % [path, value])
			names.append_array(Array(resolved))
	return _sorted(names)


## Every theme item a script looks up, as `<type>/<kind>/<item>`. A lookup with
## no type argument reads the script's own variation, which it must assign.
func _looked_up_items() -> PackedStringArray:
	var items: Array[String] = []
	var lookup := RegEx.create_from_string(THEME_LOOKUP)
	for path: String in _runtime_files(["gd"]):
		var source: String = GdSource.strip_comments(AddonFiles.read(path))
		for found: RegExMatch in lookup.search_all(source):
			var arguments: PackedStringArray = GdSource.split_arguments(
				_call_text(source, found.get_end())
			)
			var item: PackedStringArray = GdSource.resolve(arguments[0], source)
			var type_expression: String = (
				arguments[1]
				if arguments.size() > 1
				else GdSource.own_assignment(source, "theme_type_variation")
			)
			var type: PackedStringArray = GdSource.resolve(type_expression, source)
			var where: String = "%s: %s(%s)" % [path, found.get_string(), ", ".join(arguments)]
			assert_eq(item.size(), 1, "%s names one item" % where)
			assert_eq(type.size(), 1, "%s names one theme type" % where)
			if item.size() == 1 and type.size() == 1:
				items.append("%s/%s/%s" % [type[0], THEME_KINDS[found.get_string(1)], item[0]])
	return _sorted(items)


## The text between the parentheses of the call whose `(` is at `open`.
func _call_text(source: String, open: int) -> String:
	var close: int = GdSource.matching_paren(source, open)
	return source.substr(open + 1, close - open - 1)


## Every key a translated call or scene property reads. An argument that names
## no constant or literal (a line's own `text_key`) is authored data, not the
## contract.
func _translated_keys() -> PackedStringArray:
	var keys: Array[String] = []
	for path: String in _runtime_files(["gd"]):
		var source: String = GdSource.strip_comments(AddonFiles.read(path))
		for arguments: PackedStringArray in GdSource.call_arguments(source, TRANSLATION_LOOKUP):
			if arguments.is_empty():
				continue
			for key: String in GdSource.resolve(arguments[0], source):
				# `""` is the absence of a key, which renders nothing.
				if not key.is_empty():
					keys.append(key)
	var scene_key := RegEx.create_from_string(SCENE_KEY_PATTERN)
	for path: String in _runtime_files(["tscn"]):
		for found: RegExMatch in scene_key.search_all(AddonFiles.read(path)):
			keys.append(found.get_string(1))
	return _sorted(keys)


func _type_of(item: String) -> String:
	return item.get_slice("/", 0)


func test_every_variation_used_is_published_and_every_published_one_is_used() -> void:
	var used: Array[String] = []
	used.append_array(Array(_assigned_variations()))
	for item: String in _looked_up_items():
		used.append(_type_of(item))
	var published: PackedStringArray = _sorted(ShantyHostContract.THEME_TYPE_VARIATIONS.keys())

	assert_eq(_sorted(used), published)


func test_every_theme_item_looked_up_is_published_and_every_published_one_is_looked_up() -> void:
	var published: PackedStringArray = _sorted(Array(ShantyHostContract.THEME_ITEMS))

	assert_eq(_looked_up_items(), published)
	for item: String in published:
		assert_true(
			ShantyHostContract.THEME_TYPE_VARIATIONS.has(StringName(_type_of(item))),
			"%s is on a published variation" % item
		)


func test_every_key_used_is_published_and_every_published_one_is_used() -> void:
	var published: PackedStringArray = _sorted(Array(ShantyHostContract.TRANSLATION_KEYS))

	assert_eq(_translated_keys(), published)


func test_the_scans_read_constants_and_multi_line_calls() -> void:
	var source: String = (
		'const KIND: StringName = &"ShantyThing"\n'
		+ "const ITEM: StringName = ITEM_NAME\n"
		+ 'const ITEM_NAME: StringName = &"edge_color"\n'
		+ "func _ready() -> void:\n"
		+ "\ttheme_type_variation = KIND\n"
		+ "\tother.theme_type_variation = (\n\t\tdata.variation if data else KIND\n\t)\n"
		+ '\tvar c: Color = get_theme_color(\n\t\tITEM, &"ShantyOther"\n\t)\n'
	)

	assert_eq(GdSource.own_assignment(source, "theme_type_variation"), "KIND")
	assert_eq(GdSource.assigned_values(source, "theme_type_variation").size(), 2)
	assert_eq(
		GdSource.resolve(GdSource.assigned_values(source, "theme_type_variation")[1], source),
		PackedStringArray(["ShantyThing"])
	)
	var calls: Array[PackedStringArray] = GdSource.call_arguments(source, "get_theme_color")
	assert_eq(calls.size(), 1)
	assert_eq(GdSource.resolve(calls[0][0], source), PackedStringArray(["edge_color"]))
	assert_eq(GdSource.resolve(calls[0][1], source), PackedStringArray(["ShantyOther"]))
	assert_eq(
		GdSource.resolve("ShantyHostContract.FRAME_VARIATION", ""),
		PackedStringArray(["ShantyFrame"]),
		"a constant on another class is followed"
	)


func test_a_variation_a_scene_assigns_styles_the_class_the_contract_names() -> void:
	var node := RegEx.create_from_string(NODE_PATTERN)
	var variation := RegEx.create_from_string(SCENE_VARIATION_PATTERN)
	var checked: int = 0
	for path: String in _runtime_files(["tscn"]):
		var node_type: String = ""
		for line: String in AddonFiles.read(path).split("\n"):
			if line.begins_with("[node "):
				var typed: RegExMatch = node.search(line)
				node_type = typed.get_string(1) if typed != null else ""
				continue
			var assigned: RegExMatch = variation.search(line)
			if assigned == null or node_type.is_empty():
				continue
			var name: StringName = StringName(assigned.get_string(1))
			assert_eq(
				ShantyHostContract.THEME_TYPE_VARIATIONS.get(name, &""),
				StringName(node_type),
				"%s: %s on a %s" % [path, name, node_type]
			)
			checked += 1
	assert_gt(checked, 0, "the scenes assign variations to check")


func test_the_player_reads_the_ground_the_contract_publishes() -> void:
	assert_eq(CutscenePlayer.FRAME_VARIATION, ShantyHostContract.FRAME_VARIATION)
	assert_eq(CutscenePlayer.GROUND_COLOR, ShantyHostContract.FRAME_GROUND_COLOR)
	assert_eq(CutscenePlayer.DEFAULT_GROUND, ShantyHostContract.FRAME_DEFAULT_GROUND)
	assert_eq(CutscenePlayer.DIM_ALPHA, ShantyHostContract.FRAME_DIM_ALPHA)
	assert_true(
		ShantyHostContract.THEME_ITEMS.has(
			(
				"%s/colors/%s"
				% [ShantyHostContract.FRAME_VARIATION, ShantyHostContract.FRAME_GROUND_COLOR]
			)
		),
		"the ground colour is listed with the other theme items"
	)


func test_the_example_catalogue_declares_every_published_key() -> void:
	var catalogue: String = AddonFiles.read(EXAMPLE_ROOT + "example_strings.csv")
	for key: String in ShantyHostContract.TRANSLATION_KEYS:
		assert_true(catalogue.contains("\n%s," % key), "%s is in the example's strings" % key)
