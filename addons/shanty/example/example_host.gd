extends Control

## The smallest whole host: everything a game does around Shanty, with no game.
## It owns the context, the speakers and the reading settings; opens a
## CutscenePlayer for each playing and frees it after; applies the effects a
## scene hands back; keeps the record; and replays it read-only.
##
## **Its strings are its own.** The example's keys live in `example_strings.csv`
## beside it and are loaded into the TranslationServer while this node is in
## the tree (`load_translations()`), so it reads without any host catalogue. A
## real host adds its CSV to Project Settings > Localization instead -- this
## shortcut reads the source file, which an exported build does not include.

## A first playing finished; its effects are already applied.
signal played(record: PlayedSceneRecord)
## A replay closed. Nothing was applied or recorded.
signal replayed

const ExampleContext := preload("res://addons/shanty/example/example_context.gd")
const SetFlagEffect := preload("res://addons/shanty/example/example_effect.gd")
const ExampleSpeakerProvider := preload("res://addons/shanty/example/example_speaker_provider.gd")
const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")
const SCENE: CutsceneDefinition = preload("res://addons/shanty/example/example_scene.tres")
const STRINGS_PATH: String = "res://addons/shanty/example/example_strings.csv"
## The colour `[hl]` words draw in. Shanty never knows a host's palette.
const HIGHLIGHT_COLOUR: Color = Color8(237, 161, 43)
## Set before the first playing: the scene's first line asks for it.
const STARTING_FLAG: StringName = &"example_lamp_dark"

## The host's world. Effects write here; conditions read here.
var context: ExampleContext = ExampleContext.new()
## The reader's preferences, injected into every playing.
var settings: ShantyViewSettings = ShantyViewSettings.new()
## The last first playing's record, or null before one has finished.
var last_record: PlayedSceneRecord = null
## How many effects this host has applied, ever -- a replay must add none.
var effects_applied: int = 0

var _speakers: ExampleSpeakerProvider = ExampleSpeakerProvider.new()
var _player: CutscenePlayer = null
var _translations: Array[Translation] = []
var _previous_highlight: Color = Color.WHITE

@onready var _play_button: Button = %PlayButton
@onready var _replay_button: Button = %ReplayButton


func _ready() -> void:
	_translations = load_translations(STRINGS_PATH)
	for translation: Translation in _translations:
		TranslationServer.add_translation(translation)
	# Static and shared: put back on exit, so the example never recolours a host.
	_previous_highlight = ShantyText.highlight_colour()
	ShantyText.set_highlight_colour(HIGHLIGHT_COLOUR)
	context.set_flag(STARTING_FLAG, true)
	_play_button.pressed.connect(play)
	_replay_button.pressed.connect(replay)
	_replay_button.disabled = true
	_play_button.grab_focus.call_deferred()


func _exit_tree() -> void:
	for translation: Translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	ShantyText.set_highlight_colour(_previous_highlight)


## Plays the scene for the first time -- or again, as a new playing.
func play() -> void:
	if _player != null:
		return
	_open().finished.connect(_on_finished, CONNECT_ONE_SHOT)
	_player.play(SCENE, context, _speakers, settings)


## Replays the last record read-only. Nothing it collects is applied.
func replay() -> void:
	if _player != null or last_record == null:
		return
	_open().replay_finished.connect(_on_replay_finished, CONNECT_ONE_SHOT)
	_player.play_replay(SCENE, last_record, context, _speakers, settings)


## The player on screen, or null between scenes.
func player() -> CutscenePlayer:
	return _player


## One Translation per locale column of the CSV at `path`, in Godot's own CSV
## shape: a `keys` column, then one column per locale; a column whose header
## starts with `_` is a note and is skipped.
static func load_translations(path: String) -> Array[Translation]:
	var translations: Array[Translation] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Shanty example: cannot read %s." % path)
		return translations
	var header: PackedStringArray = file.get_csv_line()
	var columns: Dictionary[int, Translation] = {}
	for column: int in range(1, header.size()):
		if header[column].begins_with("_"):
			continue
		var translation := Translation.new()
		translation.locale = header[column]
		columns[column] = translation
		translations.append(translation)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < header.size() or row[0].is_empty():
			continue
		for column: int in columns:
			columns[column].add_message(row[0], row[column])
	return translations


func _open() -> CutscenePlayer:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	return _player


func _close() -> void:
	if _player != null:
		_player.queue_free()
		_player = null
	_play_button.grab_focus()


func _on_finished(record: PlayedSceneRecord, effects: Array[ShantyEffect]) -> void:
	for effect: ShantyEffect in effects:
		_apply(effect)
	last_record = record
	_replay_button.disabled = false
	print("Shanty example: played ", JSON.stringify(record.to_dictionary()))
	_close()
	played.emit(record)


func _on_replay_finished() -> void:
	print("Shanty example: replayed ", last_record.scene_id)
	_close()
	replayed.emit()


## The host decides what each effect means. This one knows a single kind.
func _apply(effect: ShantyEffect) -> void:
	var set_flag: SetFlagEffect = effect as SetFlagEffect
	if set_flag == null:
		push_warning("Shanty example: no meaning for effect %s." % effect)
		return
	context.set_flag(set_flag.flag, set_flag.value)
	effects_applied += 1
