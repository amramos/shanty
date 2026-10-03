extends GutTest

## ShantyLint, one rule at a time, over a small clean fixture that each test
## breaks in exactly one way. Errors block the tab's Save; warnings and coverage
## never do.

const CSV: String = (
	"keys,en,pt_BR,de,_notes,_flags\n"
	+ "SPEAKER_ANA,Ana,Ana,,,\n"
	+ "SPEAKER_BO,Bo,Bo,,,\n"
	+ "TALK_01,Hello.,Olá.,,,\n"
	+ "TALK_02,Ask {name:ana}.,Pergunte a {name:ana}.,,,NEUTRAL\n"
	+ "TALK_02A,Yes.,Sim.,,,\n"
	+ "TALK_02B,No.,Não.,,,\n"
)


func _config() -> ShantyProjectConfig:
	var config := ShantyProjectConfig.new()
	var rule := ShantyFlagRule.new()
	rule.flag = "NEUTRAL"
	rule.forbidden_words = {"en": PackedStringArray(["he", "she"]), "de": PackedStringArray(["er"])}
	config.flags = [rule]
	return config


func _speaker(id: StringName, key: String, tags: Array[StringName]) -> SpeakerDefinition:
	var speaker := SpeakerDefinition.new()
	speaker.speaker_id = id
	speaker.name_key = key
	for tag: StringName in tags:
		var face := SpeakerFace.new()
		face.tag = tag
		speaker.faces.append(face)
	return speaker


func _speakers() -> Array[SpeakerDefinition]:
	return [
		_speaker(&"ana", "SPEAKER_ANA", [&"neutral", &"wary"]),
		_speaker(&"bo", "SPEAKER_BO", [&"neutral"]),
	]


func _line(speaker: StringName, key: String) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_id = speaker
	line.face = &"neutral"
	line.text_key = key
	return line


func _choice(key: String, jump: StringName = &"") -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.text_key = key
	choice.jump_label = jump
	return choice


func _conversation() -> ConversationDefinition:
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = &"talk"
	var asking: DialogueLine = _line(&"bo", "TALK_02")
	asking.choices = [_choice("TALK_02A"), _choice("TALK_02B")]
	conversation.lines = [_line(&"ana", "TALK_01"), asking]
	return conversation


func _check(
	csv: String = CSV,
	conversation: ConversationDefinition = null,
	config: ShantyProjectConfig = null
) -> Array[ShantyLintIssue]:
	var used: ConversationDefinition = conversation if conversation != null else _conversation()
	var conversations: Array[ConversationDefinition] = [used]
	return ShantyLint.check(
		ShantyCsvDocument.parse(csv),
		config if config != null else _config(),
		_speakers(),
		conversations
	)


func _rules(issues: Array[ShantyLintIssue]) -> PackedStringArray:
	var names: PackedStringArray = []
	for issue: ShantyLintIssue in issues:
		names.append("%s:%s" % ["error" if issue.is_error() else "warning", issue.rule])
	return names


func test_the_clean_fixture_has_no_findings_although_a_locale_is_empty() -> void:
	var issues: Array[ShantyLintIssue] = _check()

	assert_eq(
		_rules(issues), PackedStringArray(), "the empty `de` column is coverage, not a finding"
	)


func test_a_missing_key_is_an_error() -> void:
	var issues: Array[ShantyLintIssue] = _check(CSV.replace("TALK_01,Hello.,Olá.,,,\n", ""))

	assert_eq(_rules(issues), PackedStringArray(["error:missing_key"]))
	assert_eq(issues[0].key, "TALK_01")
	assert_eq(issues[0].path, "talk line 1")


func test_an_empty_key_is_an_error() -> void:
	var conversation: ConversationDefinition = _conversation()
	conversation.lines[0].text_key = ""

	assert_eq(_rules(_check(CSV, conversation)), PackedStringArray(["error:empty_key"]))


func test_a_doubled_key_is_an_error_and_a_short_row_only_a_warning() -> void:
	var csv: String = CSV + "TALK_01,Again,,,,\nSHORT,x\n"
	var issues: Array[ShantyLintIssue] = _check(csv)

	assert_eq(_rules(issues), PackedStringArray(["error:duplicate_key", "warning:row_width"]))
	assert_eq(issues[1].key, "SHORT")
	assert_eq(issues[1].message, "2 cells, header has 6; missing cells read as empty")


func test_a_row_wider_than_the_header_is_an_error() -> void:
	var issues: Array[ShantyLintIssue] = _check(CSV + "WIDE,Hi, there.,Oi.,,,\n")

	assert_eq(_rules(issues), PackedStringArray(["error:row_width"]))
	assert_eq(issues[0].key, "WIDE")
	assert_string_contains(issues[0].message, "7 cells, header has 6")


## Godot's CSV translation importer (verified by a host on 4.7.1; GUT cannot
## run the importer) takes a four-column header with rows of two, three and five
## cells without an error: a short row's missing cells import as empty, and a
## five-cell row's locale cells translate normally while its fifth cell is
## dropped without a word. So a short row is a warning that never blocks Save,
## and only a row wider than the header -- whose extra cells vanish, usually
## after an unescaped comma -- is an error.
func test_row_width_severities_follow_what_the_importer_does() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse(
		"keys,en,pt_BR,fr\nTWO,a\nTHREE,a,b\nFIVE,a,b,c,extra\n"
	)
	var no_speakers: Array[SpeakerDefinition] = []
	var no_conversations: Array[ConversationDefinition] = []
	var issues: Array[ShantyLintIssue] = ShantyLint.check(
		document, null, no_speakers, no_conversations
	)

	assert_eq(
		_rules(issues),
		PackedStringArray(["warning:row_width", "warning:row_width", "error:row_width"])
	)
	assert_eq(issues[0].key, "TWO")
	assert_eq(issues[1].key, "THREE")
	assert_eq(ShantyLint.errors_in(issues)[0].key, "FIVE")
	assert_eq(document.text("FIVE", "fr"), "c", "a long row's locale cells still read")
	assert_eq(document.text("TWO", "fr"), "", "a short row's missing cells read as empty")


func test_a_flagged_row_may_not_hold_a_forbidden_whole_word() -> void:
	var csv: String = CSV.replace("Ask {name:ana}.", "Ask {name:ana} then ask SHE.")
	var issues: Array[ShantyLintIssue] = _check(csv)

	assert_eq(_rules(issues), PackedStringArray(["error:flag_word"]))
	assert_eq(issues[0].locale, "en")
	assert_string_contains(issues[0].message, "she")


func test_the_flag_rule_reads_whole_words_only() -> void:
	var words: PackedStringArray = ["he", "er"]

	assert_eq(ShantyLintText.forbidden_words_in("The hero, there.", words), PackedStringArray())
	assert_eq(ShantyLintText.forbidden_words_in("Then he left.", words), PackedStringArray(["he"]))
	assert_eq(
		ShantyLintText.forbidden_words_in("[hl]He[/hl] did.", words), PackedStringArray(["he"])
	)
	assert_eq(ShantyLintText.forbidden_words_in("Ask {name:he}.", words), PackedStringArray())
	assert_eq(ShantyLintText.forbidden_words_in("Ér er.", words), PackedStringArray(["er"]))
	assert_eq(ShantyLintText.forbidden_words_in("Éher", words), PackedStringArray())


func test_a_locale_with_no_list_has_no_rule() -> void:
	var csv: String = CSV.replace("Pergunte a {name:ana}.", "Pergunte a ele {name:ana}.")

	assert_eq(_rules(_check(csv)), PackedStringArray())
	var german: String = CSV.replace(
		"TALK_02,Ask {name:ana}.,Pergunte a {name:ana}.,",
		"TALK_02,Ask {name:ana}.,Pergunte a {name:ana}.,Er {name:ana}"
	)
	assert_eq(_rules(_check(german)), PackedStringArray(["error:flag_word"]))


func test_an_unflagged_row_is_never_checked_for_words() -> void:
	var csv: String = CSV.replace("Hello.", "He said hello.")

	assert_eq(_rules(_check(csv)), PackedStringArray())


func test_a_flag_the_config_does_not_name_is_a_warning() -> void:
	var csv: String = CSV.replace("Hello.,Olá.,,,", "Hello.,Olá.,,,LOUD")

	assert_eq(_rules(_check(csv)), PackedStringArray(["warning:unknown_flag"]))


func test_name_tokens_must_match_across_filled_locales() -> void:
	var csv: String = CSV.replace("Pergunte a {name:ana}.", "Pergunte a {name:bo}.")
	var issues: Array[ShantyLintIssue] = _check(csv)

	assert_eq(_rules(issues), PackedStringArray(["error:token_mismatch"]))
	assert_eq(issues[0].locale, "pt_BR")


func test_a_token_naming_no_speaker_is_a_warning() -> void:
	var csv: String = CSV.replace("{name:ana}", "{name:cy}")

	assert_eq(_rules(_check(csv)), PackedStringArray(["warning:unknown_token"]))


func test_an_over_length_line_is_a_warning() -> void:
	var config: ShantyProjectConfig = _config()
	config.length_cap = 5
	var issues: Array[ShantyLintIssue] = _check(CSV, null, config)

	assert_false(ShantyLint.has_errors(issues))
	assert_gt(issues.size(), 0)
	for issue: ShantyLintIssue in issues:
		assert_eq(issue.rule, ShantyLint.RULE_LENGTH)


func test_a_loop_is_an_error() -> void:
	var conversation: ConversationDefinition = _conversation()
	conversation.lines[0].label = &"top"
	conversation.lines[1].choices[0].jump_label = &"top"

	assert_eq(_rules(_check(CSV, conversation)), PackedStringArray(["error:cycle"]))


func test_a_jump_to_a_label_no_line_carries_is_an_error() -> void:
	var conversation: ConversationDefinition = _conversation()
	conversation.lines[1].choices[1].jump_label = &"nowhere"

	assert_eq(_rules(_check(CSV, conversation)), PackedStringArray(["error:unknown_label"]))


func test_a_label_used_twice_is_an_error() -> void:
	var conversation: ConversationDefinition = _conversation()
	conversation.lines[0].label = &"same"
	conversation.lines[1].label = &"same"

	assert_eq(_rules(_check(CSV, conversation)), PackedStringArray(["error:duplicate_label"]))


func test_unknown_speakers_and_faces_are_errors() -> void:
	var conversation: ConversationDefinition = _conversation()
	conversation.lines[0].face = &"furious"
	conversation.lines[1].speaker_id = &"cy"
	conversation.lines[1].reply_speaker_id = &"dee"

	assert_eq(
		_rules(_check(CSV, conversation)),
		PackedStringArray(["error:unknown_face", "error:unknown_speaker", "error:unknown_speaker"])
	)


func test_replies_and_asking_lines_must_be_told_apart() -> void:
	var conversation: ConversationDefinition = _conversation()
	conversation.lines[1].choices[1].text_key = "TALK_02A"
	var again: DialogueLine = _line(&"ana", "TALK_02")
	again.choices = [_choice("TALK_02B")]
	conversation.lines.append(again)

	assert_eq(
		_rules(_check(CSV, conversation)),
		PackedStringArray(["error:duplicate_reply", "error:duplicate_reply"])
	)


func test_more_than_three_replies_is_an_error() -> void:
	var conversation: ConversationDefinition = _conversation()
	for key: String in ["TALK_02A", "TALK_02B"]:
		conversation.lines[1].choices.append(_choice(key))

	assert_true(_rules(_check(CSV, conversation)).has("error:too_many_replies"))


func test_speakers_need_an_id_and_a_name_key_and_ids_are_unique() -> void:
	var speakers: Array[SpeakerDefinition] = _speakers()
	speakers.append(_speaker(&"ana", "SPEAKER_ANA", [&"neutral"]))
	speakers.append(_speaker(&"cy", "SPEAKER_CY", []))
	speakers.append(_speaker(&"", "", []))
	var conversations: Array[ConversationDefinition] = [_conversation()]
	var issues: Array[ShantyLintIssue] = ShantyLint.check(
		ShantyCsvDocument.parse(CSV), _config(), speakers, conversations
	)

	assert_eq(
		_rules(issues),
		PackedStringArray(["error:duplicate_speaker", "error:missing_key", "error:unknown_speaker"])
	)


func test_a_scene_names_existing_keys_or_none() -> void:
	var scene := CutsceneDefinition.new()
	scene.scene_id = &"s"
	scene.title_key = "SCENE_TITLE_S"
	var scenes: Array[CutsceneDefinition] = [scene]
	var conversations: Array[ConversationDefinition] = [_conversation()]
	var issues: Array[ShantyLintIssue] = ShantyLint.check(
		ShantyCsvDocument.parse(CSV), _config(), _speakers(), conversations, scenes
	)

	assert_eq(_rules(issues), PackedStringArray(["error:missing_key"]))
	assert_eq(issues[0].key, "SCENE_TITLE_S")


func test_issues_are_filtered_by_key_and_described_in_one_line() -> void:
	var issues: Array[ShantyLintIssue] = _check(CSV.replace("TALK_01,Hello.,Olá.,,,\n", ""))

	assert_eq(ShantyLint.for_key(issues, "TALK_01").size(), 1)
	assert_eq(ShantyLint.for_key(issues, "TALK_02").size(), 0)
	assert_eq(
		issues[0].describe(),
		"error  missing_key  talk line 1 TALK_01: the CSV has no row for this key"
	)
