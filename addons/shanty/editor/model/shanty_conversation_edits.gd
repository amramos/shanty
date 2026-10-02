@tool
class_name ShantyConversationEdits
extends RefCounted

## Edits to conversations, over a `ShantyEditorModel`. Every new line and reply
## gets a key from the scheme and a CSV row in one contiguous block after the
## conversation's last row, so two writers adding to different conversations
## touch different parts of the file. **A key is never renumbered**: a line
## inserted mid-conversation takes the next free number.

const ID_PATTERN: String = "^[a-z0-9_]+$"


## A new conversation saved as `<conversations folder>/<id>.tres`, its keys
## under `prefix` (the scheme's default when empty). Null, changing nothing,
## for a bad or taken id or an existing file.
static func add_conversation(
	model: ShantyEditorModel, id: String, prefix: String = ""
) -> ConversationDefinition:
	var folder: String = model.config.conversations_folder
	var path: String = folder.path_join(id + ".tres")
	if RegEx.create_from_string(ID_PATTERN).search(id) == null or folder.is_empty():
		return null
	if find(model, StringName(id)) != null or ShantyFiles.exists(path):
		return null
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = StringName(id)
	model.key_prefixes[conversation] = (
		prefix if not prefix.is_empty() else model.config.scheme().prefix_for(id)
	)
	model.conversations.append(conversation)
	model.adopt(conversation, path)
	return conversation


static func find(model: ShantyEditorModel, id: StringName) -> ConversationDefinition:
	for conversation: ConversationDefinition in model.conversations:
		if conversation.conversation_id == id:
			return conversation
	return null


## The prefix new lines are keyed under: the writer's, else the one the
## conversation's own keys share, else the scheme's default for its id.
static func prefix_of(model: ShantyEditorModel, conversation: ConversationDefinition) -> String:
	if model.key_prefixes.has(conversation):
		return model.key_prefixes[conversation]
	var inferred: String = model.config.scheme().infer_prefix(keys_of(conversation))
	if not inferred.is_empty():
		return inferred
	return model.config.scheme().prefix_for(String(conversation.conversation_id))


static func set_prefix(
	model: ShantyEditorModel, conversation: ConversationDefinition, prefix: String
) -> void:
	model.key_prefixes[conversation] = prefix
	model.changed.emit()


## Every key the conversation names: each line's, then its replies'.
static func keys_of(conversation: ConversationDefinition) -> PackedStringArray:
	var keys: PackedStringArray = []
	for line: DialogueLine in conversation.lines:
		if line == null:
			continue
		keys.append(line.text_key)
		for choice: DialogueChoice in line.choices:
			if choice != null:
				keys.append(choice.text_key)
	return keys


## A new line after line `after` (at the end when -1), keyed by the next free
## number, with its row added to the conversation's block.
static func add_line(
	model: ShantyEditorModel,
	conversation: ConversationDefinition,
	speaker_id: StringName,
	face: StringName,
	after: int = -1
) -> DialogueLine:
	var prefix: String = prefix_of(model, conversation)
	var taken: PackedStringArray = model.document.keys()
	taken.append_array(keys_of(conversation))
	var line := DialogueLine.new()
	line.speaker_id = speaker_id
	line.face = face
	line.text_key = model.config.scheme().next_line_key(prefix, taken)
	if not model.add_row(line.text_key, model.document.last_of(keys_of(conversation))):
		return null
	var lines: Array[DialogueLine] = conversation.lines
	var at: int = after + 1 if after >= 0 and after < lines.size() else lines.size()
	lines.insert(at, line)
	conversation.lines = lines
	model.touch(conversation)
	return line


## Removes line `index`, and the rows of its keys that nothing else names.
static func remove_line(
	model: ShantyEditorModel, conversation: ConversationDefinition, index: int
) -> bool:
	if index < 0 or index >= conversation.lines.size():
		return false
	var line: DialogueLine = conversation.lines[index]
	var lines: Array[DialogueLine] = conversation.lines
	lines.remove_at(index)
	conversation.lines = lines
	if line != null:
		var keys: PackedStringArray = [line.text_key]
		for choice: DialogueChoice in line.choices:
			if choice != null:
				keys.append(choice.text_key)
		_drop_unused_rows(model, keys)
	model.touch(conversation)
	return true


## A new reply under `line`, keyed by the first free letter. Null once the
## line has three.
static func add_choice(
	model: ShantyEditorModel, conversation: ConversationDefinition, line: DialogueLine
) -> DialogueChoice:
	if line.choices.size() >= ShantyLint.MAX_REPLIES:
		return null
	var key: String = model.config.scheme().next_reply_key(line.text_key, model.document.keys())
	if key.is_empty() or not model.add_row(key, model.document.last_of(keys_of(conversation))):
		return null
	var choice := DialogueChoice.new()
	choice.text_key = key
	var choices: Array[DialogueChoice] = line.choices
	choices.append(choice)
	line.choices = choices
	model.touch(conversation)
	return choice


static func remove_choice(
	model: ShantyEditorModel, conversation: ConversationDefinition, line: DialogueLine, index: int
) -> bool:
	if index < 0 or index >= line.choices.size():
		return false
	var choice: DialogueChoice = line.choices[index]
	var choices: Array[DialogueChoice] = line.choices
	choices.remove_at(index)
	line.choices = choices
	if choice != null:
		_drop_unused_rows(model, [choice.text_key])
	model.touch(conversation)
	return true


## Sets one property of a line or reply inside `conversation` and marks it edited.
static func edit(
	model: ShantyEditorModel,
	conversation: ConversationDefinition,
	target: Resource,
	property: StringName,
	value: Variant
) -> void:
	target.set(property, value)
	model.touch(conversation)


## A new condition of the script at `script_path` on `line`; null when that
## script does not extend ShantyCondition.
static func add_condition(
	model: ShantyEditorModel,
	conversation: ConversationDefinition,
	line: DialogueLine,
	script_path: String
) -> ShantyCondition:
	var condition: ShantyCondition = ShantyFiles.instantiate(script_path) as ShantyCondition
	if condition == null:
		return null
	var conditions: Array[ShantyCondition] = line.conditions
	conditions.append(condition)
	line.conditions = conditions
	model.touch(conversation)
	return condition


## A new effect on a line or a reply (`holder`); null when the script does not
## extend ShantyEffect or `holder` holds no effects.
static func add_effect(
	model: ShantyEditorModel,
	conversation: ConversationDefinition,
	holder: Resource,
	script_path: String
) -> ShantyEffect:
	if not (holder is DialogueLine or holder is DialogueChoice):
		return null
	var effect: ShantyEffect = ShantyFiles.instantiate(script_path) as ShantyEffect
	if effect == null:
		return null
	var effects: Array[ShantyEffect] = holder.get(&"effects")
	effects.append(effect)
	holder.set(&"effects", effects)
	model.touch(conversation)
	return effect


## Removes entry `index` of the array `property` (`conditions` or `effects`) on
## `holder`.
static func remove_entry(
	model: ShantyEditorModel,
	conversation: ConversationDefinition,
	holder: Resource,
	property: StringName,
	index: int
) -> bool:
	var entries: Array = holder.get(property)
	if index < 0 or index >= entries.size():
		return false
	entries.remove_at(index)
	holder.set(property, entries)
	model.touch(conversation)
	return true


static func _drop_unused_rows(model: ShantyEditorModel, keys: PackedStringArray) -> void:
	var still_named: PackedStringArray = []
	for conversation: ConversationDefinition in model.conversations:
		still_named.append_array(keys_of(conversation))
	for speaker: SpeakerDefinition in model.speakers:
		still_named.append(speaker.name_key)
	for key: String in keys:
		if not key.is_empty() and not still_named.has(key):
			model.remove_row(key)
