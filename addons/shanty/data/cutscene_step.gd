class_name CutsceneStep
extends Resource

## One step of a cutscene, and the abstract base every step type extends. The
## player runs steps in order, calling `begin()` and waiting for `completed`;
## when the player is skipped it calls `skip_to_end()` on the step in progress
## and on every step after it, and each must still emit `completed` once it has
## reached its end state.
##
## A step is authored data shared through the resource cache, so it keeps no
## state of its own between calls: whatever runs over time (a tween, a
## conversation, a wait) lives on the player, and the step only asks for it.
## Subclass to add a step type; `AnimateStep` and `VideoStep` are declared and
## deliberately unbuilt (`is_built()`).

## Emitted once the step has reached its end state, by either route.
signal completed


## Starts the step on `player`. Emits `completed` when done -- synchronously is
## allowed; the player tolerates it. The base completes at once and complains,
## so a step type that forgot to override this can never hang a scene.
func begin(_player: CutscenePlayer) -> void:
	push_error("CutsceneStep %s does not override begin()." % get_script().resource_path)
	completed.emit()


## False for a step type this version names but does not build (AnimateStep,
## VideoStep). CutscenePlayer refuses a whole scene that holds one, so a writer
## who authors it by accident sees an error rather than a scene with a hole.
func is_built() -> bool:
	return true


## Puts the step straight into its end state on `player` and emits `completed`.
## A step that owes the player a decision (a choice) may wait for it first.
func skip_to_end(player: CutscenePlayer) -> void:
	begin(player)
