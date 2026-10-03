@tool
extends VBoxContainer

## The trigger form: the moment it answers -- chosen from the config's
## `trigger_ids` when it lists them, typed when it does not -- and its
## candidates, each a scene from the scenes folder, a priority, `once` and
## conditions edited in the Inspector. Every change goes through
## `ShantyTriggerEdits`.

signal inspect_requested(resource: Resource, owner: Resource)

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const PickerMenu := preload("res://addons/shanty/editor/shanty_picker_menu.gd")
const EntryChips := preload("res://addons/shanty/editor/shanty_entry_chips.gd")
const NO_SCENE: String = "(no scene)"
const SCENE_WIDTH: float = 200.0
const PRIORITY_WIDTH: float = 90.0

var _model: ShantyEditorModel = null
var _trigger: StoryTriggerDefinition = null
var _findings: Label = null
var _issues: Array[ShantyLintIssue] = []


func show_trigger(model: ShantyEditorModel, trigger: StoryTriggerDefinition) -> void:
	_model = model
	_trigger = trigger
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	if _trigger == null:
		return
	add_child(_id_row())
	_findings = Palette.caption("", Palette.error())
	_findings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_findings)
	add_child(HSeparator.new())
	add_child(
		(
			Palette
			. caption(
				"Candidates: the highest priority whose conditions hold plays; a tie goes to the first.",
				Palette.muted()
			)
		)
	)
	for index: int in _trigger.candidates.size():
		if _trigger.candidates[index] != null:
			add_child(_candidate_rows(index))
	var add := Button.new()
	add.text = "+ Candidate"
	add.size_flags_horizontal = SIZE_SHRINK_BEGIN
	add.pressed.connect(
		func() -> void:
			ShantyTriggerEdits.add_candidate(_model, _trigger)
			rebuild()
	)
	add_child(add)
	apply_issues(_issues)


## Lists what the lint found about this trigger and its candidates.
func apply_issues(issues: Array[ShantyLintIssue]) -> void:
	_issues = issues
	if _trigger == null or _findings == null:
		return
	var where: String = ShantyLint.location_of(_trigger, _trigger.trigger_id)
	var found: PackedStringArray = []
	for issue: ShantyLintIssue in issues:
		if issue.path == where or issue.path.begins_with(where + " candidate"):
			found.append(issue.describe())
	_findings.text = "\n".join(found)
	_findings.visible = not found.is_empty()


func _id_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = "Moment"
	caption.tooltip_text = _model.path_of(_trigger)
	row.add_child(caption)
	if ShantyTriggerEdits.is_closed(_model):
		row.add_child(_closed_id_picker())
	else:
		var field := LineEdit.new()
		field.text = String(_trigger.trigger_id)
		field.custom_minimum_size.x = SCENE_WIDTH
		field.tooltip_text = "Any lower-case id: the config lists no trigger ids"
		field.text_submitted.connect(
			func(value: String) -> void:
				if not ShantyTriggerEdits.set_id(_model, _trigger, value.strip_edges()):
					field.text = String(_trigger.trigger_id)
		)
		row.add_child(field)
	return row


## The config's ids; the trigger's own first even when the set no longer has
## it, so the lint's complaint is visible rather than silently replaced.
func _closed_id_picker() -> OptionButton:
	var picker := OptionButton.new()
	picker.tooltip_text = "The moments the config's trigger_ids name"
	var ids: PackedStringArray = _model.config.trigger_ids.duplicate()
	if not ids.has(String(_trigger.trigger_id)):
		ids.insert(0, String(_trigger.trigger_id))
	for id: String in ids:
		picker.add_item(id if not id.is_empty() else "(no id)")
	picker.select(ids.find(String(_trigger.trigger_id)))
	picker.item_selected.connect(
		func(at: int) -> void:
			if not ShantyTriggerEdits.set_id(_model, _trigger, ids[at]):
				picker.select(ids.find(String(_trigger.trigger_id)))
	)
	return picker


func _candidate_rows(index: int) -> VBoxContainer:
	var candidate: StoryCandidate = _trigger.candidates[index]
	var box := VBoxContainer.new()
	var row := HBoxContainer.new()
	box.add_child(row)
	var number := Label.new()
	number.text = str(index + 1)
	number.custom_minimum_size.x = 28
	row.add_child(number)
	row.add_child(_scene_picker(candidate))
	row.add_child(_priority_field(candidate))
	var once := CheckBox.new()
	once.text = "Once"
	once.tooltip_text = "Passed over once the host's records hold its scene"
	once.button_pressed = candidate.once
	once.toggled.connect(
		func(on: bool) -> void: ShantyTriggerEdits.edit(_model, _trigger, candidate, &"once", on)
	)
	row.add_child(once)
	var condition: PickerMenu = PickerMenu.new()
	condition.setup(&"ShantyCondition", "+ Condition")
	condition.picked.connect(
		func(path: String) -> void:
			var made: ShantyCondition = ShantyTriggerEdits.add_condition(
				_model, _trigger, candidate, path
			)
			if made != null:
				rebuild()
				inspect_requested.emit(made, _trigger)
	)
	row.add_child(condition)
	_add_actions(row, index)
	var chips: EntryChips = EntryChips.new()
	chips.show_entries("If:", candidate.conditions)
	chips.inspect_requested.connect(
		func(entry: Resource) -> void: inspect_requested.emit(entry, _trigger)
	)
	chips.remove_requested.connect(
		func(at: int) -> void:
			if ShantyTriggerEdits.remove_condition(_model, _trigger, candidate, at):
				rebuild()
	)
	box.add_child(chips)
	return box


## The candidate's priority as typed: any whole number, as the data allows. A
## field rather than a SpinBox, whose float would round a large one. Anything
## else is put back to the value it holds.
func _priority_field(candidate: StoryCandidate) -> LineEdit:
	var field := LineEdit.new()
	field.text = str(candidate.priority)
	field.custom_minimum_size.x = PRIORITY_WIDTH
	field.placeholder_text = "priority"
	field.tooltip_text = "Priority: any whole number; the highest whose conditions hold plays"
	var commit: Callable = func(value: String) -> void:
		ShantyTriggerEdits.set_priority(_model, _trigger, candidate, value)
		field.text = str(candidate.priority)
	field.text_submitted.connect(commit)
	field.focus_exited.connect(func() -> void: commit.call(field.text))
	return field


## The scenes the scenes folder holds; a scene from anywhere else stays named,
## and the lint says why it should not.
func _scene_picker(candidate: StoryCandidate) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = SCENE_WIDTH
	var scenes: Array[CutsceneDefinition] = [null]
	scenes.append_array(_model.scenes)
	if candidate.cutscene != null and not scenes.has(candidate.cutscene):
		scenes.append(candidate.cutscene)
	for scene: CutsceneDefinition in scenes:
		picker.add_item(String(scene.scene_id) if scene != null else NO_SCENE)
	picker.select(scenes.find(candidate.cutscene))
	picker.item_selected.connect(
		func(at: int) -> void:
			ShantyTriggerEdits.edit(_model, _trigger, candidate, &"cutscene", scenes[at])
	)
	return picker


func _add_actions(row: HBoxContainer, index: int) -> void:
	var last: int = _trigger.candidates.size() - 1
	var actions: Array[Array] = [
		["↑", "Move this candidate up", index == 0, index - 1],
		["↓", "Move this candidate down", index == last, index + 1],
	]
	for action: Array in actions:
		var button := Button.new()
		button.text = action[0]
		button.tooltip_text = action[1]
		button.disabled = action[2]
		var to: int = action[3]
		button.pressed.connect(
			func() -> void:
				if ShantyTriggerEdits.move_candidate(_model, _trigger, index, to):
					rebuild()
		)
		row.add_child(button)
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(
		func() -> void:
			if ShantyTriggerEdits.remove_candidate(_model, _trigger, index):
				rebuild()
	)
	row.add_child(remove)
