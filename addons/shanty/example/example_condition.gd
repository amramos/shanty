extends ShantyCondition

## FlagCondition: holds when the host's context has `flag` set (or, with
## `expected` off, when it has not). The one condition the example needs; a real
## host writes one per question its writers ask.

@export var flag: StringName = &""
## False inverts the test: the condition holds while the flag is unset.
@export var expected: bool = true


func evaluate(context: ShantyContext) -> bool:
	return context.has_key(flag) == expected
