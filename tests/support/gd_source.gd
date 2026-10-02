extends RefCounted

## Reads GDScript source closely enough for the tests that guard what the addon
## asks of a host: the calls a script makes, their arguments, and the string
## values those arguments name once constants are followed. No `class_name`, as
## with every support script.
##
## **Resolution is deliberately narrow.** A string literal names itself; an
## identifier names whatever its `const`/`var` in the same script is initialised
## to; `SomeClass.NAME` names whatever `NAME` is in that global class's script.
## Anything else -- a parameter, a member of an object, a computed value -- names
## nothing, and the caller decides whether that is allowed.

const LITERAL_PATTERN: String = '^[&^]?"((?:[^"\\\\]|\\\\.)*)"$'
const TOKEN_PATTERN: String = (
	'[&^]?"(?:[^"\\\\]|\\\\.)*"' + "|[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*"
)
const MAX_DEPTH: int = 6


## `source` with every `#` comment removed -- a comment's words are not code,
## and a scan that read them would count a call a comment only names. Line
## breaks are kept, so offsets into lines still mean the same lines.
static func strip_comments(source: String) -> String:
	var lines: PackedStringArray = []
	for line: String in source.split("\n"):
		lines.append(_code_part(line))
	return "\n".join(lines)


## `line` up to its first `#` outside a string.
static func _code_part(line: String) -> String:
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if not quote.is_empty():
			if character == "\\":
				index += 1
			elif character == quote:
				quote = ""
		elif character == '"' or character == "'":
			quote = character
		elif character == "#":
			return line.substr(0, index)
		index += 1
	return line


## The one string value `expression` names when it is a single literal, or a
## single constant whose own initialiser is one -- followed as far as it goes.
## "" for anything constructed: a concatenation, a format, a call, a parameter.
static func resolve_single(expression: String, source: String, depth: int = 0) -> String:
	var text: String = expression.strip_edges()
	if depth > MAX_DEPTH:
		return ""
	var whole := RegEx.create_from_string("^(?:%s)$" % TOKEN_PATTERN)
	if whole.search(text) == null:
		return ""
	var literal: RegExMatch = RegEx.create_from_string(LITERAL_PATTERN).search(text)
	if literal != null:
		return literal.get_string(1)
	var parts: PackedStringArray = text.split(".")
	var owner_source: String = source if parts.size() == 1 else _global_class_source(parts[0])
	if parts.size() > 2:
		return ""
	var initialiser: String = _initialiser(owner_source, parts[parts.size() - 1])
	if initialiser.is_empty():
		return ""
	return resolve_single(initialiser, owner_source, depth + 1)


## Every call in `source` whose callee matches `callee_pattern` (a regex that
## ends just before the opening parenthesis), as its top-level arguments,
## stripped. Calls spanning several lines are read whole.
static func call_arguments(source: String, callee_pattern: String) -> Array[PackedStringArray]:
	var found_calls: Array[PackedStringArray] = []
	var callee := RegEx.create_from_string(callee_pattern + "\\(")
	for found: RegExMatch in callee.search_all(source):
		var open: int = found.get_end() - 1
		var close: int = matching_paren(source, open)
		if close < 0:
			continue
		found_calls.append(split_arguments(source.substr(open + 1, close - open - 1)))
	return found_calls


## The index of the parenthesis closing the one at `open`, skipping strings, or
## -1 when it never closes.
static func matching_paren(source: String, open: int) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = open
	while index < source.length():
		var character: String = source[index]
		if not quote.is_empty():
			if character == "\\":
				index += 1
			elif character == quote:
				quote = ""
		elif character == '"' or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## `text` split at the commas that are not inside brackets or strings.
static func split_arguments(text: String) -> PackedStringArray:
	var arguments: PackedStringArray = []
	var depth: int = 0
	var quote: String = ""
	var current: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\" and index + 1 < text.length():
				current += character
				index += 1
				character = text[index]
			elif character == quote:
				quote = ""
		elif character == '"' or character == "'":
			quote = character
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		elif character == "," and depth == 0:
			arguments.append(current.strip_edges())
			current = ""
			index += 1
			continue
		current += character
		index += 1
	if not current.strip_edges().is_empty():
		arguments.append(current.strip_edges())
	return arguments


## The right-hand side of every `<target> = ...` assignment in `source` whose
## target ends in `property` (so `node.property = ...` counts too), read whole
## when it is parenthesised across lines. Declarations (`var`/`const`) and
## comparisons (`==`) are not assignments.
static func assigned_values(source: String, property: String) -> PackedStringArray:
	var values: PackedStringArray = []
	var assignment := RegEx.create_from_string(
		"(?m)^[ \\t]*(?:[A-Za-z_][A-Za-z0-9_]*\\.)*%s[ \\t]*=(?!=)[ \\t]*" % property
	)
	for found: RegExMatch in assignment.search_all(source):
		var start: int = found.get_end()
		if source[start] == "(":
			var close: int = matching_paren(source, start)
			values.append(source.substr(start, close - start + 1))
		else:
			var line_end: int = source.find("\n", start)
			if line_end < 0:
				line_end = source.length()
			values.append(source.substr(start, line_end - start).strip_edges())
	return values


## The right-hand side of `source`'s assignment to `property` on its own node
## (no object before it), or "" when it makes none.
static func own_assignment(source: String, property: String) -> String:
	var own := RegEx.create_from_string("(?m)^[ \\t]*%s[ \\t]*=(?!=)[ \\t]*(.+)$" % property)
	var found: RegExMatch = own.search(source)
	return found.get_string(1).strip_edges() if found != null else ""


## Every string value `expression` names in `source`, following constants as
## the header describes. Empty when it names none.
static func resolve(expression: String, source: String, depth: int = 0) -> PackedStringArray:
	var names: PackedStringArray = []
	if depth > MAX_DEPTH:
		return names
	var token := RegEx.create_from_string(TOKEN_PATTERN)
	for found: RegExMatch in token.search_all(expression):
		for name: String in _resolve_token(found.get_string(), source, depth):
			if not names.has(name):
				names.append(name)
	return names


static func _resolve_token(token: String, source: String, depth: int) -> PackedStringArray:
	var literal: RegExMatch = RegEx.create_from_string(LITERAL_PATTERN).search(token)
	if literal != null:
		return PackedStringArray([literal.get_string(1)])
	var parts: PackedStringArray = token.split(".")
	if parts.size() == 1:
		var initialiser: String = _initialiser(source, parts[0])
		if initialiser.is_empty():
			return PackedStringArray()
		return resolve(initialiser, source, depth + 1)
	if parts.size() == 2:
		var class_source: String = _global_class_source(parts[0])
		var initialiser: String = _initialiser(class_source, parts[1])
		if initialiser.is_empty():
			return PackedStringArray()
		return resolve(initialiser, class_source, depth + 1)
	return PackedStringArray()


## What `name`'s `const` or `var` declaration in `source` is initialised to.
static func _initialiser(source: String, name: String) -> String:
	if source.is_empty():
		return ""
	var declaration := RegEx.create_from_string(
		"(?m)^(?:@export[^\\n]*?\\s)?(?:const|var)\\s+%s\\b[^=\\n]*=\\s*(.+)$" % name
	)
	var found: RegExMatch = declaration.search(source)
	return found.get_string(1).strip_edges() if found != null else ""


static func _global_class_source(name: String) -> String:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["class"]) == name:
			return FileAccess.get_file_as_string(String(entry["path"]))
	return ""
