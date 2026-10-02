extends GutTest

## DialogueView's reading preferences and sounds over Shanty-only fixtures:
## reduced motion types nothing, auto-advance and the name
## plate follow their settings, blips tick once per group of revealed characters
## and never with `text_blips` off, a line's voice starts with it and stops when
## the reader moves on, and a missing sample is silence rather than an error.

const VIEW_SCENE: PackedScene = preload("res://addons/shanty/ui/dialogue_view.tscn")

var _view: DialogueView
var _settings: ShantyViewSettings
var _advanced: int = 0


func before_each() -> void:
	_advanced = 0
	_view = VIEW_SCENE.instantiate()
	add_child_autofree(_view)
	_settings = ShantyViewSettings.new()
	_view.advance_requested.connect(func() -> void: _advanced += 1)


func _line(text_key: String = "A LINE OF TWELVE CHARACTERS") -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_id = &"anyone"
	line.text_key = text_key
	return line


## A short silent stream, enough for a player to hold a playback.
func _stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(8000)
	stream.data = silence
	return stream


func test_reduced_motion_types_nothing() -> void:
	_settings.text_speed_chars_per_second = 1.0
	_settings.reduced_motion = true
	_view.configure(null, _settings)

	_view.show_line(_line())

	assert_false(_view.is_revealing(), "the line is whole at once")


func test_auto_advance_moves_a_finished_line_on_and_off_waits() -> void:
	_settings.text_speed_chars_per_second = 0.0
	_settings.auto_advance = true
	_view.configure(null, _settings)
	_view.show_line(_line())
	await wait_seconds(DialogueView.AUTO_ADVANCE_DELAY + 0.3)
	assert_eq(_advanced, 1, "on by itself after a beat")

	_settings.auto_advance = false
	_view.show_line(_line())
	await wait_seconds(DialogueView.AUTO_ADVANCE_DELAY + 0.3)
	assert_eq(_advanced, 1, "off: it waits for the reader")


func test_the_name_plate_follows_its_setting() -> void:
	_settings.speaker_names = false
	_view.configure(null, _settings)
	_view.show_line(_line())
	var plate: Label = _view.find_child("NamePlate", true, false)
	assert_false(plate.visible)
	_settings.speaker_names = true
	_view.show_line(_line())
	assert_true(plate.visible)


## A speaker with no face shows a flat plate that carries the name; with names
## off that plate is still there -- the frame never goes empty -- but blank.
func test_names_off_blanks_the_faceless_plate_too() -> void:
	_settings.speaker_names = false
	_view.configure(null, _settings)
	_view.show_line(_line())
	var portrait: Control = _view.find_child("Portrait", true, false)
	var plate_name: Label = _view.find_child("PlateName", true, false)

	assert_true(portrait.visible, "the plate stays")
	assert_true(plate_name.visible)
	assert_eq(plate_name.text, "", "and says no name")
	_settings.speaker_names = true
	_view.show_line(_line())
	assert_eq(plate_name.text, "anyone", "names on: the plate names the speaker")


func test_blips_tick_once_per_group_of_revealed_characters() -> void:
	var blips: Array[int] = [0]
	_view.line_audio().blipped.connect(func() -> void: blips[0] += 1)
	_settings.text_speed_chars_per_second = 0.0
	_view.configure(null, _settings)
	_view.line_audio().restart_blips()

	for count: int in range(1, 13):
		_view.line_audio().revealed(count)

	assert_eq(blips[0], 12 / ShantyLineAudio.CHARACTERS_PER_BLIP, "one per group begun")


func test_blips_are_silent_when_turned_off() -> void:
	var blips: Array[int] = [0]
	_view.line_audio().blipped.connect(func() -> void: blips[0] += 1)
	_settings.text_speed_chars_per_second = 200.0
	_settings.text_blips = false
	_view.configure(null, _settings)
	_view.show_line(_line())
	await wait_until(func() -> bool: return not _view.is_revealing(), 2.0)

	assert_eq(blips[0], 0)


func test_a_line_typing_out_blips_without_a_sample_and_without_an_error() -> void:
	var blips: Array[int] = [0]
	_view.line_audio().blipped.connect(func() -> void: blips[0] += 1)
	_settings.text_speed_chars_per_second = 200.0
	_settings.text_blip = null
	_view.configure(null, _settings)
	_view.show_line(_line())
	await wait_until(func() -> bool: return not _view.is_revealing(), 2.0)

	assert_gt(blips[0], 0, "the blips were owed; with no sample nothing is heard")


func test_a_voice_starts_with_its_line_and_stops_when_the_reader_moves_on() -> void:
	_settings.text_speed_chars_per_second = 0.0
	_view.configure(null, _settings)
	var voiced: DialogueLine = _line()
	voiced.voice = _stream()

	_view.show_line(voiced)
	assert_true(_view.line_audio().is_voice_playing(), "the line speaks as it appears")
	_view.handle_tap()
	assert_false(_view.line_audio().is_voice_playing(), "and stops when the reader goes on")

	_view.show_line(voiced)
	_view.show_line(_line())
	assert_false(_view.line_audio().is_voice_playing(), "a line with no voice silences the last")


func test_a_skip_silences_the_voice() -> void:
	_settings.text_speed_chars_per_second = 0.0
	_view.configure(null, _settings)
	var voiced: DialogueLine = _line()
	voiced.voice = _stream()
	_view.show_line(voiced)

	_view.stop_voice()

	assert_false(_view.line_audio().is_voice_playing())


## Found by a pseudolocalization pass: the line arrives translated and
## rendered, and a second translation by the label itself ran its BBCode back
## through the catalogue, showing the `[lb]` escape as text.
func test_a_rendered_line_is_never_translated_a_second_time() -> void:
	_settings.text_speed_chars_per_second = 0.0
	_view.configure(null, _settings)
	TranslationServer.pseudolocalization_enabled = true
	_view.show_line(_line("[A] BRACKETED LINE"))
	var shown: String = _view.line_text()
	TranslationServer.pseudolocalization_enabled = false

	assert_false(shown.contains("lb]"), "the escape stays an escape: %s" % shown)
	var line: RichTextLabel = _view.find_child("Line", true, false)
	assert_eq(line.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
