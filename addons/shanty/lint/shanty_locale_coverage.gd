@tool
class_name ShantyLocaleCoverage
extends RefCounted

## How much of one locale column is written: a report, never a verdict. An
## empty cell is allowed at save; whether a missing locale fails anything is
## the host's rule.

var locale: String = ""
var filled: int = 0
var total: int = 0
## The keys whose cell in this locale is empty, in file order.
var empty_keys: PackedStringArray = []


func is_complete() -> bool:
	return filled == total


## `en 12/12`, the strip's spelling.
func summary() -> String:
	return "%s %d/%d" % [locale, filled, total]
