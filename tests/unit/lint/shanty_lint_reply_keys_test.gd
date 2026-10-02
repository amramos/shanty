extends GutTest

## A played record names a reply by its key alone, so a reply key may appear
## once across every line of a conversation and across every conversation the
## lint is handed -- not merely once under one asking line.

const CSV: String = (
	"keys,en\n"
	+ "SPEAKER_ANA,Ana\n"
	+ "ONE_01,Ask.\n"
	+ "ONE_02,Ask again.\n"
	+ "TWO_01,Ask elsewhere.\n"
	+ "REPLY_YES,Yes.\n"
	+ "REPLY_NO,No.\n"
)


func _asking(key: String, replies: PackedStringArray) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_id = &"ana"
	line.text_key = key
	var choices: Array[DialogueChoice] = []
	for reply: String in replies:
		var choice := DialogueChoice.new()
		choice.text_key = reply
		choices.append(choice)
	line.choices = choices
	return line


func _conversation(id: StringName, lines: Array[DialogueLine]) -> ConversationDefinition:
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = id
	conversation.lines = lines
	return conversation


func _duplicates(conversations: Array[ConversationDefinition]) -> Array[ShantyLintIssue]:
	var speaker := SpeakerDefinition.new()
	speaker.speaker_id = &"ana"
	speaker.name_key = "SPEAKER_ANA"
	var speakers: Array[SpeakerDefinition] = [speaker]
	var issues: Array[ShantyLintIssue] = ShantyLint.check(
		ShantyCsvDocument.parse(CSV), ShantyProjectConfig.new(), speakers, conversations
	)
	return issues.filter(
		func(issue: ShantyLintIssue) -> bool: return issue.rule == ShantyLint.RULE_DUPLICATE_REPLY
	)


func test_distinct_reply_keys_pass() -> void:
	var one: ConversationDefinition = _conversation(
		&"one", [_asking("ONE_01", ["REPLY_YES"]), _asking("ONE_02", ["REPLY_NO"])]
	)

	assert_eq(_duplicates([one]).size(), 0)


func test_the_same_reply_key_on_two_lines_of_one_conversation_is_an_error() -> void:
	var one: ConversationDefinition = _conversation(
		&"one", [_asking("ONE_01", ["REPLY_YES", "REPLY_NO"]), _asking("ONE_02", ["REPLY_YES"])]
	)
	var found: Array[ShantyLintIssue] = _duplicates([one])

	assert_eq(found.size(), 1)
	assert_eq(found[0].key, "REPLY_YES")
	assert_string_contains(found[0].message, "one line 1", "it names where the key was first")


func test_the_same_reply_key_in_two_conversations_is_an_error() -> void:
	var one: ConversationDefinition = _conversation(&"one", [_asking("ONE_01", ["REPLY_YES"])])
	var two: ConversationDefinition = _conversation(&"two", [_asking("TWO_01", ["REPLY_YES"])])
	var found: Array[ShantyLintIssue] = _duplicates([one, two])

	assert_eq(found.size(), 1)
	assert_eq(found[0].key, "REPLY_YES")
	assert_string_contains(found[0].path, "two line 1")


func test_the_same_reply_twice_under_one_line_is_still_an_error() -> void:
	var one: ConversationDefinition = _conversation(
		&"one", [_asking("ONE_01", ["REPLY_YES", "REPLY_YES"])]
	)

	assert_eq(_duplicates([one]).size(), 1)
