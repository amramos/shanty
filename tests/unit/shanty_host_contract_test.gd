extends GutTest

## ShantyHostContract is the truth about what a host provides: every theme type
## variation and translation key the addon's scenes and scripts use is in it, and
## nothing it lists is unused. A variation renamed in a scene, or a key added to a
## script, fails here before a host's screen quietly falls back to defaults.

const AddonFiles := preload("res://tests/support/addon_files.gd")
const CONTRACT_PATH: String = "res://addons/shanty/core/shanty_host_contract.gd"
## The example is a host, not the addon: its own keys are not the contract.
const EXAMPLE_ROOT: String = "res://addons/shanty/example/"
const VARIATION_PATTERN: String = '&"(Shanty[A-Z][A-Za-z0-9]*)"'
const KEY_PATTERN: String = '"(SHANTY_[A-Z0-9_]+)"'
const NODE_PATTERN: String = '^\\[node name="[^"]*" type="([A-Za-z0-9_]+)"'
const SCENE_VARIATION_PATTERN: String = '^theme_type_variation = &"([A-Za-z0-9_]+)"'


## The addon's runtime files: scenes, resources and scripts, minus the example
## and the contract itself.
func _runtime_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, ["gd", "tscn", "tres"]):
		if not path.begins_with(EXAMPLE_ROOT) and path != CONTRACT_PATH:
			files.append(path)
	return files


func _used(pattern_text: String) -> PackedStringArray:
	var pattern := RegEx.create_from_string(pattern_text)
	var names: PackedStringArray = []
	for path: String in _runtime_files():
		for found: RegExMatch in pattern.search_all(AddonFiles.read(path)):
			if not names.has(found.get_string(1)):
				names.append(found.get_string(1))
	names.sort()
	return names


func _sorted(names: Array) -> PackedStringArray:
	var sorted := PackedStringArray()
	for name: Variant in names:
		sorted.append(String(name))
	sorted.sort()
	return sorted


func test_every_variation_used_is_published_and_every_published_one_is_used() -> void:
	var published: PackedStringArray = _sorted(ShantyHostContract.THEME_TYPE_VARIATIONS.keys())

	assert_eq(_used(VARIATION_PATTERN), published)


func test_every_key_used_is_published_and_every_published_one_is_used() -> void:
	var published: PackedStringArray = _sorted(Array(ShantyHostContract.TRANSLATION_KEYS))

	assert_eq(_used(KEY_PATTERN), published)


func test_a_variation_a_scene_assigns_styles_the_class_the_contract_names() -> void:
	var node := RegEx.create_from_string(NODE_PATTERN)
	var variation := RegEx.create_from_string(SCENE_VARIATION_PATTERN)
	var checked: int = 0
	for path: String in _runtime_files():
		if path.get_extension() != "tscn":
			continue
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
		ShantyHostContract.THEME_TYPE_VARIATIONS.has(ShantyHostContract.FRAME_VARIATION),
		"the frame's type is listed with the others"
	)


func test_the_example_catalogue_declares_every_published_key() -> void:
	var catalogue: String = AddonFiles.read(EXAMPLE_ROOT + "example_strings.csv")
	for key: String in ShantyHostContract.TRANSLATION_KEYS:
		assert_true(catalogue.contains("\n%s," % key), "%s is in the example's strings" % key)
