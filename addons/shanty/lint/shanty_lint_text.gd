@tool
class_name ShantyLintText
extends RefCounted

## The lint rules that read the CSV's cells: the file's own shape, flag words,
## `{name:}` tokens and length. Pure; `ShantyLint` runs them with the rules
## that read the authored resources.

const NAME_TOKEN: String = "\\{name:([^}]*)\\}"
const MARKUP_TAG: String = "\\[/?hl\\]"
## A letter, combining mark, digit or underscore on either side means the word
## is part of a longer one. Written with Unicode classes so accented letters
## count, composed (`é`) or decomposed (`e` + U+0301) alike.
##
## **An apostrophe is a word edge, not part of a word**, so a forbidden `she`
## is found in `she's` and a forbidden `homme` in `l'homme`: a contraction or an
## elision still says the word, and a lint that missed it would pass the very
## line it exists to stop. A forbidden word holding an apostrophe (`she's`)
## still matches only itself. The typographic apostrophe (U+2019) is read as
## `'`, in the text and in the word list alike.
const WORD_EDGE_BEFORE: String = "(?<![\\p{L}\\p{M}\\p{N}_])"
const WORD_EDGE_AFTER: String = "(?![\\p{L}\\p{M}\\p{N}_])"
const APOSTROPHE: String = "'"
const TYPOGRAPHIC_APOSTROPHE: String = "\u2019"


## Duplicate keys, and rows not as wide as the header. Godot's importer reads
## a short row's missing cells as empty, so it imports and is only a warning; it
## ignores a long row's extra cells without a word, and those almost always mean
## an unescaped comma that shifted the text, so a long row is an error.
static func check_shape(document: ShantyCsvDocument, issues: Array[ShantyLintIssue]) -> void:
	for key: String in document.duplicate_keys():
		issues.append(
			ShantyLintIssue.error(
				ShantyLint.RULE_DUPLICATE_KEY,
				"the key is on more than one row; the importer keeps only the last",
				key
			)
		)
	var width: int = document.header().size()
	var mismatches: Dictionary[String, int] = document.width_mismatches()
	for key: String in mismatches:
		var cells: int = mismatches[key]
		if cells < width:
			issues.append(
				ShantyLintIssue.warning(
					ShantyLint.RULE_ROW_WIDTH,
					"%d cells, header has %d; missing cells read as empty" % [cells, width],
					key
				)
			)
		else:
			issues.append(
				ShantyLintIssue.error(
					ShantyLint.RULE_ROW_WIDTH,
					(
						"%d cells, header has %d; the extra cells are ignored (an unescaped comma?)"
						% [cells, width]
					),
					key
				)
			)


## Every flagged row against the config's word lists: a forbidden whole word in
## a locale's cell is an error, and a token the config does not name a warning.
static func check_flags(
	document: ShantyCsvDocument, config: ShantyProjectConfig, issues: Array[ShantyLintIssue]
) -> void:
	var known: PackedStringArray = config.flag_names() if config != null else PackedStringArray()
	for key: String in document.keys():
		for flag: String in document.flags(key):
			if not known.has(flag):
				issues.append(
					ShantyLintIssue.warning(
						ShantyLint.RULE_UNKNOWN_FLAG,
						"the config names no flag '%s', so it checks nothing" % flag,
						key
					)
				)
				continue
			var rule: ShantyFlagRule = config.rule_for(flag)
			for locale: String in document.locales():
				for word: String in forbidden_words_in(
					document.text(key, locale), rule.words_for(locale)
				):
					issues.append(
						ShantyLintIssue.error(
							ShantyLint.RULE_FLAG_WORD,
							"flagged %s, but the text says '%s'" % [flag, word],
							key,
							"",
							locale
						)
					)


## The words of `words` that `text` contains whole, case-insensitively, in
## list order. `{name:}` tokens and markup tags are not text. Words are compared
## as written, without Unicode normalization.
static func forbidden_words_in(text: String, words: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = []
	if text.is_empty():
		return found
	# Lower-cased here rather than with `(?i)`, which folds ASCII only.
	var plain: String = _comparable(plain_text(text))
	for word: String in words:
		if word.strip_edges().is_empty():
			continue
		var literal: String = _comparable(word.strip_edges())
		var pattern: String = WORD_EDGE_BEFORE + escape_regex(literal) + WORD_EDGE_AFTER
		if RegEx.create_from_string(pattern).search(plain) != null:
			found.append(word.strip_edges())
	return found


## Every filled locale of a row must name the same speakers by token, the same
## number of times; a token naming no known speaker is a warning.
static func check_tokens(
	document: ShantyCsvDocument, speaker_ids: PackedStringArray, issues: Array[ShantyLintIssue]
) -> void:
	for key: String in document.keys():
		var reference: String = ""
		var reference_tokens: PackedStringArray = []
		for locale: String in document.locales():
			var text: String = document.text(key, locale)
			if text.is_empty():
				continue
			var tokens: PackedStringArray = name_tokens(text)
			if reference.is_empty():
				reference = locale
				reference_tokens = tokens
				_check_known(tokens, speaker_ids, key, locale, issues)
			elif tokens != reference_tokens:
				issues.append(
					ShantyLintIssue.error(
						ShantyLint.RULE_TOKEN_MISMATCH,
						(
							"names %s, but %s names %s"
							% [_listed(tokens), reference, _listed(reference_tokens)]
						),
						key,
						"",
						locale
					)
				)


## The speaker ids `text` names by `{name:}` token, sorted.
static func name_tokens(text: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	for found: RegExMatch in RegEx.create_from_string(NAME_TOKEN).search_all(text):
		ids.append(found.get_string(1))
	ids.sort()
	return ids


## Each of `keys` whose text in some locale runs past `cap` characters, markup
## tags not counted. A warning: the bar wraps, it only reads worse.
static func check_length(
	document: ShantyCsvDocument, keys: PackedStringArray, cap: int, issues: Array[ShantyLintIssue]
) -> void:
	if cap <= 0:
		return
	for key: String in keys:
		for locale: String in document.locales():
			var length: int = (
				RegEx
				. create_from_string(MARKUP_TAG)
				. sub(document.text(key, locale), "", true)
				. length()
			)
			if length > cap:
				issues.append(
					ShantyLintIssue.warning(
						ShantyLint.RULE_LENGTH,
						"%d characters, over the cap of %d" % [length, cap],
						key,
						"",
						locale
					)
				)


## `text` lower-cased, with every typographic apostrophe read as `'`.
static func _comparable(text: String) -> String:
	return text.to_lower().replace(TYPOGRAPHIC_APOSTROPHE, APOSTROPHE)


## `text` without its markup tags and `{name:}` tokens.
static func plain_text(text: String) -> String:
	var without_tokens: String = RegEx.create_from_string(NAME_TOKEN).sub(text, " ", true)
	return RegEx.create_from_string(MARKUP_TAG).sub(without_tokens, "", true)


static func _check_known(
	tokens: PackedStringArray,
	speaker_ids: PackedStringArray,
	key: String,
	locale: String,
	issues: Array[ShantyLintIssue]
) -> void:
	for id: String in tokens:
		if not speaker_ids.is_empty() and not speaker_ids.has(id):
			issues.append(
				ShantyLintIssue.warning(
					ShantyLint.RULE_UNKNOWN_TOKEN,
					"{name:%s} names no speaker in the speakers folder" % id,
					key,
					"",
					locale
				)
			)


static func _listed(tokens: PackedStringArray) -> String:
	return "nobody" if tokens.is_empty() else ", ".join(tokens)


## `literal` with every regular-expression metacharacter escaped.
static func escape_regex(literal: String) -> String:
	var escaped: String = ""
	for character: String in literal:
		escaped += ("\\" + character) if "\\.^$|?*+()[]{}".contains(character) else character
	return escaped
