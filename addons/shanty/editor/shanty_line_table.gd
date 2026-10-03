@tool
extends VBoxContainer

## The conversation editor: its key prefix, a header naming the two locales on
## show, one row per line (each with Insert after and up/down), and + Line.
## Each row binds straight to the model; the table only rebuilds when lines or
## replies are added, removed or moved.

signal inspect_requested(resource: Resource, owner: Resource)
signal line_picked(line: DialogueLine)

const LineRow := preload("res://addons/shanty/editor/shanty_line_row.gd")

var _model: ShantyEditorModel = null
var _conversation: ConversationDefinition = null
var _rows: Array[LineRow] = []
var _issues: Array[ShantyLintIssue] = []


func show_conversation(model: ShantyEditorModel, conversation: ConversationDefinition) -> void:
	_model = model
	_conversation = conversation
	rebuild()


## Marks every key with what the last lint found.
func apply_issues(issues: Array[ShantyLintIssue]) -> void:
	_issues = issues
	for row: LineRow in _rows:
		row.apply_issues(issues)


func rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_rows.clear()
	if _conversation == null:
		return
	add_child(_title_row())
	add_child(_column_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	add_child(scroll)
	for index: int in _conversation.lines.size():
		if _conversation.lines[index] == null:
			continue
		var row: LineRow = LineRow.new()
		row.setup(_model, _conversation, index)
		row.structure_changed.connect(rebuild)
		row.inspect_requested.connect(inspect_requested.emit)
		row.line_picked.connect(line_picked.emit)
		list.add_child(row)
		_rows.append(row)
	var add := Button.new()
	add.text = "+ Line"
	add.size_flags_horizontal = SIZE_SHRINK_BEGIN
	add.pressed.connect(_on_add_line)
	list.add_child(add)
	apply_issues(_issues)


func _title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = String(_conversation.conversation_id)
	title.tooltip_text = _model.path_of(_conversation)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(title)
	var caption := Label.new()
	caption.text = "Key prefix"
	row.add_child(caption)
	var prefix := LineEdit.new()
	prefix.text = ShantyConversationEdits.prefix_of(_model, _conversation)
	prefix.custom_minimum_size.x = 220
	prefix.tooltip_text = "New lines are keyed under this prefix. Existing keys never change."
	prefix.text_submitted.connect(
		func(value: String) -> void:
			ShantyConversationEdits.set_prefix(_model, _conversation, value.strip_edges())
	)
	row.add_child(prefix)
	return row


func _column_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	var columns: Array = [
		["#", LineRow.NUMBER_WIDTH],
		["Speaker", LineRow.SPEAKER_WIDTH],
		["Face", LineRow.FACE_WIDTH],
		["Source: %s" % _model.source_locale, -1.0],
		["Target: %s" % _model.target_locale, -1.0],
		["Flags", LineRow.FLAGS_WIDTH],
		["Notes", LineRow.NOTES_WIDTH],
	]
	for column: Array in columns:
		var label := Label.new()
		label.text = column[0]
		if float(column[1]) < 0.0:
			label.size_flags_horizontal = SIZE_EXPAND_FILL
		else:
			label.custom_minimum_size.x = float(column[1])
		row.add_child(label)
	return row


func _on_add_line() -> void:
	var last: int = _conversation.lines.size() - 1
	if ShantyConversationEdits.insert_line_after(_model, _conversation, last) != null:
		rebuild()
