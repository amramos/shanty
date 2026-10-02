@tool
class_name ShantyLintText
extends RefCounted

## The lint rules that read the CSV's cells: the file's own shape, flag words,
## `{name:}` tokens and length. Pure; `ShantyLint` runs them with the rules
## that read the authored resources.

const NAME_TOKEN: String = "\\{name:([^}]*)\\}"
const MARKUP_TAG: String = "\\[/?hl\\]"
## A letter, digit or underscore on either side means the word is part of a
## longer one. Written with Unicode classes so accented letters count.
const WORD_EDGE_BEFORE: String = "(?<![\\p{L}\\p{N}_])"
const WORD_EDGE_AFTER: String = "(?![\\p{L}\\p{N}_])"


## Duplicate keys and rows the importer would drop for their width.
static func check_shape(document: ShantyCsvDocument, issues: Array[ShantyLintIssue]) -> void:
	for key: String in document.duplicate_keys():
		issues.append(
			ShantyLintIssue.error(
				ShantyLint.RULE_DUPLICATE_KEY,
				"the key is on more than one row; the importer keeps only the last",
				key
			)
		)
	for key: String in document.width_mismatches():
		issues.append(
			ShantyLintIssue.error(
				ShantyLint.RULE_ROW_WIDTH,
				(
					"the row does not have exactly %d cells, so the importer drops it"
					% document.header().size()
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
## list order. `{name:}` tokens and markup tags are not text.
static func forbidden_words_in(text: String, words: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = []
	if text.is_empty():
		return found
	var plain: String = plain_text(text)
	for word: String in words:
		if word.strip_edges().is_empty():
			continue
		var pattern: String = (
			"(?i)" + WORD_EDGE_BEFORE + escape_regex(word.strip_edges()) + WORD_EDGE_AFTER
		)
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
