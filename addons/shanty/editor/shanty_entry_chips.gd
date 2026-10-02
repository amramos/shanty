@tool
extends HBoxContainer

## The conditions or effects on a line or a reply, one chip each: the chip opens
## the entry in the editor's Inspector, where its exports are edited, and its
## x removes it.

signal inspect_requested(resource: Resource)
signal remove_requested(index: int)


## Shows `entries` under `caption`; nothing at all when there are none.
func show_entries(caption: String, entries: Array) -> void:
	for child: Node in get_children():
		child.queue_free()
	if entries.is_empty():
		return
	var title := Label.new()
	title.text = caption
	add_child(title)
	for index: int in entries.size():
		var entry: Resource = entries[index]
		var open := Button.new()
		open.text = name_of(entry)
		open.tooltip_text = "Edit in the Inspector"
		open.pressed.connect(func() -> void: inspect_requested.emit(entry))
		add_child(open)
		var remove := Button.new()
		remove.text = "x"
		remove.tooltip_text = "Remove"
		remove.pressed.connect(func() -> void: remove_requested.emit(index))
		add_child(remove)


## A resource's class as a writer knows it: its script's `class_name`, else the
## script's file name.
static func name_of(entry: Resource) -> String:
	if entry == null:
		return "(empty)"
	var script: Script = entry.get_script() as Script
	if script == null:
		return entry.get_class()
	if not String(script.get_global_name()).is_empty():
		return String(script.get_global_name())
	return script.resource_path.get_file().get_basename()
