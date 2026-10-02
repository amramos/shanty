extends ShantyContext

## The example host's world: a dictionary of story flags, nothing more. A real
## host answers the same two questions over its own state -- a save file, a
## quest log -- and Shanty never learns which.
##
## No `class_name`, on purpose, in every example script: a vendored addon must
## not spend global class names a host's own code may want. The example's
## scripts reach each other through `preload()` constants instead.

## Flag -> set. A flag never written reads as unset.
var flags: Dictionary[StringName, bool] = {}
## Which chapter of the host's counting this is; recorded on every played scene.
var chapter: int = 1


func has_key(id: StringName) -> bool:
	return flags.get(id, false)


func playthrough_ordinal() -> int:
	return chapter


func set_flag(id: StringName, value: bool) -> void:
	flags[id] = value
