@tool
extends VBoxContainer

## The scene form: its id, the title and synopsis -- each a key in the CSV with
## a source and a target cell, like a line -- Skippable and Remembered, and the
## ordered steps. A step's row says what it does; in the editor a Backdrop row
## picks its still and a Say row its conversation through the editor's own
## resource picker; Edit opens the step in the Inspector for its other values;
## a Say step's row also opens its conversation. Every change goes through
## `ShantySceneEdits`.

signal inspect_requested(resource: Resource, owner: Resource)
## The writer asked to see the conversation a Say step plays.
signal conversation_requested(conversation: ConversationDefinition)

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const CellEdit := preload("res://addons/shanty/editor/shanty_cell_edit.gd")
const PickerMenu := preload("res://addons/shanty/editor/shanty_picker_menu.gd")
const STEP_BASE: StringName = &"CutsceneStep"
const CAPTION_WIDTH: float = 100.0
const PICKER_WIDTH: float = 160.0

var _model: ShantyEditorModel = null
var _scene: CutsceneDefinition = null
## Key -> the caption under its source cell, marked by `apply_issues()`.
var _key_states: Dictionary[String, Label] = {}
var _findings: Label = null
var _issues: Array[ShantyLintIssue] = []


func show_scene(model: ShantyEditorModel, scene: CutsceneDefinition) -> void:
	_model = model
	_scene = scene
	rebuild()


## Draws the form again from the scene: after a step changed in the Inspector.
func rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_key_states.clear()
	if _scene == null:
		return
	var title := Label.new()
	title.text = String(_scene.scene_id)
	title.tooltip_text = _model.path_of(_scene)
	add_child(title)
	_findings = Palette.caption("", Palette.error())
	_findings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_findings)
	for property: StringName in ShantySceneEdits.KEY_PROPERTIES:
		add_child(_key_row(property))
	add_child(_toggles())
	add_child(HSeparator.new())
	add_child(Palette.caption("Steps, in order", Palette.muted()))
	for index: int in _scene.steps.size():
		add_child(_step_row(index))
	var add: PickerMenu = PickerMenu.new()
	add.setup(STEP_BASE, "+ Step")
	add.size_flags_horizontal = SIZE_SHRINK_BEGIN
	add.picked.connect(_on_step_picked.bind(_scene.steps.size() - 1))
	add_child(add)
	apply_issues(_issues)


## Marks the title and synopsis keys, and lists what the lint found about the
## scene itself.
func apply_issues(issues: Array[ShantyLintIssue]) -> void:
	_issues = issues
	if _scene == null or _findings == null:
		return
	for key: String in _key_states:
		Palette.show_key_state(_key_states[key], key, issues)
	var where: String = ShantyLint.location_of(_scene, _scene.scene_id)
	var found: PackedStringArray = []
	for issue: ShantyLintIssue in issues:
		if issue.path == where and issue.key.is_empty():
			found.append(issue.message)
	_findings.text = "\n".join(found)
	_findings.visible = not found.is_empty()


func _key_row(property: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = "Title" if property == &"title_key" else "Synopsis"
	caption.custom_minimum_size.x = CAPTION_WIDTH
	row.add_child(caption)
	var key: String = _scene.get(property)
	if key.is_empty():
		var add := Button.new()
		add.text = "+ " + caption.text
		add.tooltip_text = "Name a key for it and add its row"
		add.pressed.connect(
			func() -> void:
				if ShantySceneEdits.add_key(_model, _scene, property):
					rebuild()
		)
		row.add_child(add)
		return row
	var source_box := VBoxContainer.new()
	source_box.size_flags_horizontal = SIZE_EXPAND_FILL
	var source := LineEdit.new()
	source.text = _model.text(key, _model.source_locale)
	source.text_changed.connect(
		func(value: String) -> void: _model.set_text(key, _model.source_locale, value)
	)
	source_box.add_child(source)
	_key_states[key] = Palette.caption(key, Palette.muted())
	source_box.add_child(_key_states[key])
	row.add_child(source_box)
	var target: CellEdit = CellEdit.new()
	target.size_flags_horizontal = SIZE_EXPAND_FILL
	target.size_flags_vertical = SIZE_SHRINK_BEGIN
	target.show_text(_model.text(key, _model.target_locale))
	target.text_changed.connect(
		func(value: String) -> void: _model.set_text(key, _model.target_locale, value)
	)
	row.add_child(target)
	if property == &"synopsis_key":
		var remove := Button.new()
		remove.text = "Remove"
		remove.tooltip_text = "No synopsis; its row goes when nothing else names it"
		remove.size_flags_vertical = SIZE_SHRINK_BEGIN
		remove.pressed.connect(
			func() -> void:
				if ShantySceneEdits.remove_key(_model, _scene, property):
					rebuild()
		)
		row.add_child(remove)
	return row


func _toggles() -> HBoxContainer:
	var row := HBoxContainer.new()
	var toggles: Array[Array] = [
		["Skippable", &"skippable", "Holding the advance press skips to the end"],
		["Remembered", &"remembered", "The host's replay list keeps this scene once played"],
	]
	for toggle: Array in toggles:
		var box := CheckBox.new()
		box.text = toggle[0]
		box.tooltip_text = toggle[2]
		box.button_pressed = bool(_scene.get(toggle[1]))
		var property: StringName = toggle[1]
		box.toggled.connect(
			func(on: bool) -> void: ShantySceneEdits.edit(_model, _scene, property, on)
		)
		row.add_child(box)
	return row


func _step_row(index: int) -> HBoxContainer:
	var step: CutsceneStep = _scene.steps[index]
	var row := HBoxContainer.new()
	var number := Label.new()
	number.text = str(index + 1)
	number.custom_minimum_size.x = 28
	row.add_child(number)
	var summary := Label.new()
	summary.text = ShantySceneEdits.summary(step)
	summary.size_flags_horizontal = SIZE_EXPAND_FILL
	summary.clip_text = true
	row.add_child(summary)
	var picker: Control = _value_picker(index)
	if picker != null:
		row.add_child(picker)
	var conversation: ConversationDefinition = ShantySceneEdits.conversation_of(step)
	if conversation != null:
		_add_button(
			row,
			"Open conversation",
			"Edit the lines this step says",
			false,
			func() -> void: conversation_requested.emit(conversation)
		)
	_add_button(
		row,
		"Edit",
		"Edit this step's values in the Inspector",
		step == null,
		func() -> void: inspect_requested.emit(step, _scene)
	)
	var insert: PickerMenu = PickerMenu.new()
	insert.setup(STEP_BASE, "Insert after")
	insert.picked.connect(_on_step_picked.bind(index))
	row.add_child(insert)
	var last: int = _scene.steps.size() - 1
	_add_button(row, "↑", "Move this step up", index == 0, _on_move.bind(index, index - 1))
	_add_button(row, "↓", "Move this step down", index == last, _on_move.bind(index, index + 1))
	_add_button(
		row,
		"Remove",
		"Remove this step",
		false,
		func() -> void:
			if ShantySceneEdits.remove_step(_model, _scene, index):
				rebuild()
	)
	return row


## The editor's resource picker for the step's still or conversation, writing
## through the model; null headless, where the summary shows the value, and
## for any other step.
func _value_picker(index: int) -> Control:
	var step: CutsceneStep = _scene.steps[index]
	if not Engine.is_editor_hint() or not (step is BackdropStep or step is SayStep):
		return null
	var property: StringName = &"texture" if step is BackdropStep else &"conversation"
	var picker := EditorResourcePicker.new()
	picker.base_type = "Texture2D" if step is BackdropStep else "ConversationDefinition"
	picker.edited_resource = step.get(property)
	picker.custom_minimum_size.x = PICKER_WIDTH
	picker.tooltip_text = "This step's %s" % property
	picker.resource_changed.connect(
		func(picked: Resource) -> void:
			if ShantySceneEdits.set_step_property(_model, _scene, index, property, picked):
				rebuild.call_deferred()
			else:
				picker.edited_resource = step.get(property)
	)
	picker.resource_selected.connect(
		func(picked: Resource, _inspect: bool) -> void: inspect_requested.emit(picked, _scene)
	)
	return picker


func _on_step_picked(script_path: String, after: int) -> void:
	var step: CutsceneStep = ShantySceneEdits.insert_step_after(_model, _scene, after, script_path)
	if step != null:
		rebuild()
		inspect_requested.emit(step, _scene)


func _on_move(from: int, to: int) -> void:
	if ShantySceneEdits.move_step(_model, _scene, from, to):
		rebuild()


static func _add_button(
	row: HBoxContainer, text: String, tip: String, disabled: bool, action: Callable
) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.disabled = disabled
	button.pressed.connect(action)
	row.add_child(button)
