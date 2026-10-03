extends GutTest

## ShantyKeyScheme names new keys from configurable patterns and never
## renumbers one: a new line takes the next number after the highest in use.


func test_the_defaults_name_lines_replies_speakers_and_scenes() -> void:
	var scheme := ShantyKeyScheme.new()

	assert_eq(scheme.prefix_for("old_lamp"), "DLG_OLD_LAMP")
	assert_eq(scheme.line_key_for("DLG_OPENING", 3), "DLG_OPENING_03")
	assert_eq(scheme.next_reply_key("DLG_OPENING_03", []), "DLG_OPENING_03A")
	assert_eq(scheme.speaker_key("keeper"), "SPEAKER_KEEPER")
	assert_eq(scheme.title_key("lamp"), "SCENE_TITLE_LAMP")
	assert_eq(scheme.synopsis_key("lamp"), "SCENE_SYNOPSIS_LAMP")


func test_an_id_becomes_a_key_fragment() -> void:
	assert_eq(ShantyKeyScheme.id_token("the-lamp 2"), "THE_LAMP_2")


func test_the_next_line_takes_the_number_after_the_highest_in_use() -> void:
	var scheme := ShantyKeyScheme.new()
	var taken: PackedStringArray = ["DLG_A_01", "DLG_A_07", "DLG_A_03", "DLG_AB_40", "DLG_A_07A"]

	assert_eq(scheme.next_line_key("DLG_A", taken), "DLG_A_08", "a gap is never filled")
	assert_eq(scheme.next_line_key("DLG_NEW", taken), "DLG_NEW_01")


func test_numbers_past_the_padding_still_count() -> void:
	var scheme := ShantyKeyScheme.new()

	assert_eq(scheme.next_line_key("P", ["P_99"]), "P_100")
	assert_eq(scheme.number_of("P", "P_100"), 100)
	assert_eq(scheme.number_of("P", "Q_100"), -1)


func test_reply_letters_run_out_after_three() -> void:
	var scheme := ShantyKeyScheme.new()
	var taken: PackedStringArray = ["L_01A", "L_01C"]

	assert_eq(scheme.next_reply_key("L_01", taken), "L_01B")
	taken.append("L_01B")
	assert_eq(scheme.next_reply_key("L_01", taken), "")


func test_patterns_are_configurable() -> void:
	var scheme := ShantyKeyScheme.new()
	scheme.conversation_prefix = "TALK.{ID}"
	scheme.line_key = "{PREFIX}#{NN}"
	scheme.reply_key = "{LINE}_R{LETTER}"
	scheme.number_digits = 3

	assert_eq(scheme.prefix_for("x"), "TALK.X")
	assert_eq(scheme.next_line_key("TALK.X", ["TALK.X#004", "TALKAX#900"]), "TALK.X#005")
	assert_eq(scheme.next_reply_key("TALK.X#005", []), "TALK.X#005_RA")
	assert_eq(scheme.infer_prefix(["TALK.X#001", "TALK.X#002", "OTHER"]), "TALK.X")


func test_the_prefix_is_inferred_from_existing_keys() -> void:
	var scheme := ShantyKeyScheme.new()

	assert_eq(
		scheme.infer_prefix(["EXAMPLE_LINE_1", "EXAMPLE_LINE_2", "EXAMPLE_REPLY_A"]), "EXAMPLE_LINE"
	)
	assert_eq(scheme.infer_prefix(["NOTHING", "NUMBERED"]), "")


func test_a_pattern_missing_a_placeholder_is_invalid() -> void:
	var scheme := ShantyKeyScheme.new()
	assert_true(scheme.is_valid())
	scheme.line_key = "{PREFIX}_LINE"

	assert_false(scheme.is_valid())
	assert_eq(scheme.number_of("P", "P_LINE"), -1)
