@tool
extends MenuButton

## A menu of every class the project declares under one Shanty base -- a
## condition, an effect -- read afresh each time it opens, so a class the host
## has just written is there without a restart. A script with no `class_name`
## is reached through "Script file...", which the model checks extends the base.

## The script of the class the writer picked.
signal picked(script_path: String)

const BROWSE_ID: int = 10000

var _base: StringName = &""
var _paths: PackedStringArray = []
var _dialog: EditorFileDialog = null


func setup(base: StringName, caption: String) -> void:
	_base = base
	text = caption
	flat = false
	about_to_popup.connect(_fill)
	get_popup().id_pressed.connect(_on_id_pressed)


func _fill() -> void:
	var popup: PopupMenu = get_popup()
	popup.clear()
	_paths.clear()
	for entry: Dictionary in ShantyClassCatalog.subclasses_of(_base):
		popup.add_item(String(entry["class"]), _paths.size())
		_paths.append(String(entry["path"]))
	if _paths.is_empty():
		popup.add_item("No %s subclass has a class_name yet" % _base)
		popup.set_item_disabled(0, true)
	popup.add_separator()
	popup.add_item("Script file...", BROWSE_ID)


func _on_id_pressed(id: int) -> void:
	if id == BROWSE_ID:
		_browse()
	elif id >= 0 and id < _paths.size():
		picked.emit(_paths[id])


func _browse() -> void:
	if _dialog == null:
		_dialog = EditorFileDialog.new()
		_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_dialog.add_filter("*.gd", "GDScript")
		_dialog.file_selected.connect(func(path: String) -> void: picked.emit(path))
		add_child(_dialog)
	_dialog.popup_file_dialog()
