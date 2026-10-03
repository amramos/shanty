extends GutTest

## ShantyEditorModel's Save, against real files in a temporary folder: it
## writes only what changed, keeps every other row byte for byte, refuses on a
## lint error or a file someone else changed, and never on an empty locale.

const Fixture := preload("res://tests/support/editor_fixture.gd")

var _model: ShantyEditorModel


func before_each() -> void:
	_model = Fixture.open_model()


func after_each() -> void:
	_model = null


func after_all() -> void:
	Fixture.remove()


func test_opening_reads_locales_resources_and_coverage() -> void:
	assert_eq(_model.locales(), PackedStringArray(["en", "pt_BR"]))
	assert_eq(_model.source_locale, "en")
	assert_eq(_model.target_locale, "pt_BR")
	assert_eq(_model.speakers.size(), 1)
	assert_eq(_model.conversations.size(), 1)
	assert_eq(_model.coverage()[1].summary(), "pt_BR 4/5")
	assert_false(_model.is_dirty())


func test_an_edit_round_trips_and_every_other_row_is_byte_identical() -> void:
	assert_true(_model.set_text("DLG_TALK_02", "pt_BR", "Tchau."))
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_eq(result.csv_path, Fixture.CSV_PATH)
	assert_eq(result.resource_paths, PackedStringArray(), "no resource was edited")
	assert_eq(
		Fixture.csv_on_disk(),
		Fixture.CSV.replace("DLG_TALK_02,Bye.,,\n", "DLG_TALK_02,Bye.,Tchau.,\n")
	)
	var reopened := ShantyEditorModel.new()
	reopened.open(Fixture.config(), true)
	assert_eq(reopened.text("DLG_TALK_02", "pt_BR"), "Tchau.")
	assert_eq(reopened.coverage()[1].summary(), "pt_BR 5/5")


func test_saving_nothing_writes_nothing() -> void:
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved)
	assert_eq(result.csv_path, "")
	assert_eq(Fixture.csv_on_disk(), Fixture.CSV)


func test_a_flag_toggle_writes_the_flags_column() -> void:
	assert_true(_model.set_flag("DLG_TALK_01", "NEUTRAL", true))
	assert_true(_model.save().saved)

	var text: String = Fixture.csv_on_disk()
	assert_true(text.begins_with("keys,en,pt_BR,_notes,_flags\n"))
	assert_true(text.contains("DLG_TALK_01,Hello.,Olá.,,NEUTRAL\n"))


func test_a_lint_error_refuses_the_save_and_writes_nothing() -> void:
	_model.set_flag("DLG_TALK_01", "NEUTRAL", true)
	_model.set_text("DLG_TALK_01", "en", "She left.")
	var result: ShantySaveResult = _model.save()

	assert_false(result.saved)
	assert_string_contains(result.message, "1 error")
	assert_true(ShantyLint.has_errors(result.issues))
	assert_eq(Fixture.csv_on_disk(), Fixture.CSV)


func test_warnings_and_an_empty_locale_never_refuse() -> void:
	_model.config.length_cap = 3
	assert_true(_model.add_locale("fr"))
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_gt(result.issues.size(), 0, "the length warnings were reported")
	assert_true(Fixture.csv_on_disk().begins_with("keys,en,pt_BR,fr,_notes\n"))
	assert_eq(_model.coverage()[2].summary(), "fr 0/5")


func test_a_short_row_never_refuses_and_keeps_its_bytes() -> void:
	var source: String = Fixture.CSV + "SHORT,only English\n"
	ShantyFiles.write_text(Fixture.CSV_PATH, source)
	_model.reload()
	assert_true(_model.set_text("DLG_TALK_02", "pt_BR", "Tchau."))
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_eq(_model.coverage()[1].summary(), "pt_BR 5/6", "the short row's pt_BR is empty")
	assert_eq(
		Fixture.csv_on_disk(), source.replace("DLG_TALK_02,Bye.,,\n", "DLG_TALK_02,Bye.,Tchau.,\n")
	)


func test_a_csv_changed_on_disk_refuses_the_save() -> void:
	_model.set_text("DLG_TALK_02", "pt_BR", "Tchau.")
	var theirs: String = Fixture.CSV + "THEIRS,Added elsewhere,,\n"
	ShantyFiles.write_text(Fixture.CSV_PATH, theirs)
	var result: ShantySaveResult = _model.save()

	assert_false(result.saved)
	assert_eq(result.stale_paths, PackedStringArray([Fixture.CSV_PATH]))
	assert_string_contains(result.message, "changed on disk")
	assert_eq(Fixture.csv_on_disk(), theirs, "their rows survive")


func test_a_resource_changed_on_disk_refuses_the_whole_save() -> void:
	var conversation: ConversationDefinition = _model.conversations[0]
	ShantyConversationEdits.add_line(_model, conversation, &"ana", &"neutral")
	var path: String = Fixture.CONVERSATIONS + "/talk.tres"
	ShantyFiles.write_text(path, ShantyFiles.read_text(path) + "\n")
	var result: ShantySaveResult = _model.save()

	assert_false(result.saved)
	assert_eq(result.stale_paths, PackedStringArray([path]))
	assert_eq(Fixture.csv_on_disk(), Fixture.CSV, "the CSV was not written either")


func test_reload_takes_the_disk_and_drops_unsaved_edits() -> void:
	_model.set_text("DLG_TALK_02", "pt_BR", "Tchau.")
	ShantyFiles.write_text(Fixture.CSV_PATH, Fixture.CSV + "THEIRS,x,y,\n")
	_model.reload()

	assert_false(_model.is_dirty())
	assert_eq(_model.text("DLG_TALK_02", "pt_BR"), "")
	assert_true(_model.document.has_key("THEIRS"))
	assert_true(_model.save().saved)


func test_new_lines_and_resources_save_and_load_back() -> void:
	var conversation: ConversationDefinition = _model.conversations[0]
	var line: DialogueLine = ShantyConversationEdits.add_line(
		_model, conversation, &"ana", &"neutral"
	)
	_model.set_text(line.text_key, "en", "One more.")
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_eq(result.resource_paths, PackedStringArray([Fixture.CONVERSATIONS + "/talk.tres"]))
	assert_true(Fixture.csv_on_disk().contains("DLG_TALK_02,Bye.,,\nDLG_TALK_03,One more.,,\nTAIL"))
	var loaded: ConversationDefinition = ResourceLoader.load(
		Fixture.CONVERSATIONS + "/talk.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_eq(loaded.lines.size(), 3)
	assert_eq(loaded.lines[2].text_key, "DLG_TALK_03")


func test_a_new_conversation_is_saved_to_its_folder() -> void:
	var conversation: ConversationDefinition = ShantyConversationEdits.add_conversation(
		_model, "greet", "DLG_GREET"
	)
	ShantyConversationEdits.add_line(_model, conversation, &"ana", &"neutral")
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_true(FileAccess.file_exists(Fixture.CONVERSATIONS + "/greet.tres"))
	assert_true(Fixture.csv_on_disk().ends_with("TAIL,Last,Último,\nDLG_GREET_01,,,\n"))
	assert_eq(conversation.resource_path, Fixture.CONVERSATIONS + "/greet.tres")


func test_a_new_file_that_appeared_on_disk_is_stale_too() -> void:
	ShantyConversationEdits.add_conversation(_model, "greet")
	ShantyFiles.write_text(Fixture.CONVERSATIONS + "/greet.tres", "someone else's")

	assert_eq(_model.save().stale_paths, PackedStringArray([Fixture.CONVERSATIONS + "/greet.tres"]))


func test_a_write_that_fails_part_way_leaves_every_file_as_it_was() -> void:
	var talk_path: String = Fixture.CONVERSATIONS + "/talk.tres"
	var talk_before: PackedByteArray = ShantyFiles.read_bytes(talk_path)
	var csv_before: PackedByteArray = ShantyFiles.read_bytes(Fixture.CSV_PATH)
	_model.set_text("DLG_TALK_02", "pt_BR", "Tchau.")
	ShantyConversationEdits.add_line(_model, _model.conversations[0], &"ana", &"neutral")
	# The second resource cannot be written: its folder does not exist.
	_model.adopt(ConversationDefinition.new(), Fixture.ROOT + "/missing/lost.tres")
	var result: ShantySaveResult = _model.save()

	assert_engine_error("ERR_CANT_OPEN", "the saver reports the folder it could not open")
	assert_false(result.saved)
	assert_string_contains(result.message, "lost.tres")
	assert_eq(ShantyFiles.read_bytes(Fixture.CSV_PATH), csv_before, "the CSV keeps its bytes")
	assert_eq(ShantyFiles.read_bytes(talk_path), talk_before, "so does the first resource")
	assert_false(FileAccess.file_exists(ShantyFiles.text_staging_path(Fixture.CSV_PATH)))
	assert_false(FileAccess.file_exists(ShantyFiles.resource_staging_path(talk_path)))
	assert_true(_model.is_dirty(), "every edit is still there to save")


func test_a_save_writes_the_csv_and_every_resource_together() -> void:
	var conversation: ConversationDefinition = _model.conversations[0]
	ShantyConversationEdits.add_line(_model, conversation, &"ana", &"neutral")
	var greet: ConversationDefinition = ShantyConversationEdits.add_conversation(_model, "greet")
	ShantyConversationEdits.add_line(_model, greet, &"ana", &"neutral")
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_eq(result.csv_path, Fixture.CSV_PATH)
	assert_eq(result.resource_paths.size(), 2)
	assert_true(Fixture.csv_on_disk().contains("DLG_TALK_03"))
	assert_true(FileAccess.file_exists(Fixture.CONVERSATIONS + "/greet.tres"))
	assert_false(_model.is_dirty())
	for path: String in result.staged_paths:
		assert_false(FileAccess.file_exists(path), "%s was removed" % path)
