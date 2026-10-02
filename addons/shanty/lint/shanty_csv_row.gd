@tool
class_name ShantyCsvRow
extends RefCounted

## One record of a translation CSV: its cells, and the exact text it was read
## from, so a row nobody touched is written back byte for byte and a diff of a
## saved file shows only the rows that really changed.

var cells: PackedStringArray = []
## The record's source text without its line terminator. Empty for a row made
## in memory, which is always encoded afresh.
var raw: String = ""
## What ended the record in the file: LF, CRLF, or "" for a last record with no
## line break after it and for a row made in memory, which takes the file's own.
var terminator: String = ""
## True once a cell has changed since the row was read.
var dirty: bool = true


func _init(row_cells: PackedStringArray = [], source: String = "", changed: bool = true) -> void:
	cells = row_cells
	raw = source
	dirty = changed


## The row's key: its first cell, or "" for a blank record.
func key() -> String:
	return cells[0] if not cells.is_empty() else ""


## The cell at `index`, or "" when the row is shorter than that.
func cell(index: int) -> String:
	return cells[index] if index >= 0 and index < cells.size() else ""


## Sets the cell at `index`, widening the row with empty cells when it is short.
## Marks the row dirty only when the value really changes.
func set_cell(index: int, value: String) -> void:
	if index < 0:
		return
	if index < cells.size() and cells[index] == value:
		return
	while cells.size() <= index:
		cells.append("")
	cells[index] = value
	dirty = true


## Inserts an empty cell at `index` when the row reaches that far; a row shorter
## than `index` is left alone, since it has no column there to shift.
func insert_cell(index: int) -> void:
	if index < 0 or index > cells.size():
		return
	cells.insert(index, "")
	dirty = true
