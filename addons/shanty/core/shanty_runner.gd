class_name ShantyRunner
extends RefCounted

## Walks one conversation. Pure: no nodes, no time, no input -- the view and
## the player decide when to call `advance()` or `choose()`, and the runner
## only says which line is current and what the host owes for it.
##
## **A line's effects are collected when the line becomes current**, whether
## it is read or held past, and a reply's effects when it is chosen. That one
## rule is what makes a skipped conversation return the same effects as a
## played one: `skip_to_end()` walks the same lines through the same
## entry point. A line whose conditions fail is never current, so its effects
## are never collected.
##
## **A skip never answers for the player.** `skip_to_end()` stops on a line that
## offers choices and reports that it has not finished; the caller shows the
## choices, takes the reply, and may skip again.

var _conversation: ConversationDefinition = null
var _context: ShantyContext = null
var _index: int = 0
var _effects: Array[ShantyEffect] = []
var _choices_taken: Dictionary[String, int] = {}


## True when following lines and replies from any line can come back to it. A
## conversation is short and one level deep by design, so a loop is authoring
## error; tests run this over every authored conversation.
static func has_cycle(conversation: ConversationDefinition) -> bool:
	if conversation == null:
		return false
	var count: int = conversation.lines.size()
	# 0 = unvisited, 1 = on the current path, 2 = finished.
	var marks: Array[int] = []
	marks.resize(count)
	marks.fill(0)
	for start: int in count:
		if marks[start] == 0 and _visit_finds_cycle(conversation, start, marks):
			return true
	return false


## The index of the line labelled `label`, or -1.
static func index_of_label(conversation: ConversationDefinition, label: StringName) -> int:
	if conversation == null or label.is_empty():
		return -1
	for index: int in conversation.lines.size():
		var line: DialogueLine = conversation.lines[index]
		if line != null and line.label == label:
			return index
	return -1


static func _successors(conversation: ConversationDefinition, index: int) -> Array[int]:
	var line: DialogueLine = conversation.lines[index]
	var next: Array[int] = []
	if line == null or line.choices.is_empty():
		next.append(index + 1)
		return next
	for choice: DialogueChoice in line.choices:
		if choice == null or choice.jump_label.is_empty():
			next.append(index + 1)
		else:
			next.append(index_of_label(conversation, choice.jump_label))
	return next


static func _visit_finds_cycle(
	conversation: ConversationDefinition, index: int, marks: Array[int]
) -> bool:
	marks[index] = 1
	for next: int in _successors(conversation, index):
		if next < 0 or next >= marks.size():
			continue
		if marks[next] == 1:
			return true
		if marks[next] == 0 and _visit_finds_cycle(conversation, next, marks):
			return true
	marks[index] = 2
	return false


## Begins `conversation` at its first line whose conditions hold. A null
## context is a context that holds nothing.
func start(conversation: ConversationDefinition, context: ShantyContext) -> void:
	_conversation = conversation
	_context = context if context != null else ShantyContext.new()
	_effects.clear()
	_choices_taken.clear()
	_index = 0
	_enter_from(0)


## The line being shown, or null once the conversation is over.
func current() -> DialogueLine:
	if _conversation == null or _index < 0 or _index >= _conversation.lines.size():
		return null
	return _conversation.lines[_index]


func is_finished() -> bool:
	return current() == null


## True when the current line is waiting for a reply rather than a press.
func awaits_choice() -> bool:
	var line: DialogueLine = current()
	return line != null and not line.choices.is_empty()


## Moves past a line that asks nothing. Refused on a line owed a reply.
func advance() -> void:
	if is_finished():
		return
	if awaits_choice():
		push_error("ShantyRunner.advance() on a line that is waiting for a choice.")
		return
	_enter_from(_index + 1)


## Takes reply `index` on the current line, collects its effects, and moves to
## its jump target -- or to the next line when it names none. A jump to a label
## the conversation does not have ends the conversation, loudly.
func choose(index: int) -> void:
	var line: DialogueLine = current()
	if line == null or index < 0 or index >= line.choices.size():
		push_error("ShantyRunner.choose(%d) has no such choice on the current line." % index)
		return
	var choice: DialogueChoice = line.choices[index]
	_choices_taken[line.text_key] = index
	if choice == null:
		_enter_from(_index + 1)
		return
	_effects.append_array(choice.effects)
	if choice.jump_label.is_empty():
		_enter_from(_index + 1)
		return
	var target: int = index_of_label(_conversation, choice.jump_label)
	if target < 0:
		push_error("ShantyRunner: no line is labelled '%s'." % choice.jump_label)
		_index = _conversation.lines.size()
		return
	_enter_from(target)


## Walks every remaining line at once, collecting what each owes, and stops on
## the first line that asks for a reply. True when the conversation is over.
func skip_to_end() -> bool:
	while not is_finished() and not awaits_choice():
		_enter_from(_index + 1)
	return is_finished()


func collected_effects() -> Array[ShantyEffect]:
	return _effects.duplicate()


## Line text key -> reply index, for every reply taken so far in this one
## conversation. A host recording several conversations qualifies the key with
## the conversation (PlayedSceneRecord.choice_key()).
func choices_taken() -> Dictionary[String, int]:
	return _choices_taken.duplicate()


func _enter_from(start_index: int) -> void:
	if _conversation == null:
		return
	var lines: Array[DialogueLine] = _conversation.lines
	var index: int = start_index
	while index < lines.size():
		var line: DialogueLine = lines[index]
		if line != null and ShantyCondition.all_hold(line.conditions, _context):
			_index = index
			_effects.append_array(line.effects)
			return
		index += 1
	_index = lines.size()
