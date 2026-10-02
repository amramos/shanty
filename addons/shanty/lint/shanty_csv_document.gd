@tool
class_name ShantyCsvDocument
extends RefCounted

## A translation CSV in Godot's own shape, held so it can be edited and written
## back with the smallest possible diff. The first column holds the keys; every
## other column whose header does not start with `_` is a locale -- the
## importer's rule, so the header is the only list of locales there is -- and a
## `_` column is the writer's: `_notes` is free text, `_flags` a structured list
## of tokens separated by `|`, and any other is kept exactly as found.
##
## **Bytes outside the edited records never change.** A row nobody edits is
## written back byte for byte, with the terminator it was read with (LF or
## CRLF, mixed as the file mixes them); an edited row is encoded afresh
## (`ShantyCsvCodec`) and keeps its own terminator; a new row takes the file's
## dominant one. A byte-order mark, and whether the file ended with a line
## break, are kept as found. An empty document is written with LF and a final
## line break.

const KEYS_HEADER: String = "keys"
const FLAGS_HEADER: String = "_flags"
const NOTES_HEADER: String = "_notes"
## `|` rather than a space: it survives a hand edit or a spreadsheet trimming
## whitespace, so no flag name may contain it.
const FLAG_SEPARATOR: String = "|"
const LOCALE_PATTERN: String = "^[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]+)*(?:@[A-Za-z]+)?$"
## U+FEFF, which `ShantyFiles.read_text()` keeps at the start of a file that
## began with a UTF-8 byte-order mark.
const BOM: String = "\uFEFF"

var _header: ShantyCsvRow = ShantyCsvRow.new(PackedStringArray([KEYS_HEADER]))
## Every record after the header, blank ones included, in file order.
var _rows: Array[ShantyCsvRow] = []
var _bom: bool = false
var _ends_with_line_break: bool = true


## The document `text` holds. Empty text is a document with a `keys` header.
static func parse(text: String) -> ShantyCsvDocument:
	var document := ShantyCsvDocument.new()
	document._bom = text.begins_with(BOM)
	var body: String = text.substr(BOM.length()) if document._bom else text
	var records: Array[ShantyCsvRow] = ShantyCsvCodec.parse(body)
	if not records.is_empty():
		document._header = records.pop_front()
		document._rows = records
		document._ends_with_line_break = body.ends_with(ShantyCsvCodec.LF)
	return document


## The whole file, ready to write.
func to_text() -> String:
	var records: Array[ShantyCsvRow] = [_header]
	records.append_array(_rows)
	var dominant: String = ShantyCsvCodec.dominant_terminator(records)
	var parts: PackedStringArray = [BOM if _bom else ""]
	for index: int in records.size():
		var row: ShantyCsvRow = records[index]
		var ending: String = row.terminator if not row.terminator.is_empty() else dominant
		if index == records.size() - 1 and not _ends_with_line_break:
			ending = ""
		parts.append(_encoded(row) + ending)
	return "".join(parts)


func header() -> PackedStringArray:
	return _header.cells.duplicate()


## Every locale column, in header order.
func locales() -> PackedStringArray:
	var found: PackedStringArray = []
	for index: int in range(1, _header.cells.size()):
		if is_locale_header(_header.cells[index]):
			found.append(_header.cells[index])
	return found


static func is_locale_header(name: String) -> bool:
	return not name.is_empty() and not name.begins_with("_")


## The column headed `name`, or -1.
func column_of(name: String) -> int:
	return _header.cells.find(name)


## Adds an empty locale column after the last locale (before the `_` columns),
## widening every row. False, changing nothing, for a name that is not a
## locale code or is already a column.
func add_locale(locale: String) -> bool:
	if RegEx.create_from_string(LOCALE_PATTERN).search(locale) == null:
		return false
	if column_of(locale) >= 0:
		return false
	var at: int = 1
	for index: int in range(1, _header.cells.size()):
		if is_locale_header(_header.cells[index]):
			at = index + 1
	_insert_column(at, locale)
	return true


## The index of the `_` column `name`, appended to the header when missing.
func ensure_column(name: String) -> int:
	var index: int = column_of(name)
	if index >= 0:
		return index
	_insert_column(_header.cells.size(), name)
	return _header.cells.size() - 1


## Every key, in file order, a duplicate as often as it appears.
func keys() -> PackedStringArray:
	var found: PackedStringArray = []
	for row: ShantyCsvRow in _rows:
		if not row.key().is_empty():
			found.append(row.key())
	return found


func has_key(key: String) -> bool:
	return _row_index(key) >= 0


func count_key(key: String) -> int:
	return keys().count(key)


## Whichever of `candidates` sits lowest in the file, or "" when none has a
## row: the anchor a block of new rows is inserted after.
func last_of(candidates: PackedStringArray) -> String:
	for index: int in range(_rows.size() - 1, -1, -1):
		if candidates.has(_rows[index].key()) and not _rows[index].key().is_empty():
			return _rows[index].key()
	return ""


## Keys that appear on more than one row: the importer keeps the last.
func duplicate_keys() -> PackedStringArray:
	var seen: Dictionary[String, int] = {}
	var repeated: PackedStringArray = []
	for key: String in keys():
		seen[key] = seen.get(key, 0) + 1
		if seen[key] == 2:
			repeated.append(key)
	return repeated


## Keys whose row is not exactly as wide as the header: the importer drops them.
func width_mismatches() -> PackedStringArray:
	var found: PackedStringArray = []
	for row: ShantyCsvRow in _rows:
		if not row.key().is_empty() and row.cells.size() != _header.cells.size():
			found.append(row.key())
	return found


## The cell of `key` under `column`, or "" when either is missing.
func text(key: String, column: String) -> String:
	var row: int = _row_index(key)
	var at: int = column_of(column)
	if row < 0 or at < 0:
		return ""
	return _rows[row].cell(at)


## Writes a cell. False when the key or the column does not exist.
func set_text(key: String, column: String, value: String) -> bool:
	var row: int = _row_index(key)
	var at: int = column_of(column)
	if row < 0 or at <= 0:
		return false
	_set_cell(_rows[row], at, value)
	return true


## Adds an empty row for `key` straight after `after_key`'s row, or at the end
## when `after_key` is empty or absent. False for an empty or existing key.
func append_row(key: String, after_key: String = "") -> bool:
	if key.is_empty() or has_key(key):
		return false
	var cells: PackedStringArray = []
	cells.resize(_header.cells.size())
	cells[0] = key
	var row := ShantyCsvRow.new(cells)
	var anchor: int = _last_row_index(after_key) if not after_key.is_empty() else -1
	if anchor < 0:
		_rows.append(row)
	else:
		_rows.insert(anchor + 1, row)
	return true


## Removes every row for `key`. False when there was none.
func remove_row(key: String) -> bool:
	var removed: bool = false
	for index: int in range(_rows.size() - 1, -1, -1):
		if _rows[index].key() == key:
			_rows.remove_at(index)
			removed = true
	return removed


## The row's `_flags` tokens, trimmed, in order, empty ones dropped.
func flags(key: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for token: String in text(key, FLAGS_HEADER).split(FLAG_SEPARATOR, false):
		if not token.strip_edges().is_empty():
			found.append(token.strip_edges())
	return found


## Replaces the row's flags, adding the `_flags` column when the file has none.
## False for a missing key or a flag name holding the separator.
func set_flags(key: String, tokens: PackedStringArray) -> bool:
	for token: String in tokens:
		if token.contains(FLAG_SEPARATOR) or token.strip_edges().is_empty():
			return false
	if not has_key(key):
		return false
	ensure_column(FLAGS_HEADER)
	return set_text(key, FLAGS_HEADER, FLAG_SEPARATOR.join(tokens))


## Turns one flag on or off on the row, keeping the others in their order.
func set_flag(key: String, flag: String, on: bool) -> bool:
	var tokens: PackedStringArray = flags(key)
	if on == tokens.has(flag):
		return has_key(key)
	if on:
		tokens.append(flag)
	else:
		tokens.remove_at(tokens.find(flag))
	return set_flags(key, tokens)


func notes(key: String) -> String:
	return text(key, NOTES_HEADER)


## Writes the row's `_notes`, adding the column when the file has none.
func set_notes(key: String, value: String) -> bool:
	if not has_key(key):
		return false
	if value.is_empty() and column_of(NOTES_HEADER) < 0:
		return true
	ensure_column(NOTES_HEADER)
	return set_text(key, NOTES_HEADER, value)


## One report per locale column, in header order.
func coverage() -> Array[ShantyLocaleCoverage]:
	var reports: Array[ShantyLocaleCoverage] = []
	for locale: String in locales():
		reports.append(coverage_of(locale))
	return reports


## How many keyed rows have a non-empty cell in `locale`.
func coverage_of(locale: String) -> ShantyLocaleCoverage:
	var report := ShantyLocaleCoverage.new()
	report.locale = locale
	var at: int = column_of(locale)
	for row: ShantyCsvRow in _rows:
		if row.key().is_empty():
			continue
		report.total += 1
		if at > 0 and not row.cell(at).is_empty():
			report.filled += 1
		else:
			report.empty_keys.append(row.key())
	return report


func _row_index(key: String) -> int:
	if key.is_empty():
		return -1
	for index: int in _rows.size():
		if _rows[index].key() == key:
			return index
	return -1


func _last_row_index(key: String) -> int:
	for index: int in range(_rows.size() - 1, -1, -1):
		if _rows[index].key() == key:
			return index
	return -1


## Widening a row to reach a column is the only way a short row changes width.
func _set_cell(row: ShantyCsvRow, at: int, value: String) -> void:
	row.set_cell(at, value)
	while row.dirty and row.cells.size() < _header.cells.size():
		row.cells.append("")


func _insert_column(at: int, name: String) -> void:
	_header.cells.insert(at, name)
	_header.dirty = true
	for row: ShantyCsvRow in _rows:
		if not row.key().is_empty():
			row.insert_cell(at)


static func _encoded(row: ShantyCsvRow) -> String:
	return ShantyCsvCodec.encode_row(row.cells) if row.dirty or row.raw.is_empty() else row.raw
