extends GutTest

## ShantyCsvDocument reads and writes Godot's translation CSV shape so that a
## save changes only the rows that changed: any locale columns, any `_`
## columns, quoting exactly as the importer reads it.

const SOURCE: String = (
	"keys,en,pt_BR,_notes,_owner\n"
	+ 'GREETING,"Hello, you.",Olá,"A ""quoted"" note",ana\n'
	+ "FAREWELL,Bye,,,\n"
	+ "\n"
	+ 'MULTI,"two\nlines",duas linhas,,\n'
	+ "SPACED,  padded  ,x,,\n"
)


func _document() -> ShantyCsvDocument:
	return ShantyCsvDocument.parse(SOURCE)


func test_an_untouched_document_is_written_back_byte_for_byte() -> void:
	assert_eq(_document().to_text(), SOURCE)


func test_cells_read_as_the_importer_reads_them() -> void:
	var document: ShantyCsvDocument = _document()

	assert_eq(document.text("GREETING", "en"), "Hello, you.")
	assert_eq(document.text("GREETING", "_notes"), 'A "quoted" note')
	assert_eq(document.text("MULTI", "en"), "two\nlines")
	assert_eq(document.text("SPACED", "en"), "  padded  ", "whitespace is the cell's own")
	assert_eq(document.keys(), PackedStringArray(["GREETING", "FAREWELL", "MULTI", "SPACED"]))


func test_the_codec_agrees_with_the_engines_csv_reader() -> void:
	var path: String = "user://shanty_codec_probe.csv"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	file = FileAccess.open(path, FileAccess.READ)
	var engine_rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		engine_rows.append(file.get_csv_line())
	file.close()
	DirAccess.remove_absolute(path)
	var ours: Array[ShantyCsvRow] = ShantyCsvCodec.parse(SOURCE)

	for index: int in ours.size():
		assert_eq(ours[index].cells, engine_rows[index], "record %d" % index)


func test_locales_are_every_column_that_is_not_keys_or_underscored() -> void:
	assert_eq(_document().locales(), PackedStringArray(["en", "pt_BR"]))
	var three: ShantyCsvDocument = ShantyCsvDocument.parse("keys,de,_x,ja,fr\nA,1,2,3,4\n")
	assert_eq(three.locales(), PackedStringArray(["de", "ja", "fr"]))


func test_editing_one_cell_rewrites_only_that_row() -> void:
	var document: ShantyCsvDocument = _document()

	assert_true(document.set_text("FAREWELL", "pt_BR", 'Tchau, "amigo"'))
	var expected: String = SOURCE.replace(
		"FAREWELL,Bye,,,\n", 'FAREWELL,Bye,"Tchau, ""amigo""",,\n'
	)
	assert_eq(document.to_text(), expected)


func test_setting_a_cell_to_its_own_value_changes_nothing() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en\nA,x\n")
	document.set_text("A", "en", "x")

	assert_eq(document.to_text(), "keys,en\nA,x\n")


func test_a_new_row_goes_after_its_anchor_and_new_rows_stay_contiguous() -> void:
	var document: ShantyCsvDocument = _document()

	assert_true(document.append_row("GREETING_2", "GREETING"))
	assert_true(document.append_row("GREETING_3", "GREETING_2"))
	assert_true(document.append_row("LAST"))
	assert_eq(
		document.keys(),
		PackedStringArray(
			["GREETING", "GREETING_2", "GREETING_3", "FAREWELL", "MULTI", "SPACED", "LAST"]
		)
	)
	assert_true(document.to_text().contains("GREETING_2,,,,\nGREETING_3,,,,\nFAREWELL,Bye,,,\n"))


func test_a_duplicate_or_empty_key_is_refused() -> void:
	var document: ShantyCsvDocument = _document()

	assert_false(document.append_row("GREETING"))
	assert_false(document.append_row(""))
	assert_eq(document.keys().size(), 4)


func test_a_row_is_removed_by_key() -> void:
	var document: ShantyCsvDocument = _document()

	assert_true(document.remove_row("FAREWELL"))
	assert_false(document.remove_row("FAREWELL"))
	assert_false(document.to_text().contains("FAREWELL"))


func test_a_locale_column_goes_after_the_last_locale_and_widens_every_row() -> void:
	var document: ShantyCsvDocument = _document()

	assert_true(document.add_locale("fr"))
	assert_eq(
		document.header(), PackedStringArray(["keys", "en", "pt_BR", "fr", "_notes", "_owner"])
	)
	assert_eq(document.text("GREETING", "_owner"), "ana", "the `_` columns kept their cells")
	assert_true(document.to_text().contains("FAREWELL,Bye,,,,\n"))
	assert_eq(document.width_mismatches(), PackedStringArray())


func test_a_bad_or_existing_locale_is_refused() -> void:
	var document: ShantyCsvDocument = _document()

	for name: String in ["en", "_x", "", "two words", "a,b", "keys"]:
		assert_false(document.add_locale(name), "'%s' is refused" % name)
	assert_eq(document.to_text(), SOURCE)


func test_flags_are_a_structured_column() -> void:
	var document: ShantyCsvDocument = _document()

	assert_eq(document.flags("GREETING"), PackedStringArray())
	assert_true(document.set_flag("GREETING", "NEUTRAL", true))
	assert_true(document.set_flag("GREETING", "SHORT", true))
	assert_eq(document.column_of("_flags"), 5, "the column is added at the end")
	assert_eq(document.text("GREETING", "_flags"), "NEUTRAL|SHORT")
	assert_true(document.set_flag("GREETING", "NEUTRAL", false))
	assert_eq(document.flags("GREETING"), PackedStringArray(["SHORT"]))
	assert_false(document.set_flag("GREETING", "A|B", true), "no flag may hold the separator")


func test_flags_read_tolerantly() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse(
		"keys,en,_flags\nA,x, NEUTRAL || LOUD \n"
	)

	assert_eq(document.flags("A"), PackedStringArray(["NEUTRAL", "LOUD"]))


func test_notes_are_free_text_and_added_only_when_written() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en\nA,x\n")

	assert_true(document.set_notes("A", ""))
	assert_eq(document.column_of("_notes"), -1)
	assert_true(document.set_notes("A", "said, quietly"))
	assert_eq(document.to_text(), 'keys,en,_notes\nA,x,"said, quietly"\n')


func test_coverage_counts_filled_cells_per_locale() -> void:
	var reports: Array[ShantyLocaleCoverage] = _document().coverage()

	assert_eq(reports.size(), 2)
	assert_eq(reports[0].summary(), "en 4/4")
	assert_true(reports[0].is_complete())
	assert_eq(reports[1].summary(), "pt_BR 3/4")
	assert_eq(reports[1].empty_keys, PackedStringArray(["FAREWELL"]))


func test_shape_problems_are_reported() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en\nA,x\nB\nA,y\n")

	assert_eq(document.duplicate_keys(), PackedStringArray(["A"]))
	assert_eq(document.width_mismatches(), PackedStringArray(["B"]))
	assert_eq(document.text("A", "en"), "x", "the first row answers")


func test_crlf_input_is_written_as_lf() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en\r\nA,x\r\n")

	assert_eq(document.text("A", "en"), "x")
	assert_eq(document.to_text(), "keys,en\nA,x\n")


func test_an_empty_text_is_a_document_with_a_keys_header() -> void:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse("")

	assert_true(document.add_locale("en"))
	assert_true(document.append_row("A"))
	assert_true(document.set_text("A", "en", "x"))
	assert_eq(document.to_text(), "keys,en\nA,x\n")


func test_the_key_column_is_never_written_through_set_text() -> void:
	var document: ShantyCsvDocument = _document()

	assert_false(document.set_text("GREETING", "keys", "RENAMED"))
	assert_false(document.set_text("NOPE", "en", "x"))
	assert_false(document.set_text("GREETING", "de", "x"))
