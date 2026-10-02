extends GutTest

## The addon stands alone: a host copies `addons/shanty/` and nothing else, so no
## file in it may name a path outside that folder, and no script may lean on a
## global class the host would have to supply. A failure names the file.

const AddonFiles := preload("res://tests/support/addon_files.gd")
## Every text format in the addon that can hold a path or a class name.
const SCANNED: PackedStringArray = ["gd", "tscn", "tres", "cfg", "csv", "json"]
const PATH_PATTERN: String = "res://[^\\s\"'()\\[\\]]*"
const SCRIPT_CLASS_PATTERN: String = 'script_class="([A-Za-z_][A-Za-z0-9_]*)"'


func _addon_classes() -> Dictionary[StringName, bool]:
	var names: Dictionary[StringName, bool] = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["path"]).begins_with(AddonFiles.ADDON_ROOT):
			names[StringName(entry["class"])] = true
	return names


## Global classes the project declares outside the addon: in a host, exactly the
## names the addon must never use.
func _foreign_classes() -> PackedStringArray:
	var names: PackedStringArray = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if not String(entry["path"]).begins_with(AddonFiles.ADDON_ROOT):
			names.append(String(entry["class"]))
	return names


## The foreign class names `text` mentions as whole words.
static func _mentions(text: String, foreign: PackedStringArray) -> PackedStringArray:
	var hits: PackedStringArray = []
	for name: String in foreign:
		var word := RegEx.create_from_string("\\b%s\\b" % name)
		if word.search(text) != null:
			hits.append(name)
	return hits


func test_the_addon_has_files_to_scan() -> void:
	var files: PackedStringArray = AddonFiles.list(AddonFiles.ADDON_ROOT, SCANNED)
	assert_gt(files.size(), 50, "the scan reaches every subfolder")


func test_no_path_points_outside_the_addon() -> void:
	var pattern := RegEx.create_from_string(PATH_PATTERN)
	var outside: PackedStringArray = []
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, SCANNED):
		for found: RegExMatch in pattern.search_all(AddonFiles.read(path)):
			if not found.get_string().begins_with(AddonFiles.ADDON_ROOT):
				outside.append("%s -> %s" % [path, found.get_string()])
	assert_eq(outside, PackedStringArray(), "every res:// path stays inside the addon")


func test_every_resource_script_class_is_the_addons_own() -> void:
	var own: Dictionary[StringName, bool] = _addon_classes()
	var pattern := RegEx.create_from_string(SCRIPT_CLASS_PATTERN)
	var foreign: PackedStringArray = []
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, ["tscn", "tres"]):
		for found: RegExMatch in pattern.search_all(AddonFiles.read(path)):
			var name: StringName = StringName(found.get_string(1))
			if not own.has(name) and not ClassDB.class_exists(name):
				foreign.append("%s -> %s" % [path, name])
	assert_eq(foreign, PackedStringArray(), "resources name only Shanty or engine classes")


func test_no_script_names_a_class_declared_outside_the_addon() -> void:
	var foreign: PackedStringArray = _foreign_classes()
	# This project's test framework declares global classes, so the scan below
	# has real names to look for rather than passing on an empty list.
	assert_true(foreign.has("GutTest"), "the scan knows at least one outside class")
	var hits: PackedStringArray = []
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, ["gd", "tscn", "tres"]):
		for name: String in _mentions(AddonFiles.read(path), foreign):
			hits.append("%s -> %s" % [path, name])
	assert_eq(hits, PackedStringArray(), "the addon leans on no host class")


func test_the_class_scan_finds_a_whole_word_and_ignores_a_longer_one() -> void:
	var foreign: PackedStringArray = ["HostThing"]

	assert_eq(_mentions("var x: HostThing = null", foreign), foreign)
	assert_eq(_mentions("var x: HostThingy = null", foreign), PackedStringArray())


func test_every_class_the_addon_declares_is_registered() -> void:
	var own: Dictionary[StringName, bool] = _addon_classes()
	var declaration := RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, ["gd"]):
		var found: RegExMatch = declaration.search(AddonFiles.read(path))
		if found != null:
			assert_true(own.has(StringName(found.get_string(1))), "%s is registered" % path)
