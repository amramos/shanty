class_name ShantyText
extends RefCounted

## Turns a line's translation key into the BBCode the view draws. Writers mark
## words with one tag, `[hl]...[/hl]`, and the host decides once what colour a
## highlight is -- Shanty never knows the host's palette.
##
## **`[hl]` is the only markup a translation may carry.** Every other `[` is
## escaped, so a stray `[b]`, `[url=...]` or a literal bracket in a translator's
## text draws as the characters typed rather than as BBCode.
##
## **A speaker is named by token, never by spelling.** `{name:<speaker_id>}` in
## any text is replaced with what the host's ShantySpeakerProvider calls that
## speaker *now*, so a host that renames or erases a character changes every
## line and every title that names them at once, without touching a translation.

const HIGHLIGHT_OPEN: String = "[hl]"
const HIGHLIGHT_CLOSE: String = "[/hl]"
## RichTextLabel's escape for a literal `[`.
const ESCAPED_BRACKET: String = "[lb]"
## `{name:keeper}` -> the provider's display name for `keeper`.
## PCRE2 reads a brace that opens no quantifier as itself, so none is escaped.
const NAME_TOKEN_PATTERN: String = "{name:([^}]+)}"

## White until the host says otherwise.
static var _highlight_colour: Color = Color.WHITE


static func set_highlight_colour(colour: Color) -> void:
	_highlight_colour = colour


static func highlight_colour() -> Color:
	return _highlight_colour


## The translated text for `key` as safe BBCode: speaker tokens named through
## `provider` (the base provider, which knows nobody, when null), highlights
## mapped to a colour tag, everything else literal.
static func render(key: String, provider: ShantySpeakerProvider = null) -> String:
	return highlight(resolve_names(TranslationServer.translate(key), provider))


## `text` with every `{name:<speaker_id>}` replaced by that speaker's display
## name from `provider`. A null provider is the base one, which names a speaker
## by their id -- loud on screen, never silent.
static func resolve_names(text: String, provider: ShantySpeakerProvider = null) -> String:
	if not text.contains("{name:"):
		return text
	var source: ShantySpeakerProvider = (
		provider if provider != null else ShantySpeakerProvider.new()
	)
	var matcher := RegEx.create_from_string(NAME_TOKEN_PATTERN)
	var resolved: String = ""
	var cursor: int = 0
	for found: RegExMatch in matcher.search_all(text):
		resolved += text.substr(cursor, found.get_start() - cursor)
		resolved += source.resolve(StringName(found.get_string(1))).display_name
		cursor = found.get_end()
	return resolved + text.substr(cursor)


## `text` as safe BBCode: every `[` escaped, then the escaped `[hl]`/`[/hl]`
## restored as colour tags. Escaping first is exact, because after it every `[`
## is followed by `lb]`, so an escaped highlight tag can only have come from a
## real one.
static func highlight(text: String) -> String:
	var open: String = "[color=#%s]" % _highlight_colour.to_html(false)
	var safe: String = text.replace("[", ESCAPED_BRACKET)
	safe = safe.replace(ESCAPED_BRACKET + HIGHLIGHT_OPEN.substr(1), open)
	return safe.replace(ESCAPED_BRACKET + HIGHLIGHT_CLOSE.substr(1), "[/color]")


## What a reader sees of translated `text`: the highlight tags removed and
## every other bracket left as typed -- the same characters `render()` draws,
## for plain controls and length checks.
static func strip_tags(text: String) -> String:
	return text.replace(HIGHLIGHT_OPEN, "").replace(HIGHLIGHT_CLOSE, "")
