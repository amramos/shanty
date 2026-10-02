class_name DialogueView
extends Control

## The dialogue bar: docked to the top of the frame, a portrait at its left, the
## speaker's name plate and the line typing out. One view serves a conversation
## over the live game and a scene over a backdrop alike; whether anything behind
## it is dimmed is its host's business.
##
## **Replies are the answering speaker's turn, not more of the asker's line.**
## A line that asks reads like any other: it types out (a tap finishes it), then
## waits under the continue marker. The *next* tap hands the bar over -- *reply
## mode*: the reply speaker's face and name (the line's `reply_speaker_id`, else
## the host's), a short placeholder where the line was, and the replies as
## bordered, unnumbered buttons indented under it. So the question is always
## read in full, at any text speed. A skip goes straight to reply mode through
## `open_replies()`. A reply speaker the provider does not know keeps the asker,
## their question and the buttons. The turn's state and its buttons are
## ShantyReplyTurn's; this view draws what it decides.
##
## **It takes no input of its own except the reply buttons.** Its host routes a
## press here through `handle_tap()`, because the same press held is the skip,
## and only the host times the hold. Every non-button node ignores the mouse so
## a click on the bar reaches the host's shield beneath it.
##
## Text speed, auto-advance and name plates come from the ShantyViewSettings the
## host injects; the view never reads a settings store itself.
##
## **A replay answers from the record, as speech.** Given `set_replay_answer()`
## before an asking line, the tap that would open the reply turn instead gives
## the bar to the reply speaker with the recorded reply as an ordinary line:
## their face and name, the text typing out, the continue marker, a tap to go
## on -- no buttons and no placeholder, because the reader is being reminded of
## what they said, not asked again. That tap reports `replay_reply_spoken` with
## the reply's index. Given REPLAY_UNANSWERED -- the record holds no reply for
## the line -- the tap after the question reports -1 and nothing is spoken.
##
## **Reduced motion types nothing**: every line appears whole, as at the
## instant text speed (ShantyTypewriter). A line's `voice` and the text blips are
## ShantyLineAudio's.

signal line_completed
signal choice_made(index: int)
signal advance_requested
## A replay's recorded reply `index` was spoken and the reader tapped past it;
## -1 when the record held no reply for the question just read.
signal replay_reply_spoken(index: int)

## Theme type variations the host's theme is expected to declare. A host that
## declares none gets the engine's plain Label/RichTextLabel/Button look.
const NAME_VARIATION: StringName = &"ShantyName"
const CHOICE_VARIATION: StringName = ShantyChoiceButton.VARIATION
## Translation key for what stands in the line while a reply is chosen. The
## host's catalogue defines it.
const REPLY_PLACEHOLDER_KEY: String = "SHANTY_REPLY_PLACEHOLDER"
## Seconds a finished line waits before advancing on its own, when asked to.
const AUTO_ADVANCE_DELAY: float = 1.6
## What `set_replay_answer()` is given for a line the record cannot answer.
const REPLAY_UNANSWERED: int = ShantyReplyTurn.REPLAY_UNANSWERED

var _provider: ShantySpeakerProvider = ShantySpeakerProvider.new()
var _settings: ShantyViewSettings = ShantyViewSettings.new()
var _line_data: DialogueLine = null
var _auto_wait: float = -1.0
var _audio: ShantyLineAudio = null
var _typewriter: ShantyTypewriter = null
var _turn: ShantyReplyTurn = null

@onready var _bar: PanelContainer = %Bar
@onready var _face: TextureRect = %Face
@onready var _plate_name: Label = %PlateName
@onready var _name_plate: Label = %NamePlate
@onready var _line: RichTextLabel = %Line
@onready var _reply_block: Control = %ReplyBlock
@onready var _choices: VBoxContainer = %Choices
@onready var _continue_marker: Control = %ContinueMarker


func _ready() -> void:
	_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_line.bbcode_enabled = true
	# Every text here arrives translated and rendered (ShantyText). Left to
	# translate itself again, the line would run its own BBCode through the
	# catalogue -- under pseudolocalization that mangles the `[lb]` escapes.
	for label: Control in [_line, _name_plate, _plate_name]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_audio = ShantyLineAudio.new()
	_audio.name = "LineAudio"
	add_child(_audio)
	_typewriter = ShantyTypewriter.new(_line, _audio)
	_typewriter.configure(_settings)
	_turn = ShantyReplyTurn.new(_choices, _reply_block)
	_turn.chosen.connect(choice_made.emit)
	clear()


func _process(delta: float) -> void:
	if _typewriter.is_revealing():
		if _typewriter.advance(delta):
			complete_line()
	elif _auto_wait >= 0.0:
		_auto_wait -= delta
		if _auto_wait < 0.0:
			_go_on()


func configure(provider: ShantySpeakerProvider, settings: ShantyViewSettings) -> void:
	if provider != null:
		_provider = provider
	if settings != null:
		_settings = settings
	_audio.configure(_settings)
	_typewriter.configure(_settings)


## Shows `line` and starts typing it. If it asks, the reply turn begins on the
## tap after it has fully revealed.
func show_line(line: DialogueLine) -> void:
	_line_data = line
	_auto_wait = -1.0
	_turn.end_line()
	_continue_marker.visible = false
	_show_speaker(_provider.resolve(line.speaker_id), line.face)
	_line.text = ShantyText.render(line.text_key, _provider)
	_audio.start_line(line.voice)
	_start_reveal()


func is_revealing() -> bool:
	return _typewriter.is_revealing()


## True while replies are on screen and waiting for one to be chosen.
func is_waiting_for_choice() -> bool:
	return _turn.is_offering()


## True while the bar belongs to the reply speaker rather than the asker.
func is_replying() -> bool:
	return _turn.is_replying()


## True while a replay's recorded reply is on the bar as the reply speaker's line.
func is_speaking_recorded_reply() -> bool:
	return _turn.is_speaking()


## What the bar reads right now, tags removed: the line, or the recorded reply
## being spoken in its place.
func line_text() -> String:
	return _line.get_parsed_text()


## The speaker's name as the plate draws it.
func speaker_name() -> String:
	return _name_plate.text


## The line's voice and blips, for a test to listen to.
func line_audio() -> ShantyLineAudio:
	return _audio


## The line on the bar, or null. The question, even in reply mode.
func current_line() -> DialogueLine:
	return _line_data


## Reveals the rest of the line at once and waits under the continue marker.
## Auto-advance never moves past a question: only a tap hands it over.
func complete_line() -> void:
	if _line_data == null:
		return
	_typewriter.finish()
	_continue_marker.visible = true
	if _settings.auto_advance and (not _asks() or _turn.is_speaking()):
		_auto_wait = AUTO_ADVANCE_DELAY
	line_completed.emit()


## Completes the line and, if it asks, hands the turn over at once -- for a
## skip, which stops on a question but has no reason to linger on it.
func open_replies() -> void:
	if _line_data == null:
		return
	if _typewriter.is_revealing():
		complete_line()
	if _asks() and not _turn.is_replying():
		_begin_reply_turn()


## A press from the host: finishes a line still typing, otherwise asks to move
## on. Ignored while replies are waiting -- only a reply answers those.
func handle_tap() -> void:
	if _line_data == null:
		return
	if _typewriter.is_revealing():
		complete_line()
	elif _turn.is_speaking():
		_go_on()
	elif _asks() and not _turn.is_replying():
		_begin_reply_turn()
	elif not is_waiting_for_choice():
		_go_on()


## Makes the next reply turn a replay's: reply `index` spoken by the reply
## speaker, or nothing spoken for REPLAY_UNANSWERED.
func set_replay_answer(index: int) -> void:
	_turn.set_replay_answer(index)


## Silences the line's voice -- a skip walks past it.
func stop_voice() -> void:
	_audio.stop_voice()


func clear() -> void:
	_turn.clear()
	_line_data = null
	_typewriter.stop()
	_auto_wait = -1.0
	_line.text = ""
	_name_plate.text = ""
	_face.texture = null
	_continue_marker.visible = false
	if _audio != null:
		_audio.stop_voice()


## The bar's height on the UI base, for a host's layout budget.
func bar_height() -> float:
	return _bar.size.y


## The reply buttons currently listed, in order.
func choice_buttons() -> Array[Button]:
	return _turn.buttons()


func _show_speaker(speaker: ShantySpeaker, face_tag: StringName) -> void:
	_name_plate.text = speaker.display_name
	_name_plate.theme_type_variation = (
		speaker.colour_variation if not speaker.colour_variation.is_empty() else NAME_VARIATION
	)
	_name_plate.visible = _settings.speaker_names
	var face: Texture2D = speaker.face_texture(face_tag)
	_face.texture = face
	_face.visible = face != null
	# A missing face is a flat plate with the name on it, never an empty frame:
	# art is allowed to arrive after the words. With `speaker_names` off the
	# reader asked for no names anywhere, so the plate stays and stays blank.
	_plate_name.text = speaker.display_name if _settings.speaker_names else ""
	_plate_name.visible = face == null


## The reply speaker takes the bar, unless nobody is named or the provider does
## not know them: then the asker and the question stay, with the buttons under.
## In a replay the turn is spoken instead (`_speak_recorded_reply()`).
func _begin_reply_turn() -> void:
	_audio.stop_voice()
	var opening: ShantyReplyTurn.Opening = _turn.open(_line_data)
	if opening == ShantyReplyTurn.Opening.UNANSWERED:
		replay_reply_spoken.emit(-1)
		return
	_continue_marker.visible = false
	var speaker: ShantySpeaker = ShantyReplyTurn.reply_speaker(_line_data, _settings, _provider)
	if opening == ShantyReplyTurn.Opening.SPOKEN:
		_speak_recorded_reply(_turn.spoken_index(), speaker)
		return
	if speaker != null:
		_show_speaker(speaker, &"")
		_line.text = ShantyText.render(REPLY_PLACEHOLDER_KEY, _provider)
		_line.visible_characters = -1
	_turn.offer(_line_data.choices, _provider)


## A replay's recorded reply, said as a line: the reply speaker's face and name
## (the asker's, when there is nobody to hand over to), the reply's text typing
## out, then the continue marker.
func _speak_recorded_reply(index: int, speaker: ShantySpeaker) -> void:
	if speaker != null:
		_show_speaker(speaker, &"")
	var choice: DialogueChoice = _line_data.choices[index]
	_line.text = ShantyText.render(choice.text_key if choice != null else "", _provider)
	_audio.restart_blips()
	_start_reveal()


func _start_reveal() -> void:
	if not _typewriter.start():
		complete_line()


## Past a finished line: a recorded reply hands the replay back to its
## conversation; any other line asks for the next one.
func _go_on() -> void:
	_auto_wait = -1.0
	_audio.stop_voice()
	if _turn.is_speaking():
		replay_reply_spoken.emit(_turn.take_spoken())
		return
	advance_requested.emit()


func _asks() -> bool:
	return _line_data != null and not _line_data.choices.is_empty()
