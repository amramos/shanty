extends GutTest

## The edits the Shanty tab makes, over the model, without saving: keys named
## by the scheme and never renumbered, rows kept in one block per
## conversation, replies capped at three, speakers and faces, and the pickers'
## conditions and effects.

const Fixture := preload("res://tests/support/editor_fixture.gd")

var _model: ShantyEditorModel
var _talk: ConversationDefinition


func before_each() -> void:
	_model = Fixture.open_model()
	_talk = _model.conversations[0]


func after_each() -> void:
	_model = null
	_talk = null


func after_all() -> void:
	Fixture.remove()


func test_the_prefix_is_inferred_from_the_conversations_own_keys() -> void:
	assert_eq(ShantyConversationEdits.prefix_of(_model, _talk), "DLG_TALK")


func test_new_lines_take_the_next_free_number_in_one_contiguous_block() -> void:
	ShantyConversationEdits.add_line(_model, _talk, &"ana", &"neutral")
	ShantyConversationEdits.add_line(_model, _talk, &"ana", &"neutral")

	assert_eq(
		_model.document.keys(),
		PackedStringArray(
			[
				"SPEAKER_ANA",
				"UNRELATED",
				"DLG_TALK_01",
				"DLG_TALK_02",
				"DLG_TALK_03",
				"DLG_TALK_04",
				"TAIL"
			]
		)
	)


func test_an_inserted_line_never_renumbers_another() -> void:
	var inserted: DialogueLine = ShantyConversationEdits.add_line(
		_model, _talk, &"ana", &"neutral", 0
	)

	assert_eq(inserted.text_key, "DLG_TALK_03")
	assert_eq(
		ShantyConversationEdits.keys_of(_talk),
		PackedStringArray(["DLG_TALK_01", "DLG_TALK_03", "DLG_TALK_02"])
	)


func test_replies_take_letters_after_their_line_and_stop_at_three() -> void:
	var line: DialogueLine = _talk.lines[1]
	var keys: PackedStringArray = []
	for attempt: int in 3:
		keys.append(ShantyConversationEdits.add_choice(_model, _talk, line).text_key)

	assert_eq(keys, PackedStringArray(["DLG_TALK_02A", "DLG_TALK_02B", "DLG_TALK_02C"]))
	assert_null(ShantyConversationEdits.add_choice(_model, _talk, line))
	assert_eq(
		_model.document.keys().slice(3, 8),
		PackedStringArray(["DLG_TALK_02", "DLG_TALK_02A", "DLG_TALK_02B", "DLG_TALK_02C", "TAIL"])
	)


func test_removing_a_line_drops_the_rows_nothing_else_names() -> void:
	var line: DialogueLine = _talk.lines[1]
	ShantyConversationEdits.add_choice(_model, _talk, line)
	assert_true(ShantyConversationEdits.remove_line(_model, _talk, 1))

	assert_false(_model.document.has_key("DLG_TALK_02"))
	assert_false(_model.document.has_key("DLG_TALK_02A"))
	assert_eq(_talk.lines.size(), 1)


func test_a_new_speaker_gets_a_name_row_beside_the_other_names() -> void:
	var speaker: SpeakerDefinition = ShantySpeakerEdits.add_speaker(_model, "bo")

	assert_eq(speaker.name_key, "SPEAKER_BO")
	assert_eq(
		_model.document.keys().slice(0, 3),
		PackedStringArray(["SPEAKER_ANA", "SPEAKER_BO", "UNRELATED"])
	)
	assert_eq(_model.path_of(speaker), Fixture.SPEAKERS + "/bo.tres")
	assert_null(ShantySpeakerEdits.add_speaker(_model, "bo"), "a taken id is refused")
	assert_null(ShantySpeakerEdits.add_speaker(_model, "Not An Id"))


func test_faces_are_added_tagged_and_textured() -> void:
	var speaker: SpeakerDefinition = _model.speakers[0]

	assert_true(ShantySpeakerEdits.add_face(_model, speaker, "wary"))
	assert_false(ShantySpeakerEdits.add_face(_model, speaker, "wary"), "a tag is unique")
	assert_true(ShantySpeakerEdits.set_face_texture(_model, speaker, 1, PlaceholderTexture2D.new()))
	assert_eq(ShantySpeakerEdits.face_tags(_model, &"ana"), PackedStringArray(["neutral", "wary"]))
	assert_true(ShantySpeakerEdits.remove_face(_model, speaker, 0))
	assert_eq(ShantySpeakerEdits.face_tags(_model, &"ana"), PackedStringArray(["wary"]))
	assert_true(_model.is_dirty())


func test_a_changed_name_key_gets_its_own_row() -> void:
	var speaker: SpeakerDefinition = _model.speakers[0]

	assert_true(ShantySpeakerEdits.set_name_key(_model, speaker, "SPEAKER_ANNA"))
	assert_true(_model.document.has_key("SPEAKER_ANNA"))
	assert_true(_model.document.has_key("SPEAKER_ANA"), "the old row is never deleted for it")


func test_conditions_and_effects_are_made_from_the_picked_script() -> void:
	var line: DialogueLine = _talk.lines[0]
	var choice: DialogueChoice = ShantyConversationEdits.add_choice(_model, _talk, line)

	assert_not_null(
		ShantyConversationEdits.add_condition(_model, _talk, line, Fixture.CONDITION_SCRIPT)
	)
	assert_not_null(
		ShantyConversationEdits.add_effect(_model, _talk, choice, Fixture.EFFECT_SCRIPT)
	)
	assert_null(
		ShantyConversationEdits.add_condition(_model, _talk, line, Fixture.EFFECT_SCRIPT),
		"an effect script is not a condition"
	)
	assert_eq(line.conditions.size(), 1)
	assert_eq(choice.effects.size(), 1)
	assert_true(ShantyConversationEdits.remove_entry(_model, _talk, choice, &"effects", 0))
	assert_eq(choice.effects.size(), 0)


func test_an_edit_through_the_model_marks_its_conversation() -> void:
	var choice: DialogueChoice = ShantyConversationEdits.add_choice(_model, _talk, _talk.lines[1])
	_model.save()
	ShantyConversationEdits.edit(_model, _talk, choice, &"jump_label", &"nowhere")

	assert_true(_model.is_dirty())
	assert_true(ShantyLint.has_errors(_model.lint()), "the jump to nowhere is caught")


func test_the_catalog_walks_each_class_to_its_base() -> void:
	var classes: Array[Dictionary] = [
		{"class": &"ShantyCondition", "base": &"Resource", "path": "res://c.gd"},
		{"class": &"HasItem", "base": &"ShantyCondition", "path": "res://has_item.gd"},
		{"class": &"HasRareItem", "base": &"HasItem", "path": "res://rare.gd"},
		{
			"class": &"Abstract",
			"base": &"ShantyCondition",
			"path": "res://a.gd",
			"is_abstract": true
		},
		{"class": &"GiveItem", "base": &"ShantyEffect", "path": "res://give.gd"},
		{"class": &"VideoStep", "base": &"CutsceneStep", "path": "res://v.gd"},
	]

	var conditions: Array[Dictionary] = ShantyClassCatalog.subclasses_of(
		&"ShantyCondition", classes
	)
	assert_eq(conditions.size(), 2)
	assert_eq(conditions[0]["class"], &"HasItem")
	assert_eq(conditions[1]["path"], "res://rare.gd")
	assert_eq(ShantyClassCatalog.subclasses_of(&"CutsceneStep", classes).size(), 0)


func test_the_real_catalog_lists_the_addons_own_steps() -> void:
	var steps: Array[Dictionary] = ShantyClassCatalog.subclasses_of(&"CutsceneStep")
	var names: PackedStringArray = []
	for entry: Dictionary in steps:
		names.append(String(entry["class"]))

	assert_true(names.has("SayStep"))
	assert_false(names.has("VideoStep"), "unbuilt steps are never offered")
