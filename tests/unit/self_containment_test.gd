extends GutTest

## The addon stands alone: a host copies `addons/shanty/` and nothing else, so no
## file in it may name a path outside that folder -- spelled as a `res://` path or
## as a `uid://` that resolves to one -- no script may load a path it builds at
## runtime, and no script may lean on a global class the host would have to
## supply. A failure names the file.
##
## **One exception, by name.** The Shanty tab opens the host's own files -- its
## config, its CSV, its speakers and conversations -- at paths the host's config
## names, so exactly one script may load a path it is handed:
## `HOST_FILE_READER`. Every other script still loads only literal paths inside
## the addon, and the exception is held to that one file.

const AddonFiles := preload("res://tests/support/addon_files.gd")
const GdSource := preload("res://tests/support/gd_source.gd")
## Every text format in the addon that can hold a path or a class name.
const SCANNED: PackedStringArray = ["gd", "tscn", "tres", "cfg", "csv", "json"]
const PATH_PATTERN: String = "res://[^\\s\"'()\\[\\]]*"
const SCRIPT_CLASS_PATTERN: String = 'script_class="([A-Za-z_][A-Za-z0-9_]*)"'
const UID_PATTERN: String = "uid://[0-9a-z]+"
## `load(`, `preload(` and `ResourceLoader.load(` alike.
const LOAD_CALL: String = "\\b(?:preload|load)"
const HOST_FILE_READER: String = "res://addons/shanty/editor/model/shanty_files.gd"


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


## The path Godot resolves `uid` to, or "" when it names nothing.
static func _uid_path(uid: String) -> String:
	var id: int = ResourceUID.text_to_id(uid)
	if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
		return ""
	return ResourceUID.get_id_path(id)


func test_every_uid_resolves_inside_the_addon() -> void:
	var pattern := RegEx.create_from_string(UID_PATTERN)
	var extensions: PackedStringArray = SCANNED.duplicate()
	extensions.append("uid")
	var outside: PackedStringArray = []
	var resolved: int = 0
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, extensions):
		for found: RegExMatch in pattern.search_all(AddonFiles.read(path)):
			var target: String = _uid_path(found.get_string())
			if target.begins_with(AddonFiles.ADDON_ROOT):
				resolved += 1
			else:
				var named: String = target if not target.is_empty() else "nothing Godot knows"
				outside.append("%s -> %s -> %s" % [path, found.get_string(), named])
	assert_eq(outside, PackedStringArray(), "every uid:// names a file inside the addon")
	assert_gt(resolved, 20, "the scan resolved the addon's own uids, so it is not vacuous")


func test_the_uid_scan_tells_inside_from_outside() -> void:
	var own: String = AddonFiles.read(AddonFiles.ADDON_ROOT + "core/shanty_runner.gd.uid")
	var foreign: String = FileAccess.get_file_as_string(
		"res://tests/unit/self_containment_test.gd.uid"
	)

	assert_eq(_uid_path(own.strip_edges()), AddonFiles.ADDON_ROOT + "core/shanty_runner.gd")
	assert_eq(
		_uid_path(foreign.strip_edges()),
		"res://tests/unit/self_containment_test.gd",
		"a uid outside the addon resolves outside it, which the scan above would report"
	)
	assert_eq(_uid_path("uid://notarealuid0"), "")


func test_every_load_names_a_fixed_path_inside_the_addon() -> void:
	var refused: PackedStringArray = []
	var checked: int = 0
	for path: String in AddonFiles.list(AddonFiles.ADDON_ROOT, ["gd"]):
		if path == HOST_FILE_READER:
			continue
		var source: String = GdSource.strip_comments(AddonFiles.read(path))
		for arguments: PackedStringArray in GdSource.call_arguments(source, LOAD_CALL):
			var call_text: String = "%s: load(%s)" % [path, ", ".join(arguments)]
			var target: String = (
				GdSource.resolve_single(arguments[0], source) if not arguments.is_empty() else ""
			)
			if target.begins_with("uid://"):
				target = _uid_path(target)
			if target.is_empty():
				refused.append("%s builds its path at runtime" % call_text)
			elif not target.begins_with(AddonFiles.ADDON_ROOT):
				refused.append("%s loads %s" % [call_text, target])
			checked += 1
	assert_eq(refused, PackedStringArray(), "every load names a literal path inside the addon")
	assert_gt(checked, 3, "the scan found the addon's loads")


func test_only_the_host_file_reader_loads_a_path_it_is_handed() -> void:
	var source: String = GdSource.strip_comments(AddonFiles.read(HOST_FILE_READER))
	var calls: Array[PackedStringArray] = GdSource.call_arguments(source, LOAD_CALL)

	assert_eq(calls.size(), 1, "the reader funnels every host load through one call")
	assert_eq(
		GdSource.resolve_single(calls[0][0], source),
		"",
		"and that call is the runtime path the exception exists for"
	)


func test_the_load_scan_refuses_a_constructed_path() -> void:
	var source: String = (
		'const ROOT: String = "res://addons/shanty/"\n'
		+ 'const FIXED: String = "res://addons/shanty/plugin.cfg"\n'
		+ "func _ready() -> void:\n"
		+ '\tload(ROOT + "plugin.cfg")\n'
		+ "\tload(FIXED)\n"
		+ "\tResourceLoader.load(name)\n"
		+ "\t# load(in_a_comment)\n"
	)
	var calls: Array[PackedStringArray] = GdSource.call_arguments(
		GdSource.strip_comments(source), LOAD_CALL
	)

	assert_eq(calls.size(), 3, "comments are not calls")
	assert_eq(GdSource.resolve_single(calls[0][0], source), "", "a concatenation is refused")
	assert_eq(GdSource.resolve_single(calls[1][0], source), "res://addons/shanty/plugin.cfg")
	assert_eq(GdSource.resolve_single(calls[2][0], source), "", "a variable is refused")


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
