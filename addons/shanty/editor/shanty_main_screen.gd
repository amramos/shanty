@tool
extends VBoxContainer

## The Shanty tab. It owns one `ShantyEditorModel` and binds the toolbar, the
## list, the speaker form and the line table to it; every rule lives in the
## model and the lint, so this script only routes. Lint runs shortly after
## each edit and on demand; Save lints first and is refused by an error or by
## a file changed on disk since it was read.

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const Toolbar := preload("res://addons/shanty/editor/shanty_toolbar.gd")
const ListPane := preload("res://addons/shanty/editor/shanty_list_pane.gd")
const SpeakerForm := preload("res://addons/shanty/editor/shanty_speaker_form.gd")
const LineTable := preload("res://addons/shanty/editor/shanty_line_table.gd")
const LINT_DELAY: float = 0.4

var _model: ShantyEditorModel = ShantyEditorModel.new()
var _selected: Resource = null
## What the Inspector is showing for us, and the resource it belongs to.
var _inspected: Resource = null
var _inspected_owner: Resource = null
var _lint_timer: Timer = Timer.new()
var _started: bool = false

@onready var _toolbar: Toolbar = %Toolbar
@onready var _list: ListPane = %List
@onready var _hint: Label = %Hint
@onready var _speaker_form: SpeakerForm = %SpeakerForm
@onready var _line_table: LineTable = %LineTable
@onready var _issues: ItemList = %Issues
@onready var _status: Label = %Status


## Called by the plugin once the tab is in the editor; never on its own, so
## opening this scene to edit it does nothing.
func start() -> void:
	if _started:
		return
	_started = true
	_toolbar.build()
	_list.build()
	_lint_timer.one_shot = true
	_lint_timer.wait_time = LINT_DELAY
	_lint_timer.timeout.connect(_run_lint)
	add_child(_lint_timer)
	_toolbar.locales_chosen.connect(_on_locales_chosen)
	_toolbar.locale_requested.connect(_on_locale_requested)
	_toolbar.reload_pressed.connect(_open.bind(true))
	_toolbar.lint_pressed.connect(_run_lint)
	_toolbar.save_pressed.connect(_save)
	_list.resource_selected.connect(_select)
	_list.speaker_requested.connect(_on_speaker_requested)
	_list.conversation_requested.connect(_on_conversation_requested)
	_speaker_form.inspect_requested.connect(_inspect)
	_line_table.inspect_requested.connect(_inspect)
	_model.changed.connect(_on_model_changed)
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)
	_open(false)


## Reads the configured project again, dropping unsaved edits.
func _open(fresh: bool) -> void:
	var problem: String = _model.open(ShantyFiles.configured(), fresh)
	_selected = null
	_show_selected()
	_list.show_model(_model, _selected)
	_toolbar.show_locales(_model.locales(), _model.source_locale, _model.target_locale)
	_run_lint()
	_say(problem if not problem.is_empty() else "Opened %s." % _model.config.csv_path)


func _select(resource: Resource) -> void:
	_selected = resource
	_show_selected()
	_run_lint()


func _show_selected() -> void:
	_speaker_form.visible = _selected is SpeakerDefinition
	_line_table.visible = _selected is ConversationDefinition
	_hint.visible = _selected == null
	if _selected is SpeakerDefinition:
		_speaker_form.show_speaker(_model, _selected)
	elif _selected is ConversationDefinition:
		_line_table.show_conversation(_model, _selected)


func _on_locales_chosen(source: String, target: String) -> void:
	_model.set_locales(source, target)
	_show_selected()


func _on_locale_requested(locale: String) -> void:
	if not _model.add_locale(locale):
		_say("'%s' is not a locale code, or the CSV already has it." % locale)
		return
	_toolbar.show_locales(_model.locales(), _model.source_locale, _model.target_locale)
	_show_selected()
	_say("Added the %s column. Save writes it." % locale)


func _on_speaker_requested(id: String) -> void:
	var speaker: SpeakerDefinition = ShantySpeakerEdits.add_speaker(_model, id)
	if speaker == null:
		_say("No speaker made: '%s' is not a lower-case id, or it is taken." % id)
		return
	_selected = speaker
	_list.show_model(_model, _selected)
	_show_selected()


func _on_conversation_requested(id: String) -> void:
	var conversation: ConversationDefinition = ShantyConversationEdits.add_conversation(_model, id)
	if conversation == null:
		_say("No conversation made: '%s' is not a lower-case id, or it is taken." % id)
		return
	_selected = conversation
	_list.show_model(_model, _selected)
	_show_selected()


func _inspect(resource: Resource, owner: Resource) -> void:
	if resource == null:
		return
	_inspected = resource
	_inspected_owner = owner
	EditorInterface.edit_resource(resource)


## An edit in the Inspector to something we handed it marks its owner edited,
## so Save writes the conversation or speaker that holds it.
func _on_property_edited(_property: String) -> void:
	var edited: Object = EditorInterface.get_inspector().get_edited_object()
	if edited != null and edited == _inspected and _inspected_owner != null:
		_model.touch(_inspected_owner)


func _on_model_changed() -> void:
	_toolbar.show_coverage(_model.coverage())
	_lint_timer.start()


func _run_lint() -> void:
	if _model.config == null:
		return
	_show_issues(_model.lint())


func _show_issues(found: Array[ShantyLintIssue]) -> void:
	_issues.clear()
	for issue: ShantyLintIssue in found:
		var at: int = _issues.add_item(issue.describe())
		_issues.set_item_custom_fg_color(
			at, Palette.error() if issue.is_error() else Palette.warning()
		)
	_line_table.apply_issues(found)
	_toolbar.show_coverage(_model.coverage())


func _save() -> void:
	if _model.config == null:
		_say("Nothing to save: no Shanty config is set.")
		return
	var result: ShantySaveResult = _model.save()
	_show_issues(result.issues)
	_say(result.message)
	if not result.saved:
		return
	var files: EditorFileSystem = EditorInterface.get_resource_filesystem()
	for path: String in result.resource_paths:
		files.update_file(path)
	if not result.csv_path.is_empty():
		if files.is_scanning() or files.get_file_type(result.csv_path).is_empty():
			# The editor has not indexed the file yet; its scan imports it.
			files.scan()
		else:
			files.reimport_files(PackedStringArray([result.csv_path]))
	_list.show_model(_model, _selected)


func _say(text: String) -> void:
	_status.text = text
