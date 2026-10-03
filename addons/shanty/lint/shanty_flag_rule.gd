@tool
class_name ShantyFlagRule
extends Resource

## What one `_flags` token forbids. Shanty knows no flag by name: a host names
## its own (`NEUTRAL`, `CHILD_SAFE`...) and lists, per locale, the whole words a
## cell in that locale may not contain while its row carries the flag. A
## locale with no list has no rule -- agreement in some languages is not a word
## list at all, so the lint is a help, never a guarantee.

## The token as written in `_flags`; it may not contain `|`.
@export var flag: String = ""
## Locale -> forbidden whole words, matched case-insensitively.
@export var forbidden_words: Dictionary[String, PackedStringArray] = {}


func words_for(locale: String) -> PackedStringArray:
	return forbidden_words.get(locale, PackedStringArray())
