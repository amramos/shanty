extends GutTest

## What the tab asks of the editor's filesystem after a Save: a known CSV is
## reimported; a file the filesystem does not know yet, a staged file that is
## gone, and every resource are updated -- never a scan.

const FilesystemRefresh := preload("res://addons/shanty/editor/shanty_filesystem_refresh.gd")
const CSV_PATH: String = "res://addons/shanty/example/example_strings.csv"
const NEW_CSV: String = "res://nowhere/new_strings.csv"
const TALK: String = "res://addons/shanty/example/example_conversation.tres"
const STAGED: String = "res://addons/shanty/example/example_conversation.shanty-tmp.tres"


func test_a_known_csv_is_reimported_and_everything_else_updated() -> void:
	var known: PackedStringArray = [CSV_PATH, TALK]
	var type_of: Callable = func(path: String) -> String:
		return "Resource" if known.has(path) else ""

	var plan: Array[PackedStringArray] = FilesystemRefresh.split(
		PackedStringArray([STAGED, TALK, CSV_PATH, NEW_CSV]), type_of
	)

	assert_eq(plan[0], PackedStringArray([STAGED, TALK, NEW_CSV]), "updated, in order")
	assert_eq(plan[1], PackedStringArray([CSV_PATH]), "reimported")


func test_a_csv_the_filesystem_does_not_know_yet_is_updated_not_reimported() -> void:
	var plan: Array[PackedStringArray] = FilesystemRefresh.split(
		PackedStringArray([CSV_PATH]), func(_path: String) -> String: return ""
	)

	assert_eq(plan[0], PackedStringArray([CSV_PATH]))
	assert_eq(plan[1], PackedStringArray())
