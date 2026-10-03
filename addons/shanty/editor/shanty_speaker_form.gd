@tool
extends VBoxContainer

## The speaker form: the id, the name key (named by the scheme, editable), the
## name in the source and target locales, notes, and the faces -- an emotion
## tag each, with a texture through the editor's own resource picker. A face
## with no texture is allowed: the bar draws a flat plate instead.

## The writer asked to see a face's texture in the Inspector.
signal inspect_requested(resource: Resource, owner: Resource)

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const CellEdit := preload("res://addons/shanty/editor/shanty_cell_edit.gd")

var _model: ShantyEditorModel = null
var _speaker: SpeakerDefinition = null


## Shows `speaker`, rebuilding the form.
func show_speaker(model: ShantyEditorModel, speaker: SpeakerDefinition) -> void:
	_model = model
	_speaker = speaker
	for child: Node in get_children():
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	add_child(grid)
	_row(grid, "Id", _caption(String(speaker.speaker_id)))
	var key := LineEdit.new()
	key.text = speaker.name_key
	key.text_submitted.connect(_on_key_submitted)
	key.focus_exited.connect(func() -> void: _on_key_submitted(key.text))
	_row(grid, "Name key", key)
	_row(grid, "Name (%s)" % model.source_locale, _cell(model.source_locale, false))
	_row(grid, "Name (%s)" % model.target_locale, _cell(model.target_locale, true))
	var notes := LineEdit.new()
	notes.text = model.notes(speaker.name_key)
	notes.text_changed.connect(
		func(value: String) -> void: model.set_notes(_speaker.name_key, value)
	)
	_row(grid, "Notes", notes)
	add_child(HSeparator.new())
	add_child(_caption("Faces"))
	for index: int in speaker.faces.size():
		add_child(_face_row(index))
	add_child(_new_face_row())


func _cell(locale: String, dashed: bool) -> LineEdit:
	var value: String = _model.text(_speaker.name_key, locale)
	var edit: LineEdit = null
	if dashed:
		var cell: CellEdit = CellEdit.new()
		cell.show_text(value)
		edit = cell
	else:
		edit = LineEdit.new()
		edit.text = value
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.editable = not locale.is_empty()
	edit.text_changed.connect(
		func(written: String) -> void: _model.set_text(_speaker.name_key, locale, written)
	)
	return edit


func _face_row(index: int) -> HBoxContainer:
	var face: SpeakerFace = _speaker.faces[index]
	var row := HBoxContainer.new()
	var tag := LineEdit.new()
	tag.text = String(face.tag)
	tag.custom_minimum_size.x = 120
	tag.text_submitted.connect(
		func(value: String) -> void:
			if not ShantySpeakerEdits.set_face_tag(_model, _speaker, index, value):
				tag.text = String(_speaker.faces[index].tag)
	)
	row.add_child(tag)
	var picker := EditorResourcePicker.new()
	picker.base_type = "Texture2D"
	picker.edited_resource = face.texture
	picker.size_flags_horizontal = SIZE_EXPAND_FILL
	picker.resource_changed.connect(
		func(texture: Resource) -> void:
			ShantySpeakerEdits.set_face_texture(_model, _speaker, index, texture as Texture2D)
	)
	picker.resource_selected.connect(
		func(texture: Resource, _inspect: bool) -> void: inspect_requested.emit(texture, _speaker)
	)
	row.add_child(picker)
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(
		func() -> void:
			ShantySpeakerEdits.remove_face(_model, _speaker, index)
			show_speaker(_model, _speaker)
	)
	row.add_child(remove)
	return row


func _new_face_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var tag := LineEdit.new()
	tag.placeholder_text = "emotion tag, e.g. neutral"
	tag.custom_minimum_size.x = 200
	row.add_child(tag)
	var add := Button.new()
	add.text = "+ Face"
	add.pressed.connect(
		func() -> void:
			if ShantySpeakerEdits.add_face(_model, _speaker, tag.text.strip_edges()):
				show_speaker(_model, _speaker)
	)
	row.add_child(add)
	return row


func _on_key_submitted(key: String) -> void:
	if key != _speaker.name_key and ShantySpeakerEdits.set_name_key(_model, _speaker, key):
		show_speaker(_model, _speaker)


static func _row(grid: GridContainer, title: String, field: Control) -> void:
	var label := Label.new()
	label.text = title
	grid.add_child(label)
	field.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(field)


static func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
