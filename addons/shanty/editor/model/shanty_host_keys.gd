@tool
class_name ShantyHostKeys
extends RefCounted

## The host contract's translation keys (`ShantyHostContract.TRANSLATION_KEYS`)
## in the tab's CSV. A game may declare them in a catalogue of its own, so a
## missing one is reported on open and added only on request; a new config's
## CSV starts with them. Each is added as one block after any host key the CSV
## has (else at the end), with its default text in the CSV's English column and
## a note when the CSV has a `_notes` column -- never adding a column, which
## would rewrite every row.

## The `_notes` cell of a host key the tab adds.
const NOTE: String = "Shown by Shanty's own controls: see ShantyHostContract"


## The host keys `csv` has no row for, in the contract's order.
static func missing(csv: ShantyCsvDocument) -> PackedStringArray:
	var absent: PackedStringArray = []
	for key: String in ShantyHostContract.TRANSLATION_KEYS:
		if not csv.has_key(key):
			absent.append(key)
	return absent


## Gives the model's CSV every missing host key. Returns the keys added; Save
## writes them.
static func add(model: ShantyEditorModel) -> PackedStringArray:
	var english: String = english_column(model.document)
	var notes: bool = model.document.column_of(ShantyCsvDocument.NOTES_HEADER) >= 0
	var added: PackedStringArray = missing(model.document)
	for key: String in added:
		model.add_row(key, model.document.last_of(ShantyHostContract.TRANSLATION_KEYS))
		if not english.is_empty():
			model.set_text(key, english, ShantyHostContract.DEFAULT_TEXT.get(key, ""))
		if notes:
			model.set_notes(key, NOTE)
	return added


## Gives `csv` every missing host key: how a new config's CSV starts. Returns
## the keys added.
static func add_rows(csv: ShantyCsvDocument) -> PackedStringArray:
	var english: String = english_column(csv)
	var notes: bool = csv.column_of(ShantyCsvDocument.NOTES_HEADER) >= 0
	var added: PackedStringArray = missing(csv)
	for key: String in added:
		csv.append_row(key, csv.last_of(ShantyHostContract.TRANSLATION_KEYS))
		if not english.is_empty():
			csv.set_text(key, english, ShantyHostContract.DEFAULT_TEXT.get(key, ""))
		if notes:
			csv.set_notes(key, NOTE)
	return added


## The first locale column in `ShantyHostContract.DEFAULT_TEXT_LOCALE` -- `en`,
## or a regional `en_GB` or `en-US` -- or "" when the CSV has none.
static func english_column(csv: ShantyCsvDocument) -> String:
	for locale: String in csv.locales():
		var language: String = locale.replace("-", "_").get_slice("_", 0)
		if language == ShantyHostContract.DEFAULT_TEXT_LOCALE:
			return locale
	return ""
