class_name ShantyReplyTurn
extends RefCounted

## The reply half of a line that asks: whether the bar has been handed to the
## reply speaker, which reply a replay will speak in place of the buttons, and
## the buttons themselves. DialogueView owns one and decides what the bar shows;
## this decides what the turn *is*.
##
## **A turn opens one of three ways** (`open()`): OFFERED, the replies listed as
## buttons; SPOKEN, a replay's recorded reply said as the reply speaker's line;
## or UNANSWERED, a replay whose record holds no reply for the line, where
## nothing is said and the turn never begins.

## A reply button was pressed; the buttons are already gone.
signal chosen(index: int)

enum Opening {
	## The replies are listed as buttons for the reader to choose from.
	OFFERED,
	## A replay speaks the recorded reply as an ordinary line.
	SPOKEN,
	## A replay has no recorded reply: nothing is said and no turn begins.
	UNANSWERED,
}

## What `set_replay_answer()` is given for a line the record cannot answer.
const REPLAY_UNANSWERED: int = -2

var _choices: VBoxContainer = null
var _block: Control = null
var _replying: bool = false
## The reply a replay speaks for the next asking line; -1 offers the replies,
## REPLAY_UNANSWERED speaks none.
var _replay_index: int = -1
## The recorded reply on the bar right now, or -1.
var _spoken: int = -1


## `choices` holds the buttons; `block` is what frames them, shown only while
## there are any.
func _init(choices: VBoxContainer, block: Control) -> void:
	_choices = choices
	_block = block


## Who answers `line`, or null when nobody is named or `provider` does not know
## them -- then the asker and the question stay on the bar. The line's own
## `reply_speaker_id` wins over the host's.
static func reply_speaker(
	line: DialogueLine, settings: ShantyViewSettings, provider: ShantySpeakerProvider
) -> ShantySpeaker:
	var speaker_id: StringName = line.reply_speaker_id
	if speaker_id.is_empty():
		speaker_id = settings.reply_speaker_id
	if speaker_id.is_empty():
		return null
	var speaker: ShantySpeaker = provider.resolve(speaker_id)
	return speaker if speaker.known else null


## True while the bar belongs to the reply speaker rather than the asker.
func is_replying() -> bool:
	return _replying


## True while a replay's recorded reply is on the bar as the reply speaker's line.
func is_speaking() -> bool:
	return _spoken >= 0


## The recorded reply being spoken, or -1.
func spoken_index() -> int:
	return _spoken


## True while replies are listed and waiting for one to be chosen.
func is_offering() -> bool:
	return _choices.get_child_count() > 0


## Makes the next turn a replay's: reply `index` spoken, or nothing for
## REPLAY_UNANSWERED. Kept across `end_line()`, because it is given before the
## asking line is shown.
func set_replay_answer(index: int) -> void:
	_replay_index = index


## Opens the turn for `line` and says how; the replay answer, once used, is spent.
func open(line: DialogueLine) -> Opening:
	if _replay_index == REPLAY_UNANSWERED:
		# Nothing was recorded, so there is nobody to hand the bar to and nothing
		# to say: the question was read, and the replay goes no further.
		_replay_index = -1
		return Opening.UNANSWERED
	_replying = true
	if _replay_index >= 0:
		_spoken = clampi(_replay_index, 0, line.choices.size() - 1)
		_replay_index = -1
		return Opening.SPOKEN
	return Opening.OFFERED


## The reader has tapped past the spoken reply: returns its index and ends it.
func take_spoken() -> int:
	var spoken: int = _spoken
	_spoken = -1
	return spoken


## Lists `choices` as buttons, named through `provider`, the first focused.
func offer(choices: Array[DialogueChoice], provider: ShantySpeakerProvider) -> void:
	clear_buttons()
	for index: int in choices.size():
		var button := ShantyChoiceButton.for_choice(choices[index], provider)
		button.pressed.connect(_on_pressed.bind(index))
		_choices.add_child(button)
	_block.visible = _choices.get_child_count() > 0
	var listed: Array[Button] = buttons()
	ShantyChoiceButton.link_focus(listed)
	if not listed.is_empty():
		listed[0].grab_focus()


## The reply buttons currently listed, in order.
func buttons() -> Array[Button]:
	var listed: Array[Button] = []
	for child: Node in _choices.get_children():
		if child is Button:
			listed.append(child)
	return listed


## A new line is on the bar: whatever turn the last one had is over.
func end_line() -> void:
	_replying = false
	_spoken = -1
	clear_buttons()


## The bar is cleared: the turn ends and a pending replay answer is dropped.
func clear() -> void:
	_replay_index = -1
	end_line()


func clear_buttons() -> void:
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_block.visible = false


func _on_pressed(index: int) -> void:
	clear_buttons()
	chosen.emit(index)
