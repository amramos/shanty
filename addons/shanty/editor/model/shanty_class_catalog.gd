@tool
class_name ShantyClassCatalog
extends RefCounted

## The host's subclasses of a Shanty base, for the tab's pickers: every global
## class whose chain of bases reaches `ShantyCondition`, `ShantyEffect` or
## `CutsceneStep`. The host's own conditions and effects appear the moment it
## declares them with `class_name`; nothing is registered by hand.

## Step types this version declares and does not build; never offered.
const UNBUILT_STEPS: PackedStringArray = ["AnimateStep", "VideoStep"]


## `{"class": StringName, "path": String}` for each concrete class that
## descends from `base`, sorted by name. `classes` defaults to the project's
## global class list; a test passes its own.
static func subclasses_of(base: StringName, classes: Array[Dictionary] = []) -> Array[Dictionary]:
	var listed: Array[Dictionary] = classes if not classes.is_empty() else _global_classes()
	var bases: Dictionary[StringName, StringName] = {}
	for entry: Dictionary in listed:
		bases[StringName(entry["class"])] = StringName(entry.get("base", &""))
	var found: Array[Dictionary] = []
	for entry: Dictionary in listed:
		var name: StringName = StringName(entry["class"])
		if name == base or bool(entry.get("is_abstract", false)):
			continue
		if UNBUILT_STEPS.has(String(name)) or not _descends(name, base, bases):
			continue
		found.append({"class": name, "path": String(entry["path"])})
	found.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left["class"]) < String(right["class"])
	)
	return found


static func _descends(
	name: StringName, base: StringName, bases: Dictionary[StringName, StringName]
) -> bool:
	var current: StringName = bases.get(name, &"")
	var steps: int = 0
	while not current.is_empty() and steps < bases.size() + 1:
		if current == base:
			return true
		current = bases.get(current, &"")
		steps += 1
	return false


static func _global_classes() -> Array[Dictionary]:
	var classes: Array[Dictionary] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes.append(entry)
	return classes
