@tool
extends HBoxContainer

## One reply under a line: its source and target text, its key and the key's
## state, where it jumps, and its effects.

signal structure_changed
signal inspect_requested(resource: Resource, owner: Resource)

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const CellEdit := preload("res://addons/shanty/editor/shanty_cell_edit.gd")
const PickerMenu := preload("res://addons/shanty/editor/shanty_picker_menu.gd")
const EntryChips := preload("res://addons/shanty/editor/shanty_entry_chips.gd")
const NEXT_LINE: String = "(next line)"

var _model: ShantyEditorModel = null
var _conversation: ConversationDefinition = null
var _line: DialogueLine = null
var _choice: DialogueChoice = null
var _key_state: Label = null


## Builds the row for reply `index` of `line`, indented by `indent` pixels.
func setup(
	model: ShantyEditorModel,
	conversation: ConversationDefinition,
	line: DialogueLine,
	index: int,
	indent: float
) -> void:
	_model = model
	_conversation = conversation
	_line = line
	_choice = line.choices[index]
	var marker := Label.new()
	marker.text = "reply %s" % ShantyKeyScheme.REPLY_LETTERS[mini(index, 2)]
	marker.custom_minimum_size.x = indent
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(marker)
	var source_box := VBoxContainer.new()
	source_box.size_flags_horizontal = SIZE_EXPAND_FILL
	var source := LineEdit.new()
	source.text = model.text(_choice.text_key, model.source_locale)
	source.text_changed.connect(
		func(value: String) -> void: _model.set_text(_choice.text_key, _model.source_locale, value)
	)
	source_box.add_child(source)
	_key_state = Palette.caption(_choice.text_key, Palette.muted())
	source_box.add_child(_key_state)
	add_child(source_box)
	var target: CellEdit = CellEdit.new()
	target.size_flags_horizontal = SIZE_EXPAND_FILL
	target.show_text(model.text(_choice.text_key, model.target_locale))
	target.text_changed.connect(
		func(value: String) -> void: _model.set_text(_choice.text_key, _model.target_locale, value)
	)
	add_child(target)
	add_child(_jump_picker())
	_add_effects()
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(
		func() -> void:
			ShantyConversationEdits.remove_choice(_model, _conversation, _line, index)
			structure_changed.emit()
	)
	add_child(remove)


func apply_issues(issues: Array[ShantyLintIssue]) -> void:
	Palette.show_key_state(_key_state, _choice.text_key, issues)


func _jump_picker() -> OptionButton:
	var jump := OptionButton.new()
	jump.tooltip_text = "Where the conversation goes after this reply"
	jump.add_item(NEXT_LINE)
	for line: DialogueLine in _conversation.lines:
		if line != null and not line.label.is_empty():
			jump.add_item(String(line.label))
			jump.set_item_metadata(jump.item_count - 1, String(line.label))
	if not _choice.jump_label.is_empty():
		var at: int = _item_index(jump, String(_choice.jump_label))
		if at < 0:
			jump.add_item("%s (missing)" % _choice.jump_label)
			jump.set_item_metadata(jump.item_count - 1, String(_choice.jump_label))
			at = jump.item_count - 1
		jump.select(at)
	jump.item_selected.connect(
		func(at: int) -> void:
			var label: String = "" if at == 0 else String(jump.get_item_metadata(at))
			ShantyConversationEdits.edit(
				_model, _conversation, _choice, &"jump_label", StringName(label)
			)
	)
	return jump


func _add_effects() -> void:
	var picker: PickerMenu = PickerMenu.new()
	picker.setup(&"ShantyEffect", "+ Effect")
	picker.picked.connect(
		func(path: String) -> void:
			var effect: ShantyEffect = ShantyConversationEdits.add_effect(
				_model, _conversation, _choice, path
			)
			if effect != null:
				structure_changed.emit()
				inspect_requested.emit(effect, _conversation)
	)
	add_child(picker)
	var chips: EntryChips = EntryChips.new()
	chips.show_entries("", _choice.effects)
	chips.inspect_requested.connect(
		func(entry: Resource) -> void: inspect_requested.emit(entry, _conversation)
	)
	chips.remove_requested.connect(
		func(at: int) -> void:
			ShantyConversationEdits.remove_entry(_model, _conversation, _choice, &"effects", at)
			structure_changed.emit()
	)
	add_child(chips)


## The index of the item whose metadata is `label`, or -1. Every label item
## carries its label as metadata, so "(missing)" items are found too.
static func _item_index(button: OptionButton, label: String) -> int:
	for at: int in range(1, button.item_count):
		if String(button.get_item_metadata(at)) == label:
			return at
	return -1
