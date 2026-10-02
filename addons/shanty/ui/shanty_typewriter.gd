class_name ShantyTypewriter
extends RefCounted

## Types a line out on the bar's label at the reader's speed, and ticks the
## line's blips as the characters appear. DialogueView owns one, starts it on
## every line it draws, feeds it the frame's delta, and finishes it when the
## reader taps or the whole line is out.
##
## **Reduced motion and a speed of zero type nothing**: `start()` reports the
## line should appear whole, and the view completes it at once -- the same path
## a tap takes, so a reader who asked for no motion loses nothing else.

var _label: RichTextLabel = null
var _audio: ShantyLineAudio = null
var _settings: ShantyViewSettings = ShantyViewSettings.new()
var _revealing: bool = false
var _revealed: float = 0.0


func _init(label: RichTextLabel, audio: ShantyLineAudio) -> void:
	_label = label
	_audio = audio


func configure(settings: ShantyViewSettings) -> void:
	if settings != null:
		_settings = settings


func is_revealing() -> bool:
	return _revealing


## Hides the label's text and starts typing it. False when the reader's
## settings show a line whole: the caller then completes it at once.
func start() -> bool:
	_revealed = 0.0
	_label.visible_characters = 0
	_revealing = true
	return _settings.text_speed_chars_per_second > 0.0 and not _settings.reduced_motion


## Reveals `delta` seconds' worth of characters. True once the whole line is
## out -- the caller completes it, which is also what a tap does.
func advance(delta: float) -> bool:
	if not _revealing:
		return false
	_revealed += delta * _settings.text_speed_chars_per_second
	if _revealed >= _label.get_total_character_count():
		return true
	_label.visible_characters = int(_revealed)
	_audio.revealed(int(_revealed))
	return false


## Shows the rest of the line and stops typing.
func finish() -> void:
	_revealing = false
	_label.visible_characters = -1


## Stops typing where it stands, for a bar being cleared.
func stop() -> void:
	_revealing = false
