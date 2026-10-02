extends GutTest

## The example is the Shanty tab's demo: the project setting names its config,
## which opens the lighthouse conversation with three locales -- `fr` partial,
## so the coverage strip has a gap to show -- and lints without an error.

const CONFIG_PATH: String = "res://addons/shanty/example/shanty_config.tres"


func _model() -> ShantyEditorModel:
	var model := ShantyEditorModel.new()
	model.open(ShantyFiles.configured())
	return model


func test_the_project_setting_names_the_example_config() -> void:
	assert_eq(String(ProjectSettings.get_setting(ShantyProjectConfig.SETTING, "")), CONFIG_PATH)
	assert_not_null(ShantyFiles.configured())


func test_the_example_config_carries_its_flag_and_scheme() -> void:
	var config: ShantyProjectConfig = ShantyFiles.configured()

	assert_eq(config.flag_names(), PackedStringArray(["NEUTRAL"]))
	assert_eq(
		config.rule_for("NEUTRAL").words_for("en"),
		PackedStringArray(["he", "she", "him", "her", "his", "hers"])
	)
	assert_eq(config.rule_for("NEUTRAL").words_for("fr"), PackedStringArray(), "no list, no rule")
	assert_eq(config.scheme().speaker_key("cook"), "SHANTY_EXAMPLE_SPEAKER_COOK")


func test_the_example_opens_with_three_locales_and_a_partial_one() -> void:
	var model: ShantyEditorModel = _model()

	assert_eq(model.locales(), PackedStringArray(["en", "pt_BR", "fr"]))
	assert_eq(model.source_locale, "en")
	assert_eq(model.speakers.size(), 2)
	assert_eq(model.conversations.size(), 1)
	assert_eq(model.scenes.size(), 1)
	var summaries: PackedStringArray = []
	for report: ShantyLocaleCoverage in model.coverage():
		summaries.append(report.summary())
	assert_eq(summaries, PackedStringArray(["en 14/14", "pt_BR 14/14", "fr 10/14"]))


func test_the_example_lints_without_an_error() -> void:
	var issues: Array[ShantyLintIssue] = _model().lint()

	assert_eq(ShantyLint.errors_in(issues), [] as Array[ShantyLintIssue])


func test_the_example_flags_a_line_neutral() -> void:
	var model: ShantyEditorModel = _model()

	assert_eq(model.flags("SHANTY_EXAMPLE_LINE_2"), PackedStringArray(["NEUTRAL"]))
	model.set_text("SHANTY_EXAMPLE_LINE_2", "en", "I said she would.")
	assert_true(ShantyLint.has_errors(model.lint()), "the flag's word list holds")


func test_a_new_line_in_the_example_follows_its_own_numbering() -> void:
	var model: ShantyEditorModel = _model()
	var conversation: ConversationDefinition = model.conversations[0]

	assert_eq(ShantyConversationEdits.prefix_of(model, conversation), "SHANTY_EXAMPLE_LINE")
	var line: DialogueLine = ShantyConversationEdits.add_line(
		model, conversation, &"keeper", &"neutral"
	)
	assert_eq(line.text_key, "SHANTY_EXAMPLE_LINE_4")
	# Never saved: the edit is dropped with the model, and the cached resource put back.
	ShantyConversationEdits.remove_line(model, conversation, 3)


func test_the_example_scheme_names_its_own_reply_keys() -> void:
	var model: ShantyEditorModel = _model()
	var conversation: ConversationDefinition = model.conversations[0]
	var asking: DialogueLine = conversation.lines[2]
	var existing: PackedStringArray = []
	for choice: DialogueChoice in asking.choices:
		existing.append(choice.text_key)
	var scheme: ShantyKeyScheme = model.config.scheme()

	assert_eq(
		existing,
		PackedStringArray(
			[
				scheme.reply_key.replace("{LINE}", asking.text_key).replace("{LETTER}", "A"),
				scheme.reply_key.replace("{LINE}", asking.text_key).replace("{LETTER}", "B"),
			]
		),
		"the example's replies are keyed by its own scheme"
	)
	var reply: DialogueChoice = ShantyConversationEdits.add_choice(model, conversation, asking)
	assert_eq(reply.text_key, "SHANTY_EXAMPLE_LINE_3_C")
	var first: DialogueChoice = ShantyConversationEdits.add_choice(
		model, conversation, conversation.lines[1]
	)
	assert_eq(first.text_key, "SHANTY_EXAMPLE_LINE_2_A")
	# Never saved: the cached resource is put back as it was.
	ShantyConversationEdits.remove_choice(model, conversation, asking, 2)
	ShantyConversationEdits.remove_choice(model, conversation, conversation.lines[1], 0)
	assert_eq(asking.choices.size(), 2)
	assert_eq(conversation.lines[1].choices.size(), 0)
