extends GutTest

## The addon README's tutorial names real things: every translation key it puts
## on a resource is in the example's strings, every class it names in a
## gdscript block is one Shanty or the tutorial itself declares, and every
## `example/` file it points at as a twin exists. A rename that forgets the
## README fails here rather than in a reader's first half hour.

const README: String = "res://addons/shanty/README.md"
const STRINGS: String = "res://addons/shanty/example/example_strings.csv"
const ADDON: String = "res://addons/shanty/"
## A Shanty class, or a name shaped like one of its data or UI classes.
const TYPE_PATTERN: String = (
	"\\b(Shanty[A-Za-z]+"
	+ "|[A-Z][A-Za-z]*(?:Definition|Step|Candidate|Record|Player|Choice|Line))\\b"
)
## Classes the tutorial's own scripts declare, which no installed addon has.
const TUTORIAL_CLASSES: Array[String] = [
	"StoryFlagCondition", "StoryFlagEffect", "StoryContext", "StorySpeakers"
]


func _readme() -> String:
	return FileAccess.get_file_as_string(README)


func _gdscript_blocks(text: String) -> Array[String]:
	var blocks: Array[String] = []
	var fence := RegEx.create_from_string("(?s)```gdscript\\n(.*?)```")
	for found: RegExMatch in fence.search_all(text):
		blocks.append(found.get_string(1))
	return blocks


func test_every_example_key_the_readme_names_is_in_the_example_strings() -> void:
	var catalogue: String = FileAccess.get_file_as_string(STRINGS)
	var keys := RegEx.create_from_string("\\bSHANTY_[A-Z0-9_]*[A-Z0-9]\\b")
	var named: Array[String] = []
	for found: RegExMatch in keys.search_all(_readme()):
		if not named.has(found.get_string()):
			named.append(found.get_string())

	assert_gt(named.size(), 10, "the tutorial names its keys")
	for key: String in named:
		assert_true(catalogue.contains("\n%s," % key), "%s is in example_strings.csv" % key)


func test_every_class_the_tutorial_code_names_exists() -> void:
	var declared: Array[String] = TUTORIAL_CLASSES.duplicate()
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		declared.append(String(entry["class"]))
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


func test_every_twin_the_tutorial_points_at_exists() -> void:
	var twins := RegEx.create_from_string("`(example/[a-z_]+\\.(?:tres|tscn|gd|csv))`")
	var found_any: bool = false
	for found: RegExMatch in twins.search_all(_readme()):
		found_any = true
		var path: String = ADDON + found.get_string(1)
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
	assert_true(found_any, "the tutorial names its twins")
