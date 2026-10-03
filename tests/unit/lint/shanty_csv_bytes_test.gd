extends GutTest

## ShantyCsvDocument keeps every byte outside the records it edits, checked at
## the byte level: CRLF, mixed terminators, a byte-order mark, a file with no
## final line break. An edited row changes only its own bytes, keeping its
## terminator; a new row takes the file's dominant one.

const PATH: String = "user://shanty_csv_bytes_probe.csv"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


## `source` parsed, `key`'s `en` cell set to `value`, written back as bytes.
static func _edited(source: String, key: String, value: String) -> PackedByteArray:
	var document: ShantyCsvDocument = ShantyCsvDocument.parse(source)
	document.set_text(key, "en", value)
	return document.to_text().to_utf8_buffer()


func test_a_crlf_file_round_trips_exactly() -> void:
	var source: String = "keys,en\r\nA,x\r\nB,y\r\n"

	assert_eq(ShantyCsvDocument.parse(source).text("A", "en"), "x", "no CR in the value")
	assert_eq(ShantyCsvDocument.parse(source).to_text().to_utf8_buffer(), source.to_utf8_buffer())
	assert_eq(_edited(source, "A", "z"), "keys,en\r\nA,z\r\nB,y\r\n".to_utf8_buffer())


func test_mixed_terminators_are_kept_row_by_row() -> void:
	var source: String = "keys,en\r\nA,x\nB,y\r\nC,w\n"

	assert_eq(ShantyCsvDocument.parse(source).to_text().to_utf8_buffer(), source.to_utf8_buffer())
	assert_eq(_edited(source, "A", "z"), "keys,en\r\nA,z\nB,y\r\nC,w\n".to_utf8_buffer())
	assert_eq(_edited(source, "B", "z"), "keys,en\r\nA,x\nB,z\r\nC,w\n".to_utf8_buffer())


func test_a_file_without_a_final_line_break_keeps_ending_without_one() -> void:
	var source: String = "keys,en\nA,x\nB,y"

	assert_eq(ShantyCsvDocument.parse(source).to_text().to_utf8_buffer(), source.to_utf8_buffer())
	assert_eq(_edited(source, "A", "z"), "keys,en\nA,z\nB,y".to_utf8_buffer())
	assert_eq(_edited(source, "B", "z"), "keys,en\nA,x\nB,z".to_utf8_buffer())


func test_a_new_row_takes_the_dominant_terminator() -> void:
	var crlf: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en\r\nA,x\r\nB,y\n")
	crlf.append_row("C", "A")
	assert_eq(crlf.to_text(), "keys,en\r\nA,x\r\nC,\r\nB,y\n")

	var open_end: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en\r\nA,x")
	open_end.append_row("B")
	assert_eq(open_end.to_text(), "keys,en\r\nA,x\r\nB,", "the old last row gets a line break")


func test_a_byte_order_mark_survives_a_save_through_the_files() -> void:
	var body: String = "keys,en\r\nA,x\r\nB,y\r\n"
	var bytes := PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array(body.to_utf8_buffer())
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

	var document: ShantyCsvDocument = ShantyCsvDocument.parse(ShantyFiles.read_text(PATH))
	assert_eq(document.header()[0], "keys", "the mark is not part of the first cell")
	assert_eq(document.text("A", "en"), "x")
	assert_true(document.set_text("A", "en", "z"))
	assert_eq(ShantyFiles.write_text(PATH, document.to_text()), OK)

	var expected := PackedByteArray([0xEF, 0xBB, 0xBF])
	expected.append_array("keys,en\r\nA,z\r\nB,y\r\n".to_utf8_buffer())
	assert_eq(FileAccess.get_file_as_bytes(PATH), expected)


func test_a_file_without_a_mark_is_written_without_one() -> void:
	ShantyFiles.write_text(PATH, "keys,en\nA,x\n")
	var document: ShantyCsvDocument = ShantyCsvDocument.parse(ShantyFiles.read_text(PATH))
	ShantyFiles.write_text(PATH, document.to_text())

	assert_eq(FileAccess.get_file_as_bytes(PATH), "keys,en\nA,x\n".to_utf8_buffer())
