@tool
class_name ShantyLint
extends RefCounted

## Checks a translation CSV and the authored resources that name its keys,
## without touching the editor or the disk: everything it reads is handed in.
## The Shanty tab runs it on demand and before every Save, and a host's own
## tests can run the same checks over its data.
##
## Errors are what would break or mislead at runtime: a key missing or doubled,
## a row wider than the header (the importer ignores the extra cells), a
## flagged word, a loop, a jump to nowhere, an unknown speaker or face, a reply
## that cannot be told apart in a played record, `{name:}` tokens that differ
## between locales. Warnings are what reads worse but works -- a short row
## among them, whose missing cells the importer reads as empty. **Coverage is
## neither** -- an empty cell is a report (`ShantyCsvDocument.coverage()`), and
## whether a gap fails anything is the host's rule.

const RULE_MISSING_KEY: StringName = &"missing_key"
const RULE_EMPTY_KEY: StringName = &"empty_key"
const RULE_DUPLICATE_KEY: StringName = &"duplicate_key"
const RULE_ROW_WIDTH: StringName = &"row_width"
const RULE_FLAG_WORD: StringName = &"flag_word"
const RULE_UNKNOWN_FLAG: StringName = &"unknown_flag"
const RULE_LENGTH: StringName = &"length"
const RULE_CYCLE: StringName = &"cycle"
const RULE_UNKNOWN_LABEL: StringName = &"unknown_label"
const RULE_DUPLICATE_LABEL: StringName = &"duplicate_label"
const RULE_UNKNOWN_SPEAKER: StringName = &"unknown_speaker"
const RULE_UNKNOWN_FACE: StringName = &"unknown_face"
const RULE_DUPLICATE_SPEAKER: StringName = &"duplicate_speaker"
const RULE_DUPLICATE_REPLY: StringName = &"duplicate_reply"
const RULE_TOO_MANY_REPLIES: StringName = &"too_many_replies"
const RULE_TOKEN_MISMATCH: StringName = &"token_mismatch"
const RULE_UNKNOWN_TOKEN: StringName = &"unknown_token"
## Scenes and triggers (`ShantyLintStory`).
const RULE_UNPLAYABLE_SCENE: StringName = &"unplayable_scene"
const RULE_UNKNOWN_TRIGGER: StringName = &"unknown_trigger"
const RULE_DUPLICATE_TRIGGER: StringName = &"duplicate_trigger"
const RULE_EMPTY_TRIGGER: StringName = &"empty_trigger"
const RULE_UNKNOWN_SCENE: StringName = &"unknown_scene"
const RULE_DUPLICATE_CANDIDATE: StringName = &"duplicate_candidate"
const RULE_UNSAFE_TRIGGER_ID: StringName = &"unsafe_trigger_id"
## The runtime shows at most this many replies under a line.
const MAX_REPLIES: int = 3


## Every finding, in a stable order: the file's shape, flags, speakers, tokens,
## then each conversation, scene and trigger, then length.
static func check(
	document: ShantyCsvDocument,
	config: ShantyProjectConfig,
	speakers: Array[SpeakerDefinition],
	conversations: Array[ConversationDefinition],
	scenes: Array[CutsceneDefinition] = [],
	triggers: Array[StoryTriggerDefinition] = []
) -> Array[ShantyLintIssue]:
	var issues: Array[ShantyLintIssue] = []
	ShantyLintText.check_shape(document, issues)
	ShantyLintText.check_flags(document, config, issues)
	var faces: Dictionary[StringName, PackedStringArray] = _check_speakers(
		document, speakers, issues
	)
	var speaker_ids: PackedStringArray = []
	for id: StringName in faces:
		speaker_ids.append(String(id))
	ShantyLintText.check_tokens(document, speaker_ids, issues)
	var spoken: PackedStringArray = []
	# Reply key -> where it was first seen, across every conversation handed in:
	# a played record names a reply by its key alone.
	var replies: Dictionary[String, String] = {}
	for conversation: ConversationDefinition in conversations:
		if conversation != null:
			_check_conversation(document, conversation, faces, issues, spoken, replies)
	for scene: CutsceneDefinition in scenes:
		if scene != null:
			var at: String = location_of(scene, scene.scene_id)
			_require_key(document, scene.title_key, at, issues, true)
			_require_key(document, scene.synopsis_key, at, issues, true)
	ShantyLintStory.check_scenes(scenes, issues)
	ShantyLintStory.check_triggers(config, scenes, triggers, issues)
	var cap: int = config.length_cap if config != null else 0
	ShantyLintText.check_length(document, spoken, cap, issues)
	return issues


static func has_errors(issues: Array[ShantyLintIssue]) -> bool:
	return not errors_in(issues).is_empty()


static func errors_in(issues: Array[ShantyLintIssue]) -> Array[ShantyLintIssue]:
	return issues.filter(func(issue: ShantyLintIssue) -> bool: return issue.is_error())


## The findings about `key`, for marking its cells.
static func for_key(issues: Array[ShantyLintIssue], key: String) -> Array[ShantyLintIssue]:
	return issues.filter(func(issue: ShantyLintIssue) -> bool: return issue.key == key)


## Speaker id -> its face tags, for the line checks.
static func _check_speakers(
	document: ShantyCsvDocument, speakers: Array[SpeakerDefinition], issues: Array[ShantyLintIssue]
) -> Dictionary[StringName, PackedStringArray]:
	var faces: Dictionary[StringName, PackedStringArray] = {}
	for speaker: SpeakerDefinition in speakers:
		if speaker == null:
			continue
		var where: String = location_of(speaker, speaker.speaker_id)
		if speaker.speaker_id.is_empty():
			issues.append(
				ShantyLintIssue.error(RULE_UNKNOWN_SPEAKER, "the speaker has no id", "", where)
			)
			continue
		if faces.has(speaker.speaker_id):
			issues.append(
				ShantyLintIssue.error(
					RULE_DUPLICATE_SPEAKER,
					"another speaker already has the id '%s'" % speaker.speaker_id,
					"",
					where
				)
			)
		_require_key(document, speaker.name_key, where, issues)
		var tags: PackedStringArray = []
		for face: SpeakerFace in speaker.faces:
			if face != null:
				tags.append(String(face.tag))
		faces[speaker.speaker_id] = tags
	return faces


static func _check_conversation(
	document: ShantyCsvDocument,
	conversation: ConversationDefinition,
	faces: Dictionary[StringName, PackedStringArray],
	issues: Array[ShantyLintIssue],
	spoken: PackedStringArray,
	replies: Dictionary[String, String]
) -> void:
	var where: String = location_of(conversation, conversation.conversation_id)
	if ShantyRunner.has_cycle(conversation):
		issues.append(
			ShantyLintIssue.error(
				RULE_CYCLE, "a reply or a gated line leads back to an earlier line", "", where
			)
		)
	var labels: PackedStringArray = []
	var asking_keys: PackedStringArray = []
	for index: int in conversation.lines.size():
		var line: DialogueLine = conversation.lines[index]
		if line == null:
			continue
		var at: String = "%s line %d" % [where, index + 1]
		if not line.label.is_empty():
			if labels.has(String(line.label)):
				issues.append(
					ShantyLintIssue.error(
						RULE_DUPLICATE_LABEL, "the label '%s' is used twice" % line.label, "", at
					)
				)
			labels.append(String(line.label))
		_require_key(document, line.text_key, at, issues)
		spoken.append(line.text_key)
		_check_speaker_use(line, faces, at, issues)
		if line.choices.is_empty():
			continue
		if asking_keys.has(line.text_key):
			issues.append(
				ShantyLintIssue.error(
					RULE_DUPLICATE_REPLY,
					"two asking lines share this key; a record cannot tell them apart",
					line.text_key,
					at
				)
			)
		asking_keys.append(line.text_key)
		_check_choices(document, conversation, line, at, issues, spoken, replies)


static func _check_speaker_use(
	line: DialogueLine,
	faces: Dictionary[StringName, PackedStringArray],
	at: String,
	issues: Array[ShantyLintIssue]
) -> void:
	if not faces.has(line.speaker_id):
		issues.append(
			ShantyLintIssue.error(
				RULE_UNKNOWN_SPEAKER,
				"no speaker has the id '%s'" % line.speaker_id,
				line.text_key,
				at
			)
		)
	elif not line.face.is_empty() and not faces[line.speaker_id].has(String(line.face)):
		issues.append(
			ShantyLintIssue.error(
				RULE_UNKNOWN_FACE,
				"'%s' has no face '%s'" % [line.speaker_id, line.face],
				line.text_key,
				at
			)
		)
	if not line.reply_speaker_id.is_empty() and not faces.has(line.reply_speaker_id):
		issues.append(
			ShantyLintIssue.error(
				RULE_UNKNOWN_SPEAKER,
				"no speaker has the reply speaker id '%s'" % line.reply_speaker_id,
				line.text_key,
				at
			)
		)


static func _check_choices(
	document: ShantyCsvDocument,
	conversation: ConversationDefinition,
	line: DialogueLine,
	at: String,
	issues: Array[ShantyLintIssue],
	spoken: PackedStringArray,
	replies: Dictionary[String, String]
) -> void:
	if line.choices.size() > MAX_REPLIES:
		issues.append(
			ShantyLintIssue.error(
				RULE_TOO_MANY_REPLIES,
				"%d replies; at most %d are shown" % [line.choices.size(), MAX_REPLIES],
				line.text_key,
				at
			)
		)
	for choice: DialogueChoice in line.choices:
		if choice == null:
			continue
		_require_key(document, choice.text_key, at, issues)
		spoken.append(choice.text_key)
		if replies.has(choice.text_key):
			issues.append(
				ShantyLintIssue.error(
					RULE_DUPLICATE_REPLY,
					"another reply already has this key (%s)" % replies[choice.text_key],
					choice.text_key,
					at
				)
			)
		elif not choice.text_key.is_empty():
			replies[choice.text_key] = at
		if ShantyRunner.index_of_label(conversation, choice.jump_label) < 0:
			if not choice.jump_label.is_empty():
				issues.append(
					ShantyLintIssue.error(
						RULE_UNKNOWN_LABEL,
						"the reply jumps to '%s', which no line carries" % choice.jump_label,
						choice.text_key,
						at
					)
				)


## An empty key is an error unless `optional`; a key the CSV lacks always is.
static func _require_key(
	document: ShantyCsvDocument,
	key: String,
	where: String,
	issues: Array[ShantyLintIssue],
	optional: bool = false
) -> void:
	if key.is_empty():
		if not optional:
			issues.append(ShantyLintIssue.error(RULE_EMPTY_KEY, "no translation key", "", where))
	elif not document.has_key(key):
		issues.append(
			ShantyLintIssue.error(RULE_MISSING_KEY, "the CSV has no row for this key", key, where)
		)


## A resource's file when it has one, else its id.
static func location_of(resource: Resource, id: StringName) -> String:
	return resource.resource_path if not resource.resource_path.is_empty() else String(id)
