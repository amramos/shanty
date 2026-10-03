extends Control

## The game window the Shanty tab's Play opens through
## `EditorInterface.play_custom_scene()`. It reads the request the tab wrote
## (`ShantyPlay`), loads the config, asks the host's `ShantyPreviewHost` for a
## context, speakers and settings, and plays the scene -- or the scene the
## picked trigger chooses -- through the real `CutscenePlayer`. Every effect the
## scene hands back and the record it leaves are printed to the editor's Output;
## nothing is applied and nothing is saved. Escape closes the window.
##
## **The theme is set in code, twice.** On this root, and on each Control the
## player holds directly: a `CanvasLayer` does not pass a parent's theme on.

## The scene finished; what a host's own code would have received.
signal played(record: PlayedSceneRecord, effects: Array[ShantyEffect])

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")

## Where the tab wrote what to play. A test points it elsewhere before ready.
var request_path: String = ShantyPlay.REQUEST_PATH
var host: ShantyPreviewHost = null
## The record the scene left, once it has finished.
var record: PlayedSceneRecord = null
## Every line this window printed, in order.
var report: PackedStringArray = []

var _player: CutscenePlayer = null
var _translations: Array[Translation] = []
var _previous_highlight: Color = Color.WHITE
var _previous_locale: String = ""

@onready var _caption: Label = %Caption


func _ready() -> void:
	_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_previous_highlight = ShantyText.highlight_colour()
	_previous_locale = TranslationServer.get_locale()
	var request: ShantyPlay = ShantyPlay.read(request_path)
	var config: ShantyProjectConfig = request.load_config() if request != null else null
	if config == null:
		_end("Nothing to play: no request at %s, or no Shanty config." % request_path)
		return
	host = ShantyPreviewHost.for_config(config)
	for translation: Translation in host.make_translations():
		TranslationServer.add_translation(translation)
		_translations.append(translation)
	if not request.locale.is_empty():
		TranslationServer.set_locale(request.locale)
	ShantyText.set_highlight_colour(config.highlight_colour)
	theme = ShantyPreviewModel.stage_theme(config)
	var context: ShantyContext = host.make_context()
	var scene: CutsceneDefinition = _scene_to_play(request.resource_path, context)
	if scene == null:
		return
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	for child: Node in _player.get_children():
		if child is Control:
			(child as Control).theme = theme
	_player.finished.connect(_on_finished.bind(scene), CONNECT_ONE_SHOT)
	_say("playing '%s' in %s." % [scene.scene_id, TranslationServer.get_locale()])
	_player.play(scene, context, host.make_speaker_provider(), host.make_settings())


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().quit()


## Puts back what this window changed in the process it shares with a test.
func _exit_tree() -> void:
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	ShantyText.set_highlight_colour(_previous_highlight)
	if not _previous_locale.is_empty():
		TranslationServer.set_locale(_previous_locale)


## The player on screen, or null before and after the scene.
func player() -> CutscenePlayer:
	return _player


## The scene at `path`, or the one the trigger at `path` chooses now; null,
## with the reason on screen, when there is none.
func _scene_to_play(path: String, context: ShantyContext) -> CutsceneDefinition:
	var resource: Resource = ShantyFiles.load_resource(path)
	if resource is CutsceneDefinition:
		return resource
	if resource is StoryTriggerDefinition:
		var trigger: StoryTriggerDefinition = resource
		var chosen: StoryCandidate = ShantySelector.select(trigger, context, host.make_records())
		if chosen == null:
			_end("'%s' chooses nothing now. Press Escape or close." % trigger.trigger_id)
			return null
		_say("'%s' chose '%s'." % [trigger.trigger_id, chosen.cutscene.scene_id])
		return chosen.cutscene
	_end("%s is not a scene or a trigger. Press Escape or close." % path)
	return null


func _on_finished(
	finished_record: PlayedSceneRecord, effects: Array[ShantyEffect], scene: CutsceneDefinition
) -> void:
	record = finished_record
	for effect: ShantyEffect in effects:
		_say("effect " + ShantyPlay.describe(effect))
	_say("record " + JSON.stringify(record.to_dictionary()))
	_player.queue_free()
	_player = null
	if record.scene_id.is_empty():
		_end("'%s' was refused; the Output says why. Press Escape or close." % scene.scene_id)
	else:
		_end("Played %s. Press Escape or close." % scene.scene_id)
	played.emit(record, effects)


func _end(caption: String) -> void:
	_say(caption)
	_caption.text = caption
	_caption.show()


func _say(line: String) -> void:
	report.append(line)
	print("Shanty Play: ", line)
