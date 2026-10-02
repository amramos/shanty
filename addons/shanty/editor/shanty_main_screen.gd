@tool
extends VBoxContainer

## The Shanty tab. It owns one `ShantyEditorModel` and binds the toolbar, the
## list, the speaker form and the line table to it; every rule lives in the
## model and the lint, so this script only routes. Lint runs shortly after
## each edit and on demand; Save lints first and is refused by an error or by
## a file changed on disk since it was read.
##
## Everything that needs the running editor -- the Inspector, the filesystem,
## file dialogs -- is reached only through `_in_editor()`, so the tab can be
## instantiated and opened headlessly, as the tests do.

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const Toolbar := preload("res://addons/shanty/editor/shanty_toolbar.gd")
const ListPane := preload("res://addons/shanty/editor/shanty_list_pane.gd")
const SpeakerForm := preload("res://addons/shanty/editor/shanty_speaker_form.gd")
const LineTable := preload("res://addons/shanty/editor/shanty_line_table.gd")
const FilesystemRefresh := preload("res://addons/shanty/editor/shanty_filesystem_refresh.gd")
const LINT_DELAY: float = 0.4
const PICK_HINT: String = "Pick a speaker or a conversation on the left, or make one."
const NO_CONFIG_HINT: String = (
	"No Shanty config is open. Press Create config… to make one, or point the project"
	+ " setting %s at yours." % ShantyProjectConfig.SETTING
)

var _model: ShantyEditorModel = ShantyEditorModel.new()
var _selected: Resource = null
## What the Inspector is showing for us, and the resource it belongs to.
var _inspected: Resource = null
var _inspected_owner: Resource = null
var _lint_timer: Timer = Timer.new()
var _config_dialog: EditorFileDialog = null
var _refresh: FilesystemRefresh = null
var _started: bool = false

@onready var _toolbar: Toolbar = %Toolbar
@onready var _list: ListPane = %List
@onready var _hint: Label = %Hint
@onready var _speaker_form: SpeakerForm = %SpeakerForm
@onready var _line_table: LineTable = %LineTable
@onready var _issues: ItemList = %Issues
@onready var _status: Label = %Status


## Called by the plugin once the tab is in the editor (and by the tests); never
## on its own, so opening this scene to edit it does nothing.
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
	_toolbar.create_config_pressed.connect(_on_create_config_pressed)
	_list.resource_selected.connect(_select)
	_list.speaker_requested.connect(_on_speaker_requested)
	_list.conversation_requested.connect(_on_conversation_requested)
	_speaker_form.inspect_requested.connect(_inspect)
	_line_table.inspect_requested.connect(_inspect)
	_model.changed.connect(_on_model_changed)
	if _in_editor():
		EditorInterface.get_inspector().property_edited.connect(_on_property_edited)
	_open(false)


## The model the tab shows, for the tests.
func model() -> ShantyEditorModel:
	return _model


## Reads the configured project again, dropping unsaved edits. With no usable
## config the tab shows an empty state and says why.
func _open(fresh: bool) -> void:
	var problem: ShantyEditorModel.Problem = _model.open_path(ShantyFiles.config_path(), fresh)
	var missing: bool = problem != ShantyEditorModel.Problem.NONE
	_selected = null
	_show_selected()
	_list.show_model(_model, _selected)
	_toolbar.show_locales(_model.locales(), _model.source_locale, _model.target_locale)
	_toolbar.show_config_missing(missing)
	_run_lint()
	if missing:
		_say(_model.status + " Press Create config… to make one.")
	elif _model.status.is_empty():
		_say("Opened %s." % _model.config.csv_path)
	else:
		_say(_model.status)


func _select(resource: Resource) -> void:
	_selected = resource
	_show_selected()
	_run_lint()


func _show_selected() -> void:
	_speaker_form.visible = _selected is SpeakerDefinition
	_line_table.visible = _selected is ConversationDefinition
	_hint.visible = _selected == null
	_hint.text = PICK_HINT if _model.config != null else NO_CONFIG_HINT
	if _selected is SpeakerDefinition:
		_speaker_form.show_speaker(_model, _selected)
	elif _selected is ConversationDefinition:
		_line_table.show_conversation(_model, _selected)


func _on_locales_chosen(source: String, target: String) -> void:
	_model.set_locales(source, target)
	_show_selected()


func _on_locale_requested(locale: String) -> void:
	if _model.config == null or not _model.add_locale(locale):
		_say("'%s' is not a locale code, or the CSV already has it." % locale)
		return
	_toolbar.show_locales(_model.locales(), _model.source_locale, _model.target_locale)
	_show_selected()
	_say("Added the %s column. Save writes it." % locale)


func _on_speaker_requested(id: String) -> void:
	if _model.config == null:
		_say(NO_CONFIG_HINT)
		return
	var speaker: SpeakerDefinition = ShantySpeakerEdits.add_speaker(_model, id)
	if speaker == null:
		_say("No speaker made: '%s' is not a lower-case id, or it is taken." % id)
		return
	_selected = speaker
	_list.show_model(_model, _selected)
	_show_selected()


func _on_conversation_requested(id: String) -> void:
	if _model.config == null:
		_say(NO_CONFIG_HINT)
		return
	var conversation: ConversationDefinition = ShantyConversationEdits.add_conversation(_model, id)
	if conversation == null:
		_say("No conversation made: '%s' is not a lower-case id, or it is taken." % id)
		return
	_selected = conversation
	_list.show_model(_model, _selected)
	_show_selected()


func _on_create_config_pressed() -> void:
	if not _in_editor():
		return
	if _config_dialog == null:
		_config_dialog = EditorFileDialog.new()
		_config_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_config_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_config_dialog.title = "Create a Shanty config"
		_config_dialog.add_filter("*.tres", "ShantyProjectConfig")
		_config_dialog.current_file = "shanty_config.tres"
		_config_dialog.file_selected.connect(_create_config)
		add_child(_config_dialog)
	_config_dialog.popup_file_dialog()


## Saves a fresh config at `path`, points the project setting at it, opens it,
## and hands it to the Inspector so its CSV and folders can be set.
func _create_config(path: String) -> void:
	var error: Error = ShantyFiles.create_config(path)
	if error != OK:
		_say("Could not create %s (%s)." % [path, error_string(error)])
		return
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, path)
	ProjectSettings.save()
	_filesystem().request(PackedStringArray([path]))
	_open(true)
	if _model.config != null:
		EditorInterface.edit_resource(_model.config)
	_say(
		(
			"Created %s and pointed %s at it. Its CSV and folders are in the Inspector."
			% [path, ShantyProjectConfig.SETTING]
		)
	)


func _inspect(resource: Resource, owner: Resource) -> void:
	if resource == null or not _in_editor():
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
	if is_inside_tree():
		_lint_timer.start()


func _run_lint() -> void:
	# An empty model lints clean, so this is safe with no config open.
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
		_say("Nothing to save: no Shanty config is open.")
		return
	var result: ShantySaveResult = _model.save()
	_show_issues(result.issues)
	_say(result.message)
	if result.saved:
		_list.show_model(_model, _selected)
	if not _in_editor():
		return
	# Saving a staged resource told the editor about it, saved or not; it is
	# gone again, and is forgotten before the file that replaced it is read.
	var paths: PackedStringArray = result.staged_paths.duplicate()
	if result.saved:
		paths.append_array(result.resource_paths)
		if not result.csv_path.is_empty():
			paths.append(result.csv_path)
	_filesystem().request(paths)


## The pane's one link to the editor's filesystem; editor-only.
func _filesystem() -> FilesystemRefresh:
	if _refresh == null:
		_refresh = FilesystemRefresh.new(EditorInterface.get_resource_filesystem())
	return _refresh


func _say(text: String) -> void:
	_status.text = text


## True only inside the running editor, where `EditorInterface` is real.
static func _in_editor() -> bool:
	return Engine.is_editor_hint()
