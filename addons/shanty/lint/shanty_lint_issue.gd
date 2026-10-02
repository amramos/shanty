@tool
class_name ShantyLintIssue
extends RefCounted

## One finding of `ShantyLint`. An error blocks the tab's Save; a warning is
## shown and marked but never blocks anything.

enum Severity { ERROR, WARNING }

var severity: Severity = Severity.ERROR
## Which rule found it: one of the `ShantyLint.RULE_*` names.
var rule: StringName = &""
## The translation key it concerns, or "".
var key: String = ""
## The locale column it concerns, or "".
var locale: String = ""
## Where in the authored data: a resource path or id, and a line number.
var path: String = ""
var message: String = ""


static func error(
	rule_name: StringName,
	text: String,
	at_key: String = "",
	at_path: String = "",
	in_locale: String = ""
) -> ShantyLintIssue:
	return _make(Severity.ERROR, rule_name, text, at_key, at_path, in_locale)


static func warning(
	rule_name: StringName,
	text: String,
	at_key: String = "",
	at_path: String = "",
	in_locale: String = ""
) -> ShantyLintIssue:
	return _make(Severity.WARNING, rule_name, text, at_key, at_path, in_locale)


func is_error() -> bool:
	return severity == Severity.ERROR


## One line for a list: `error  missing_key  DLG_X_01: ...`.
func describe() -> String:
	var where: PackedStringArray = []
	for part: String in [path, key, locale]:
		if not part.is_empty():
			where.append(part)
	var level: String = "error" if is_error() else "warning"
	return "%s  %s  %s: %s" % [level, rule, " ".join(where), message]


static func _make(
	level: Severity,
	rule_name: StringName,
	text: String,
	at_key: String,
	at_path: String,
	in_locale: String
) -> ShantyLintIssue:
	var issue := ShantyLintIssue.new()
	issue.severity = level
	issue.rule = rule_name
	issue.message = text
	issue.key = at_key
	issue.path = at_path
	issue.locale = in_locale
	return issue
