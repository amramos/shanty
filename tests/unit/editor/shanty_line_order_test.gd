extends GutTest

## Inserting and reordering lines changes order only: an inserted line takes
## the next free number wherever it sits, a moved line keeps its key, and no
## other key or CSV row moves. A new speaker drops a face it does not have.

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


func test_insert_after_takes_the_next_free_number_and_the_row_above_s_voice() -> void:
	var rows_before: PackedStringArray = _model.document.keys()
	_talk.lines[0].face = &"neutral"
	var inserted: DialogueLine = ShantyConversationEdits.insert_line_after(_model, _talk, 0)

	assert_eq(inserted.text_key, "DLG_TALK_03")
	assert_eq(inserted.speaker_id, &"ana")
	assert_eq(inserted.face, &"neutral")
	assert_eq(
		ShantyConversationEdits.keys_of(_talk),
		PackedStringArray(["DLG_TALK_01", "DLG_TALK_03", "DLG_TALK_02"])
	)
	var rows_after: PackedStringArray = rows_before.duplicate()
	rows_after.insert(rows_before.find("DLG_TALK_02") + 1, "DLG_TALK_03")
	assert_eq(_model.document.keys(), rows_after, "the new row joins the block; none moves")
	assert_true(_model.is_dirty())


func test_insert_at_the_start_and_outside_the_conversation() -> void:
	var first: DialogueLine = ShantyConversationEdits.insert_line_after(_model, _talk, -1)

	assert_eq(_talk.lines[0], first)
	assert_eq(first.text_key, "DLG_TALK_03")
	assert_null(ShantyConversationEdits.insert_line_after(_model, _talk, 3))
	assert_null(ShantyConversationEdits.insert_line_after(_model, _talk, -2))


func test_moving_a_line_changes_order_and_nothing_else() -> void:
	var csv_before: String = _model.document.to_text()
	ShantyConversationEdits.insert_line_after(_model, _talk, 1)
	var csv_with_new_row: String = _model.document.to_text()

	assert_true(ShantyConversationEdits.move_line(_model, _talk, 2, 0))
	assert_eq(
		ShantyConversationEdits.keys_of(_talk),
		PackedStringArray(["DLG_TALK_03", "DLG_TALK_01", "DLG_TALK_02"])
	)
	assert_eq(_model.document.to_text(), csv_with_new_row, "a move touches no row")
	assert_ne(csv_before, csv_with_new_row)
	assert_true(ShantyConversationEdits.move_line(_model, _talk, 0, 2))
	assert_eq(
		ShantyConversationEdits.keys_of(_talk),
		PackedStringArray(["DLG_TALK_01", "DLG_TALK_02", "DLG_TALK_03"])
	)


func test_a_move_outside_the_conversation_is_refused() -> void:
	assert_false(ShantyConversationEdits.move_line(_model, _talk, 0, 2))
	assert_false(ShantyConversationEdits.move_line(_model, _talk, -1, 0))
	assert_false(ShantyConversationEdits.move_line(_model, _talk, 1, 1))
	assert_false(_model.is_dirty())


func test_a_new_speaker_drops_a_face_it_does_not_have() -> void:
	var bo: SpeakerDefinition = ShantySpeakerEdits.add_speaker(_model, "bo")
	ShantySpeakerEdits.add_face(_model, bo, "wary")
	var line: DialogueLine = _talk.lines[0]

	ShantyConversationEdits.set_speaker(_model, _talk, line, &"bo")
	assert_eq(line.speaker_id, &"bo")
	assert_eq(line.face, &"", "bo has no neutral face")

	line.face = &"wary"
	ShantyConversationEdits.set_speaker(_model, _talk, line, &"bo")
	assert_eq(line.face, &"wary", "a face the speaker has is kept")
	assert_false(ShantyLint.has_errors(_model.lint()))
