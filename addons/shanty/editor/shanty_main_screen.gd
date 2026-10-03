@tool
extends VBoxContainer

## The Shanty tab. It owns one `ShantyEditorModel` and binds the toolbar, the
## list, the centre forms and the line preview to it; every rule lives in the
## model and the lint, so this script only routes. Lint runs shortly after
## each edit and on demand; Save lints first and is refused by an error or by
## a file changed on disk since it was read. Play hands the picked scene or
## trigger to the preview host in a game window.
##
## Everything that needs the running editor -- the Inspector, the filesystem,
## file dialogs, Play -- is reached only through `_in_editor()`, so the tab can
## be instantiated and opened headlessly, as the tests do.

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const Toolbar := preload("res://addons/shanty/editor/shanty_toolbar.gd")
const ListPane := preload("res://addons/shanty/editor/shanty_list_pane.gd")
const CentrePane := preload("res://addons/shanty/editor/shanty_centre_pane.gd")
const BarPreview := preload("res://addons/shanty/editor/shanty_bar_preview.gd")
const FilesystemRefresh := preload("res://addons/shanty/editor/shanty_filesystem_refresh.gd")
const LINT_DELAY: float = 0.4
const PICK_HINT: String = "Pick a speaker, conversation, scene or trigger on the left, or make one."
const NO_CONFIG_HINT: String = (
	"No Shanty config is open. Config ▾ > Create config… makes one, or point the project"
	+ " setting %s at yours." % ShantyProjectConfig.SETTING
)

var _model: ShantyEditorModel = ShantyEditorModel.new()
var _selected: Resource = null
## The line the preview shows.
var _previewed: DialogueLine = null
## What the Inspector is showing for us, and the resource it belongs to.
var _inspected: Resource = null
var _inspected_owner: Resource = null
var _lint_timer: Timer = Timer.new()
var _config_dialog: EditorFileDialog = null
var _refresh: FilesystemRefresh = null
var _started: bool = false
## True while a refill of the list waits for the end of the frame.
var _list_refresh_queued: bool = false

@onready var _toolbar: Toolbar = %Toolbar
@onready var _list: ListPane = %List
@onready var _centre: CentrePane = %Centre
@onready var _preview: BarPreview = %BarPreview
@onready var _issues: ItemList = %Issues
@onready var _status: Label = %Status
## Beside a Save refused for a file changed on disk: the way to see the change.
@onready var _status_reload: Button = %StatusReload


## Called by the plugin once the tab is in the editor (and by the tests); never
## on its own, so opening this scene to edit it does nothing.
func start() -> void:
	if _started:
		return
	_started = true
	_toolbar.build()
	_list.build()
	_preview.build()
	_centre.connect_forms()
	_lint_timer.one_shot = true
	_lint_timer.wait_time = LINT_DELAY
	_lint_timer.timeout.connect(_run_lint)
	add_child(_lint_timer)
	_toolbar.locales_chosen.connect(_on_locales_chosen)
	_toolbar.locale_requested.connect(_on_locale_requested)
	_toolbar.reload_pressed.connect(_open.bind(true))
	_status_reload.pressed.connect(_open.bind(true))
	_toolbar.lint_pressed.connect(_run_lint)
	_toolbar.save_pressed.connect(_save)
	_toolbar.play_pressed.connect(_play)
	_toolbar.create_config_pressed.connect(_on_create_config_pressed)
	_toolbar.inspect_config_pressed.connect(_inspect_config)
	_toolbar.host_keys_pressed.connect(_add_host_keys)
	_list.resource_selected.connect(_select)
	_list.create_requested.connect(_on_create_requested)
	_centre.inspect_requested.connect(_inspect)
	_centre.select_requested.connect(_pick)
	_centre.line_picked.connect(_on_line_picked)
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
	_model.open_path(ShantyFiles.config_path(), fresh)
	_show_opened()


## Redraws everything from what the model opened, or its empty state.
func _show_opened() -> void:
	var missing: bool = _model.problem != ShantyEditorModel.Problem.NONE
	_preview.show_config(_model.config)
	_pick(null)
	_show_locales()
	_toolbar.show_config_missing(missing)
	if missing:
		_say(_model.status + " Config ▾ > Create config… makes one.")
	elif _model.status.is_empty():
		_say("Opened %s." % _model.config.csv_path)
	else:
		_say(_model.status)


## Picks `resource` and lists it as picked: for every pick the list did not
## make itself.
func _pick(resource: Resource) -> void:
	_select(resource)
	_list.show_model(_model, _selected)


## Shows `resource`. Never refills the list, which may be the one asking, from
## inside its own selection signal.
func _select(resource: Resource) -> void:
	_selected = resource
	_previewed = ShantyPreviewModel.line_for(resource)
	_show_selected()
	_run_lint()


func _show_selected() -> void:
	_centre.show_selected(_model, _selected, PICK_HINT if _model.config != null else NO_CONFIG_HINT)
	_preview.show_line(_model, _previewed)


func _on_line_picked(line: DialogueLine) -> void:
	_previewed = line
	_preview.show_line(_model, line)


func _show_locales() -> void:
	_toolbar.show_locales(
		_model.source_choices(),
		_model.locales(),
		_model.source_locale,
		_model.target_locale,
		_model.suggested_locale()
	)


func _on_locales_chosen(source: String, target: String) -> void:
	_model.set_locales(source, target)
	_show_selected()


func _on_locale_requested(locale: String) -> void:
	if _model.config == null or not _model.add_locale(locale):
		_say("'%s' is not a locale code, or the CSV already has it." % locale)
		return
	_show_locales()
	_show_selected()
	_say("Added the %s column. Save writes it." % locale)


## Makes a new speaker, conversation, scene or trigger and picks it.
func _on_create_requested(kind: StringName, id: String) -> void:
	if _model.config == null:
		_say(NO_CONFIG_HINT)
		return
	var made: Resource = null
	match kind:
		&"speaker":
			made = ShantySpeakerEdits.add_speaker(_model, id)
		&"conversation":
			made = ShantyConversationEdits.add_conversation(_model, id)
		&"scene":
			made = ShantySceneEdits.add_scene(_model, id)
		&"trigger":
			made = ShantyTriggerEdits.add_trigger(_model, id)
	if made == null:
		_say("No %s made: %s." % [kind, _model.refusal])
		return
	_pick(made)


func _on_create_config_pressed() -> void:
	if _model.is_dirty():
		_say("Save or Reload first: opening another config drops the unsaved edits.")
		return
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


## Saves a fresh config at `path` -- or, when a file is already there, opens
## it rather than overwriting it -- points the project setting at it, opens it,
## and hands it to the Inspector so its CSV and folders can be set.
func _create_config(path: String) -> void:
	var error: Error = ShantyFiles.create_config(path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		_say("Could not create %s (%s)." % [path, error_string(error)])
		return
	var refusal: String = _model.switch_config(path)
	if not refusal.is_empty():
		_say(refusal)
		return
	ProjectSettings.save()
	_filesystem().request(PackedStringArray([path, _model.config.csv_path]))
	_show_opened()
	EditorInterface.edit_resource(_model.config)
	var done: String = "Created" if error == OK else "Opened the existing"
	_say(
		(
			"%s %s and pointed %s at it. Its CSV and folders are in the Inspector."
			% [done, path, ShantyProjectConfig.SETTING]
		)
	)


func _add_host_keys() -> void:
	if _model.config == null:
		_say(NO_CONFIG_HINT)
		return
	var added: PackedStringArray = ShantyHostKeys.add(_model)
	if added.is_empty():
		_say("%s already has every host key." % _model.config.csv_path)
		return
	_show_selected()
	_say("Added %s to %s. Save writes them." % [", ".join(added), _model.config.csv_path])


func _inspect_config() -> void:
	if _model.config == null:
		_say(NO_CONFIG_HINT)
	elif _in_editor():
		EditorInterface.edit_resource(_model.config)


func _inspect(resource: Resource, owner: Resource) -> void:
	if resource == null or not _in_editor():
		return
	_inspected = resource
	_inspected_owner = owner
	EditorInterface.edit_resource(resource)


## An edit in the Inspector to something we handed it marks its owner edited,
## so Save writes the resource that holds it, and redraws what shows it.
func _on_property_edited(_property: String) -> void:
	var edited: Object = EditorInterface.get_inspector().get_edited_object()
	if edited != null and edited == _inspected and _inspected_owner != null:
		_model.touch(_inspected_owner)
		_centre.refresh_scene()


func _on_model_changed() -> void:
	_toolbar.show_coverage(_model.coverage())
	_preview.show_line(_model, _previewed)
	_queue_list_refresh()
	if is_inside_tree():
		_lint_timer.start()


## Refills the list once the edit that changed the model has returned -- an id
## changed in a form shows in its row, and in + Trigger's free ids -- keeping
## the pick. Deferred, so it never runs inside the Tree's own selection signal,
## and coalesced: every edit in a frame shares one refill.
func _queue_list_refresh() -> void:
	if _list_refresh_queued:
		return
	_list_refresh_queued = true
	_refresh_list.call_deferred()


func _refresh_list() -> void:
	_list_refresh_queued = false
	_list.show_model(_model, _selected)


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
	_centre.apply_issues(found)
	_toolbar.show_coverage(_model.coverage())


func _save() -> void:
	if _model.config == null:
		_say("Nothing to save: no Shanty config is open.")
		return
	var result: ShantySaveResult = _model.save()
	_show_issues(result.issues)
	_say(result.message, not result.stale_paths.is_empty())
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


## Writes the Play request for the picked scene or trigger and opens the
## preview host in a game window. Refused, with the reason, while unsaved.
func _play() -> void:
	var refusal: String = ShantyPlay.refusal(_model, _selected)
	if not refusal.is_empty():
		_say(refusal)
		return
	var request: ShantyPlay = ShantyPlay.for_selection(_selected, _preview.shown_locale())
	var error: Error = request.write()
	if error != OK:
		_say("Could not write %s (%s)." % [ShantyPlay.REQUEST_PATH, error_string(error)])
		return
	if _in_editor():
		EditorInterface.play_custom_scene(ShantyPlay.HOST_SCENE)
	_say("Playing %s. Its effects and record print to the Output." % request.resource_path)


## The pane's one link to the editor's filesystem; editor-only.
func _filesystem() -> FilesystemRefresh:
	if _refresh == null:
		_refresh = FilesystemRefresh.new(EditorInterface.get_resource_filesystem())
	return _refresh


## Shows `text` in the status line, with Reload beside it when `offer_reload`.
func _say(text: String, offer_reload: bool = false) -> void:
	_status.text = text
	_status_reload.visible = offer_reload


## True only inside the running editor, where `EditorInterface` is real.
static func _in_editor() -> bool:
	return Engine.is_editor_hint()
