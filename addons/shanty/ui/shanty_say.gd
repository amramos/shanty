class_name ShantySay
extends RefCounted

## The conversations of one scene on the dialogue bar: which line is up, the
## runner behind it, the replies taken and the effects owed. CutscenePlayer makes
## one per scene, and `detach()`es the last; this listens to the bar itself. A
## SayStep reaches it through the player's `say()`/`skip_say()`.
##
## **In a replay** (`replay` not null) every reply is answered from the record,
## and nothing is kept: `effects` and `choices` stay empty, so there is nothing
## to return. The bar speaks the recorded reply as the reply speaker's line
## (DialogueView), and the conversation follows it once the reader taps past it;
## a skip follows it at once, as it walks past every other line. **A line the
## record holds no answer for is where the replay's dialogue ends**: the question
## is read, a warning names the scene and the line, and no conversation after it
## is said -- the record cannot tell which way the reader went, and inventing a
## reply would put words in the reader's mouth. The scene's other steps still
## play.

## Set by the player once the scene is being skipped: lines are walked at once
## and only a reply still stops the walk.
var skipping: bool = false
## Every effect the scene's conversations owe, in the order they were reached.
var effects: Array[ShantyEffect] = []
## `PlayedSceneRecord.choice_key()` -> reply index, for every reply taken.
var choices: Dictionary[String, int] = {}

var _view: DialogueView = null
var _context: ShantyContext = null
var _replay: PlayedSceneRecord = null
var _runner: ShantyRunner = null
var _conversation: ConversationDefinition = null
var _done: Callable = Callable()
## A replay reached a line its record cannot answer: no more dialogue is said.
var _silenced: bool = false


func _init(view: DialogueView, context: ShantyContext, replay: PlayedSceneRecord) -> void:
	_view = view
	_context = context
	_replay = replay
	_view.advance_requested.connect(advance)
	_view.choice_made.connect(choose)
	_view.replay_reply_spoken.connect(answer_replay)


## Stops listening to the bar, for the player's next scene to have it.
func detach() -> void:
	_view.advance_requested.disconnect(advance)
	_view.choice_made.disconnect(choose)
	_view.replay_reply_spoken.disconnect(answer_replay)
	_runner = null


func say(conversation: ConversationDefinition, on_done: Callable) -> void:
	if _silenced:
		on_done.call()
		return
	_start_runner(conversation)
	_done = on_done
	_show_current_line()


func skip_say(conversation: ConversationDefinition, on_done: Callable) -> void:
	if _silenced:
		on_done.call()
		return
	if _runner == null or _conversation != conversation:
		_start_runner(conversation)
	_done = on_done
	_skip_runner()


## What the scene's playing leaves behind: its id, the playthrough, the replies
## taken.
func record(scene_id: StringName, playthrough_ordinal: int) -> PlayedSceneRecord:
	var played := PlayedSceneRecord.new()
	played.scene_id = scene_id
	played.playthrough_ordinal = playthrough_ordinal
	played.choices = choices.duplicate()
	return played


## The bar asked to move past a line that asks nothing.
func advance() -> void:
	if _runner == null or _runner.awaits_choice():
		return
	_runner.advance()
	_show_current_line()


## Reply `index` was taken on the line that asked.
func choose(index: int) -> void:
	if _runner == null:
		return
	_runner.choose(index)
	if skipping:
		_skip_runner()
	else:
		_show_current_line()


## The reader has read the recorded reply `index` and tapped past it: the
## replay goes on through the same path a pressed reply takes. `index` below
## zero is a line the record could not answer: the dialogue ends there.
func answer_replay(index: int) -> void:
	if _runner == null:
		return
	if index < 0:
		_silenced = true
		_end()
		return
	choose(index)


func _start_runner(conversation: ConversationDefinition) -> void:
	_runner = ShantyRunner.new()
	_conversation = conversation
	_runner.start(conversation, _context)


func _show_current_line() -> void:
	var line: DialogueLine = _runner.current()
	if line == null:
		_end()
		return
	_prime_replay_answer(line)
	_view.show()
	_view.show_line(line)


## Walks the conversation at once; on a line owed a reply, shows it complete
## with its replies and waits. `choose()` resumes the skip from there. A replay
## is never owed one: the record answers each line as the walk reaches it.
func _skip_runner() -> void:
	_view.stop_voice()
	while not _runner.skip_to_end():
		if _replay == null:
			_prime_replay_answer(_runner.current())
			_view.show()
			_view.show_line(_runner.current())
			_view.stop_voice()
			_view.open_replies()
			return
		var answer: int = _recorded_answer(_runner.current())
		if answer < 0:
			_silenced = true
			break
		_runner.choose(answer)
	_end()


## In a replay, tells the bar which reply the record holds for `line` before it
## is shown, so its reply turn speaks instead of asking.
func _prime_replay_answer(line: DialogueLine) -> void:
	if _replay == null or line == null or line.choices.is_empty():
		return
	var answer: int = _recorded_answer(line)
	_view.set_replay_answer(answer if answer >= 0 else DialogueView.REPLAY_UNANSWERED)


## The reply the record holds for `line` of the conversation being said, or -1
## -- with a warning naming the scene and the line, since that is where the
## replay's dialogue will end.
func _recorded_answer(line: DialogueLine) -> int:
	var key: String = PlayedSceneRecord.choice_key(_conversation_id(), line.text_key)
	if _replay.choices.has(key):
		return clampi(_replay.choices[key], 0, line.choices.size() - 1)
	push_warning(
		(
			"ShantySay: the record of scene '%s' holds no reply for line '%s'; its replay ends there."
			% [_replay.scene_id, key]
		)
	)
	return -1


func _end() -> void:
	# A replay hands back nothing: its effects and answers are dropped here.
	if _replay == null:
		effects.append_array(_runner.collected_effects())
		_record_choices(_runner.choices_taken())
	_runner = null
	_conversation = null
	_view.clear()
	_view.hide()
	var done: Callable = _done
	_done = Callable()
	if done.is_valid():
		done.call()


## The runner knows lines only by text key; the scene's record needs them by
## conversation too, or two conversations reusing a key would overwrite each
## other's answer.
func _record_choices(taken: Dictionary[String, int]) -> void:
	var conversation_id: StringName = _conversation_id()
	for text_key: String in taken:
		choices[PlayedSceneRecord.choice_key(conversation_id, text_key)] = taken[text_key]


func _conversation_id() -> StringName:
	return _conversation.conversation_id if _conversation != null else &""
