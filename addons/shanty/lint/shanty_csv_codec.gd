@tool
class_name ShantyCsvCodec
extends RefCounted

## Reads and writes CSV records exactly as Godot's translation importer reads
## them (`FileAccess.get_csv_line()`): a comma separates cells, a `"` toggles
## quoting anywhere in a cell, `""` inside quotes is one literal quote, a line
## break inside quotes belongs to the cell, and every carriage return is
## dropped from a value. Each record also keeps the text it came from, so an
## untouched row can be written back unchanged.

const DELIMITER: String = ","
const QUOTE: String = '"'


## Every record in `text`, in order. A final line break ends the last record
## rather than starting an empty one; a blank line is a record of one empty
## cell, as the importer sees it.
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
		elif character == "\n" and not in_quote:
			cells.append(current)
			rows.append(
				ShantyCsvRow.new(cells, _without_cr(text.substr(start, index - start)), false)
			)
			cells = []
			current = ""
			start = index + 1
		elif character != "\r":
			current += character
		index += 1
	if start < length:
		cells.append(current)
		rows.append(ShantyCsvRow.new(cells, _without_cr(text.substr(start)), false))
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
		or value.contains("\n")
		or value.contains("\r")
	)
	if not needs_quotes:
		return value
	return QUOTE + value.replace(QUOTE, QUOTE + QUOTE) + QUOTE


## A record's source without the carriage return of a CRLF terminator, so a
## file written on Windows is normalised to LF the first time it is saved.
static func _without_cr(source: String) -> String:
	return source.trim_suffix("\r")
