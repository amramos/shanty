@tool
extends VBoxContainer

## The line preview: the line picked in the tab, drawn in the real
## `DialogueView` scene under the host's theme. The view is instanced under a
## plain `Control` that carries the theme -- a `CanvasLayer` would not pass it
## on -- and filled through the scene's own named nodes, because inside the
## editor the view's script does not run. What to draw is
## `ShantyPreviewModel`'s; this pane only binds it.
##
## **Its limit.** It is the real bar under the real theme at the pane's width,
## with the text whole: not the player's layer, letterbox, backdrop or dim, not
## your game's resolution, and no typing. Play shows all of those.

const VIEW_SCENE: PackedScene = preload("res://addons/shanty/ui/dialogue_view.tscn")
const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const STAGE_HEIGHT: float = 220.0

var _model: ShantyEditorModel = null
var _line: DialogueLine = null
var _stage: Control = Control.new()
var _view: Control = null
var _target: CheckButton = CheckButton.new()
var _reply: CheckButton = CheckButton.new()
var _note: Label = null
var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	var toggles := HBoxContainer.new()
	_target.text = "Target"
	_target.tooltip_text = "Show the target locale's text instead of the source's"
	_target.toggled.connect(_redraw.unbind(1))
	toggles.add_child(_target)
	_reply.text = "Reply turn"
	_reply.tooltip_text = "Show the replies as the reply turn draws them"
	_reply.toggled.connect(_redraw.unbind(1))
	toggles.add_child(_reply)
	add_child(toggles)
	_stage.custom_minimum_size.y = STAGE_HEIGHT
	_stage.clip_contents = true
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stage)
	_view = VIEW_SCENE.instantiate()
	_stage.add_child(_view)
	_note = Palette.caption("", Palette.muted())
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note)


## Reads the host's theme again: after opening a config, or Reload.
func show_theme(config: ShantyProjectConfig) -> void:
	_stage.theme = ShantyPreviewModel.stage_theme(config)


## Shows `line` of the open model; null shows an empty bar and a hint.
func show_line(model: ShantyEditorModel, line: DialogueLine) -> void:
	_model = model
	_line = line
	_redraw()


## The locale the preview shows: the target when its toggle is on.
func shown_locale() -> String:
	if _model == null:
		return ""
	return _model.target_locale if _target.button_pressed else _model.source_locale


## What the pane last drew, for the tests.
func view() -> Control:
	return _view


func _redraw() -> void:
	if _view == null:
		return
	var preview: ShantyPreviewModel = (
		ShantyPreviewModel.for_line(_model, _line, shown_locale(), _reply.button_pressed)
		if _model != null
		else ShantyPreviewModel.new()
	)
	_reply.disabled = _line == null or _line.choices.is_empty()
	var face: TextureRect = _view.get_node(^"%Face")
	var plate_name: Label = _view.get_node(^"%PlateName")
	var name_plate: Label = _view.get_node(^"%NamePlate")
	var line_label: RichTextLabel = _view.get_node(^"%Line")
	name_plate.text = preview.speaker_name
	name_plate.theme_type_variation = (
		preview.colour_variation
		if not preview.colour_variation.is_empty()
		else DialogueView.NAME_VARIATION
	)
	face.texture = preview.face
	face.visible = preview.face != null
	plate_name.text = preview.speaker_name
	plate_name.visible = preview.face == null
	for label: Control in [line_label, name_plate, plate_name]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line_label.bbcode_enabled = true
	line_label.text = preview.text
	line_label.visible_characters = -1
	_show_replies(preview.replies)
	(_view.get_node(^"%ContinueMarker") as Control).visible = preview.replies.is_empty()
	_note.text = _describe(preview)


func _show_replies(replies: PackedStringArray) -> void:
	var block: Control = _view.get_node(^"%ReplyBlock")
	var choices: VBoxContainer = _view.get_node(^"%Choices")
	for child: Node in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for reply: String in replies:
		var button := ShantyChoiceButton.new()
		button.text = reply
		choices.add_child(button)
	block.visible = not replies.is_empty()


func _describe(preview: ShantyPreviewModel) -> String:
	if _line == null:
		return "Pick a line to see it in the bar."
	var parts: PackedStringArray = ["%s, %s" % [_line.text_key, preview.locale]]
	if preview.empty_cell:
		parts.append("no %s text yet" % preview.locale)
	if _reply.button_pressed and not preview.replying and not preview.replies.is_empty():
		parts.append("no reply speaker named: the asker keeps the bar")
	return " · ".join(parts)
