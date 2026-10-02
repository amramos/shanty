class_name ShantyCondition
extends Resource

## A gate on a line or a candidate, evaluated against the host's context.
## Subclass and override `evaluate()`; the base always holds, so an empty
## subclass never hides content by accident.


func evaluate(_context: ShantyContext) -> bool:
	return true


## True when every condition in `conditions` holds. Null entries are ignored
## rather than failing, so a half-authored array never silences a line.
static func all_hold(conditions: Array[ShantyCondition], context: ShantyContext) -> bool:
	for condition: ShantyCondition in conditions:
		if condition != null and not condition.evaluate(context):
			return false
	return true
