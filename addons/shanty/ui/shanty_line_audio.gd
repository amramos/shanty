class_name ShantyLineAudio
extends Node

## The sound of a line on the dialogue bar: its optional recorded voice, and the
## text blips that tick as it types out. DialogueView owns one and tells it when
## a line starts, how much of it has revealed, and when it is gone.
##
## **Both are optional and silence is never an error.** A line without a voice
## plays none; a host without a blip sample still has its blips counted
## (`blipped`) but hears nothing, so a sample can arrive after the words. With
## `text_blips` off nothing is counted at all.
##
## Pausable with its owner: a pause menu over a scene freezes a voice mid-word.

## A blip was owed: `text_blips` is on and another group of characters revealed.
## Emitted whether or not a sample is there to be heard.
signal blipped

## Revealed characters per blip -- one short sound for every few letters reads
## as speech; one per letter reads as a typewriter.
const CHARACTERS_PER_BLIP: int = 3

var _settings: ShantyViewSettings = ShantyViewSettings.new()
var _voice: AudioStreamPlayer = null
var _blip: AudioStreamPlayer = null
## Blips already played for the line being revealed.
var _blips_played: int = 0


func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	add_child(_voice)
	_blip = AudioStreamPlayer.new()
	_blip.name = "Blip"
	add_child(_blip)


func configure(settings: ShantyViewSettings) -> void:
	if settings != null:
		_settings = settings


## A new line begins: the previous voice stops, this one's starts if it has one,
## and the blip count starts over.
func start_line(voice: AudioStream) -> void:
	stop_voice()
	_blips_played = 0
	if voice == null or _voice == null:
		return
	_voice.stream = voice
	_voice.bus = _settings.voice_bus
	_voice.play()


## The same line is replaced by another text with no voice of its own -- a
## replay's recorded reply -- so only the blips start over.
func restart_blips() -> void:
	_blips_played = 0


func stop_voice() -> void:
	if _voice != null and _voice.playing:
		_voice.stop()


func is_voice_playing() -> bool:
	return _voice != null and _voice.playing


## `count` characters of the line are now visible; a blip sounds for each group
## of CHARACTERS_PER_BLIP that has begun since the last.
func revealed(count: int) -> void:
	if not _settings.text_blips or count <= 0:
		return
	var owed: int = (count + CHARACTERS_PER_BLIP - 1) / CHARACTERS_PER_BLIP
	if owed <= _blips_played:
		return
	_blips_played = owed
	blipped.emit()
	if _settings.text_blip == null or _blip == null:
		return
	_blip.stream = _settings.text_blip
	_blip.bus = _settings.blip_bus
	_blip.play()
