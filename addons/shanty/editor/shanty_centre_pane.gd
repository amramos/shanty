@tool
extends VBoxContainer

## The centre pane: the form for whatever is picked on the left -- a speaker, a
## conversation's line table, a scene or a trigger -- or the hint when nothing
## is. It routes the forms' requests up to the tab, which owns the Inspector
## and the selection.

signal inspect_requested(resource: Resource, owner: Resource)
## A form asked for another resource to be picked: a Say step's conversation.
signal select_requested(resource: Resource)
## The writer is working on `line`, for the preview.
signal line_picked(line: DialogueLine)

const SpeakerForm := preload("res://addons/shanty/editor/shanty_speaker_form.gd")
const LineTable := preload("res://addons/shanty/editor/shanty_line_table.gd")
const ScenePane := preload("res://addons/shanty/editor/shanty_scene_pane.gd")
const TriggerPane := preload("res://addons/shanty/editor/shanty_trigger_pane.gd")

var _connected: bool = false

@onready var _hint: Label = %Hint
@onready var _speaker_form: SpeakerForm = %SpeakerForm
@onready var _line_table: LineTable = %LineTable
@onready var _scene_pane: ScenePane = %ScenePane
@onready var _trigger_pane: TriggerPane = %TriggerPane


## Connects the forms once; the tab calls it from `start()`.
func connect_forms() -> void:
	if _connected:
		return
	_connected = true
	for form: Node in [_speaker_form, _line_table, _scene_pane, _trigger_pane]:
		form.connect(&"inspect_requested", inspect_requested.emit)
	_line_table.line_picked.connect(line_picked.emit)
	_scene_pane.conversation_requested.connect(select_requested.emit)


## Shows the form for `selected`, or `hint` when nothing is picked.
func show_selected(model: ShantyEditorModel, selected: Resource, hint: String) -> void:
	_speaker_form.visible = selected is SpeakerDefinition
	_line_table.visible = selected is ConversationDefinition
	_scene_pane.visible = selected is CutsceneDefinition
	_trigger_pane.visible = selected is StoryTriggerDefinition
	_hint.visible = selected == null
	_hint.text = hint
	if selected is SpeakerDefinition:
		_speaker_form.show_speaker(model, selected)
	elif selected is ConversationDefinition:
		_line_table.show_conversation(model, selected)
	elif selected is CutsceneDefinition:
		_scene_pane.show_scene(model, selected)
	elif selected is StoryTriggerDefinition:
		_trigger_pane.show_trigger(model, selected)


## Redraws a scene's step summaries after the Inspector changed a step.
func refresh_scene() -> void:
	if _scene_pane.visible:
		_scene_pane.rebuild()


## Marks every form's keys and findings with the last lint.
func apply_issues(issues: Array[ShantyLintIssue]) -> void:
	_line_table.apply_issues(issues)
	_scene_pane.apply_issues(issues)
	_trigger_pane.apply_issues(issues)
