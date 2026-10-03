@tool
class_name ShantyCsvCodec
extends RefCounted

## Reads and writes CSV records exactly as Godot's translation importer reads
## them (`FileAccess.get_csv_line()`): a comma separates cells, a `"` toggles
## quoting anywhere in a cell, `""` inside quotes is one literal quote, a line
## break inside quotes belongs to the cell, and every carriage return is
## dropped from a value. Each record also keeps the text it came from and the
## line terminator that ended it, so an untouched row is written back byte for
## byte.

const DELIMITER: String = ","
const QUOTE: String = '"'
const LF: String = "\n"
const CR: String = "\r"
const CRLF: String = CR + LF


## Every record in `text`, in order. A final line break ends the last record
## rather than starting an empty one; a blank line is a record of one empty
## cell, as the importer sees it. Each record remembers its terminator: CRLF,
## LF, or "" for a last record with no line break after it.
static func parse(text: String) -> Array[ShantyCsvRow]:
	var rows: Array[ShantyCsvRow] = []
	var cells: PackedStringArray = []
	var current: String = ""
	var in_quote: bool = false
	var start: int = 0
	var index: int = 0
	var length: int = text.length()
	while index < length:
		var character: String = text[index]
		if character == DELIMITER and not in_quote:
			cells.append(current)
			current = ""
		elif character == QUOTE:
			if in_quote and index + 1 < length and text[index + 1] == QUOTE:
				current += QUOTE
				index += 1
			else:
				in_quote = not in_quote
		elif character == LF and not in_quote:
			cells.append(current)
			var crlf: bool = index > start and text[index - 1] == CR
			var end: int = index - 1 if crlf else index
			rows.append(_row(cells, text.substr(start, end - start), CRLF if crlf else LF))
			cells = []
			current = ""
			start = index + 1
		elif character != CR:
			current += character
		index += 1
	if start < length:
		cells.append(current)
		rows.append(_row(cells, text.substr(start), ""))
	return rows


## `cells` as one record, without a line terminator.
static func encode_row(cells: PackedStringArray) -> String:
	var fields: PackedStringArray = []
	for value: String in cells:
		fields.append(encode_field(value))
	return DELIMITER.join(fields)


## `value` as one field: quoted, with its quotes doubled, only when it holds a
## delimiter, a quote or a line break -- the importer would otherwise split it,
## swallow its quotes or end the record early.
static func encode_field(value: String) -> String:
	var needs_quotes: bool = (
		value.contains(DELIMITER)
		or value.contains(QUOTE)
		or value.contains(LF)
		or value.contains(CR)
	)
	if not needs_quotes:
		return value
	return QUOTE + value.replace(QUOTE, QUOTE + QUOTE) + QUOTE


## The terminator most of `records` were read with; LF on a tie or when none was
## read, so a new file is written with LF.
static func dominant_terminator(records: Array[ShantyCsvRow]) -> String:
	var crlf: int = 0
	var lf: int = 0
	for row: ShantyCsvRow in records:
		if row.terminator == CRLF:
			crlf += 1
		elif row.terminator == LF:
			lf += 1
	return CRLF if crlf > lf else LF


static func _row(cells: PackedStringArray, source: String, terminator: String) -> ShantyCsvRow:
	var row := ShantyCsvRow.new(cells, source, false)
	row.terminator = terminator
	return row
