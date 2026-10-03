@tool
class_name ShantyKeyScheme
extends Resource

## How the editor names a key it creates. A pattern is literal text with
## placeholders: `{ID}` (an id, upper-cased, anything outside `A-Z0-9_` made
## `_`), `{PREFIX}` (a conversation's key prefix), `{NN}` (a line number,
## zero-padded to `number_digits`), `{LINE}` (the asking line's key) and
## `{LETTER}` (a reply's letter).
##
## **A key is never renumbered.** A new line takes the next free number after
## the highest one already in use under its prefix -- an inserted line is
## numbered out of order rather than shifting every key after it, so no
## translation ever follows the wrong line.

const REPLY_LETTERS: PackedStringArray = ["A", "B", "C"]

## A new conversation's prefix, before the writer edits it.
@export var conversation_prefix: String = "DLG_{ID}"
## Must hold `{PREFIX}` and `{NN}`.
@export var line_key: String = "{PREFIX}_{NN}"
## Must hold `{LINE}` and `{LETTER}`.
@export var reply_key: String = "{LINE}{LETTER}"
@export var speaker_name_key: String = "SPEAKER_{ID}"
@export var scene_title_key: String = "SCENE_TITLE_{ID}"
@export var scene_synopsis_key: String = "SCENE_SYNOPSIS_{ID}"
@export_range(1, 6) var number_digits: int = 2


## `id` as a key fragment: `old_lamp` -> `OLD_LAMP`.
static func id_token(id: String) -> String:
	var token: String = ""
	for character: String in id.to_upper():
		var allowed: bool = (
			(character >= "A" and character <= "Z")
			or (character >= "0" and character <= "9")
			or character == "_"
		)
		token += character if allowed else "_"
	return token


## False when a pattern lacks a placeholder it needs to stay unique.
func is_valid() -> bool:
	return (
		line_key.contains("{PREFIX}")
		and line_key.contains("{NN}")
		and reply_key.contains("{LINE}")
		and reply_key.contains("{LETTER}")
	)


func prefix_for(conversation_id: String) -> String:
	return conversation_prefix.replace("{ID}", id_token(conversation_id))


func speaker_key(speaker_id: String) -> String:
	return speaker_name_key.replace("{ID}", id_token(speaker_id))


func title_key(scene_id: String) -> String:
	return scene_title_key.replace("{ID}", id_token(scene_id))


func synopsis_key(scene_id: String) -> String:
	return scene_synopsis_key.replace("{ID}", id_token(scene_id))


func line_key_for(prefix: String, number: int) -> String:
	var padded: String = str(number).pad_zeros(number_digits)
	return line_key.replace("{PREFIX}", prefix).replace("{NN}", padded)


## The line number `key` carries under `prefix`, or -1 when it is not a line
## key of that prefix.
func number_of(prefix: String, key: String) -> int:
	if not is_valid():
		return -1
	var found: RegExMatch = _line_pattern(ShantyLintText.escape_regex(prefix)).search(key)
	return found.get_string("nn").to_int() if found != null else -1


## The next free line key under `prefix`, given every key already taken.
func next_line_key(prefix: String, taken: PackedStringArray) -> String:
	var highest: int = 0
	for key: String in taken:
		highest = maxi(highest, number_of(prefix, key))
	return line_key_for(prefix, highest + 1)


## The first reply key under `line` that is not taken, or "" once all three
## letters are used.
func next_reply_key(line: String, taken: PackedStringArray) -> String:
	for letter: String in REPLY_LETTERS:
		var key: String = reply_key.replace("{LINE}", line).replace("{LETTER}", letter)
		if not taken.has(key):
			return key
	return ""


## The prefix most of `keys` share as line keys, or "" when none is one. The
## first seen wins a tie, so a conversation keeps the prefix it began with.
func infer_prefix(keys: PackedStringArray) -> String:
	if not is_valid():
		return ""
	var pattern: RegEx = _line_pattern("(?<prefix>.+)")
	var counts: Dictionary[String, int] = {}
	var best: String = ""
	for key: String in keys:
		var found: RegExMatch = pattern.search(key)
		if found == null:
			continue
		var prefix: String = found.get_string("prefix")
		counts[prefix] = counts.get(prefix, 0) + 1
		if best.is_empty() or counts[prefix] > counts[best]:
			best = prefix
	return best


func _line_pattern(prefix_expression: String) -> RegEx:
	var parts: PackedStringArray = []
	for piece: String in line_key.split("{PREFIX}"):
		var numbered: PackedStringArray = []
		for literal: String in piece.split("{NN}"):
			numbered.append(ShantyLintText.escape_regex(literal))
		parts.append("(?<nn>\\d+)".join(numbered))
	return RegEx.create_from_string("^" + prefix_expression.join(parts) + "$")
