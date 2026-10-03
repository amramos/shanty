@tool
extends VBoxContainer

## One line of the table: number, speaker, face, source text with its key and
## the key's state, target text, flag toggles and notes; under it the line's
## label, reply speaker, conditions and effects, and Insert after, up, down and
## remove; under those its replies.

signal structure_changed
signal inspect_requested(resource: Resource, owner: Resource)
## The writer is working on this line: its source or target cell took focus.
signal line_picked(line: DialogueLine)

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const CellEdit := preload("res://addons/shanty/editor/shanty_cell_edit.gd")
const PickerMenu := preload("res://addons/shanty/editor/shanty_picker_menu.gd")
const EntryChips := preload("res://addons/shanty/editor/shanty_entry_chips.gd")
const ChoiceRow := preload("res://addons/shanty/editor/shanty_choice_row.gd")
const NUMBER_WIDTH: float = 36.0
const SPEAKER_WIDTH: float = 120.0
const FACE_WIDTH: float = 100.0
const FLAGS_WIDTH: float = 140.0
const NOTES_WIDTH: float = 160.0
const FIRST_FACE: String = "(first face)"

var _model: ShantyEditorModel = null
var _conversation: ConversationDefinition = null
var _line: DialogueLine = null
var _index: int = 0
var _face: OptionButton = OptionButton.new()
var _key_state: Label = null
var _replies: Array[ChoiceRow] = []


func setup(model: ShantyEditorModel, conversation: ConversationDefinition, index: int) -> void:
	_model = model
	_conversation = conversation
	_index = index
	_line = conversation.lines[index]
	add_child(_main_row())
	add_child(_detail_row())
	var indent: float = NUMBER_WIDTH + SPEAKER_WIDTH + FACE_WIDTH
	for reply: int in _line.choices.size():
		var row: ChoiceRow = ChoiceRow.new()
		row.setup(model, conversation, _line, reply, indent)
		row.structure_changed.connect(structure_changed.emit)
		row.inspect_requested.connect(inspect_requested.emit)
		add_child(row)
		_replies.append(row)
	add_child(HSeparator.new())


func apply_issues(issues: Array[ShantyLintIssue]) -> void:
	Palette.show_key_state(_key_state, _line.text_key, issues)
	for row: ChoiceRow in _replies:
		row.apply_issues(issues)


func _main_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var number := Label.new()
	number.text = str(_index + 1)
	number.custom_minimum_size.x = NUMBER_WIDTH
	row.add_child(number)
	row.add_child(_speaker_picker())
	_face.custom_minimum_size.x = FACE_WIDTH
	_fill_faces()
	_face.item_selected.connect(
		func(at: int) -> void:
			var tag: String = "" if at == 0 else _face.get_item_text(at)
			ShantyConversationEdits.edit(_model, _conversation, _line, &"face", StringName(tag))
	)
	row.add_child(_face)
	var source_box := VBoxContainer.new()
	source_box.size_flags_horizontal = SIZE_EXPAND_FILL
	var source := LineEdit.new()
	source.text = _model.text(_line.text_key, _model.source_locale)
	source.text_changed.connect(
		func(value: String) -> void: _model.set_text(_line.text_key, _model.source_locale, value)
	)
	source.focus_entered.connect(func() -> void: line_picked.emit(_line))
	source_box.add_child(source)
	_key_state = Palette.caption(_line.text_key, Palette.muted())
	source_box.add_child(_key_state)
	row.add_child(source_box)
	var target: CellEdit = CellEdit.new()
	target.size_flags_horizontal = SIZE_EXPAND_FILL
	target.size_flags_vertical = SIZE_SHRINK_BEGIN
	target.show_text(_model.text(_line.text_key, _model.target_locale))
	target.text_changed.connect(
		func(value: String) -> void: _model.set_text(_line.text_key, _model.target_locale, value)
	)
	target.focus_entered.connect(func() -> void: line_picked.emit(_line))
	row.add_child(target)
	row.add_child(_flag_toggles())
	var notes := LineEdit.new()
	notes.placeholder_text = "notes"
	notes.custom_minimum_size.x = NOTES_WIDTH
	notes.size_flags_vertical = SIZE_SHRINK_BEGIN
	notes.text = _model.notes(_line.text_key)
	notes.text_changed.connect(func(value: String) -> void: _model.set_notes(_line.text_key, value))
	row.add_child(notes)
	return row


func _speaker_picker() -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = SPEAKER_WIDTH
	picker.size_flags_vertical = SIZE_SHRINK_BEGIN
	var ids: PackedStringArray = ShantySpeakerEdits.ids(_model)
	if not ids.has(String(_line.speaker_id)):
		ids.append(String(_line.speaker_id))
	for id: String in ids:
		picker.add_item(id)
	picker.select(ids.find(String(_line.speaker_id)))
	picker.item_selected.connect(
		func(at: int) -> void:
			var id: StringName = StringName(picker.get_item_text(at))
			ShantyConversationEdits.set_speaker(_model, _conversation, _line, id)
			_fill_faces()
	)
	return picker


func _fill_faces() -> void:
	_face.clear()
	_face.add_item(FIRST_FACE)
	var tags: PackedStringArray = ShantySpeakerEdits.face_tags(_model, _line.speaker_id)
	if not _line.face.is_empty() and not tags.has(String(_line.face)):
		tags.append(String(_line.face))
	for tag: String in tags:
		_face.add_item(tag)
	_face.select(0 if _line.face.is_empty() else tags.find(String(_line.face)) + 1)


func _flag_toggles() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = FLAGS_WIDTH
	var on: PackedStringArray = _model.flags(_line.text_key)
	for flag: String in _model.config.flag_names():
		var toggle := Button.new()
		toggle.text = flag
		toggle.toggle_mode = true
		toggle.button_pressed = on.has(flag)
		toggle.tooltip_text = "Checks this line against the words the config forbids for %s" % flag
		toggle.toggled.connect(
			func(pressed: bool) -> void: _model.set_flag(_line.text_key, flag, pressed)
		)
		flow.add_child(toggle)
	return flow


func _detail_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.custom_minimum_size.x = NUMBER_WIDTH
	row.add_child(spacer)
	var label := LineEdit.new()
	label.placeholder_text = "label (a jump target)"
	label.custom_minimum_size.x = SPEAKER_WIDTH + FACE_WIDTH
	label.text = String(_line.label)
	label.text_changed.connect(
		func(value: String) -> void:
			ShantyConversationEdits.edit(
				_model, _conversation, _line, &"label", StringName(value.strip_edges())
			)
	)
	row.add_child(label)
	_add_entries(row, &"ShantyCondition", "+ Condition", &"conditions", "If:")
	_add_entries(row, &"ShantyEffect", "+ Effect", &"effects", "Then:")
	var choice := Button.new()
	choice.text = "+ Choice"
	choice.disabled = _line.choices.size() >= ShantyLint.MAX_REPLIES
	choice.pressed.connect(
		func() -> void:
			if ShantyConversationEdits.add_choice(_model, _conversation, _line) != null:
				structure_changed.emit()
	)
	row.add_child(choice)
	if not _line.choices.is_empty():
		row.add_child(_reply_speaker_picker())
	_add_line_actions(row)
	return row


## Insert after, up, down and remove: each changes the order or the set of
## lines, never a key, and asks the table to rebuild.
func _add_line_actions(row: HBoxContainer) -> void:
	var last: int = _conversation.lines.size() - 1
	var actions: Array[Array] = [
		["Insert after", "A new line after this one", false, _on_insert_after],
		["↑", "Move this line up", _index == 0, _on_move.bind(-1)],
		["↓", "Move this line down", _index == last, _on_move.bind(1)],
		["Remove line", "Remove this line and its unused rows", false, _on_remove],
	]
	for action: Array in actions:
		var button := Button.new()
		button.text = action[0]
		button.tooltip_text = action[1]
		button.disabled = action[2]
		button.pressed.connect(action[3])
		row.add_child(button)


func _on_insert_after() -> void:
	if ShantyConversationEdits.insert_line_after(_model, _conversation, _index) != null:
		structure_changed.emit()


func _on_move(step: int) -> void:
	if ShantyConversationEdits.move_line(_model, _conversation, _index, _index + step):
		structure_changed.emit()


func _on_remove() -> void:
	ShantyConversationEdits.remove_line(_model, _conversation, _index)
	structure_changed.emit()


## Who answers this line's replies; the first item leaves it to the host.
func _reply_speaker_picker() -> OptionButton:
	var picker := OptionButton.new()
	picker.tooltip_text = "Who answers these replies"
	picker.add_item("(host's reply speaker)")
	var ids: PackedStringArray = ShantySpeakerEdits.ids(_model)
	for id: String in ids:
		picker.add_item(id)
	picker.select(ids.find(String(_line.reply_speaker_id)) + 1)
	picker.item_selected.connect(
		func(at: int) -> void:
			var id: String = "" if at == 0 else picker.get_item_text(at)
			ShantyConversationEdits.edit(
				_model, _conversation, _line, &"reply_speaker_id", StringName(id)
			)
	)
	return picker


func _add_entries(
	row: HBoxContainer, base: StringName, caption: String, property: StringName, title: String
) -> void:
	var picker: PickerMenu = PickerMenu.new()
	picker.setup(base, caption)
	picker.picked.connect(
		func(path: String) -> void:
			var made: Resource = (
				ShantyConversationEdits.add_condition(_model, _conversation, _line, path)
				if property == &"conditions"
				else ShantyConversationEdits.add_effect(_model, _conversation, _line, path)
			)
			if made != null:
				structure_changed.emit()
				inspect_requested.emit(made, _conversation)
	)
	row.add_child(picker)
	var chips: EntryChips = EntryChips.new()
	chips.show_entries(title, _line.get(property))
	chips.inspect_requested.connect(
		func(entry: Resource) -> void: inspect_requested.emit(entry, _conversation)
	)
	chips.remove_requested.connect(
		func(at: int) -> void:
			ShantyConversationEdits.remove_entry(_model, _conversation, _line, property, at)
			structure_changed.emit()
	)
	row.add_child(chips)
