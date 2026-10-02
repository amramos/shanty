class_name VideoStep
extends CutsceneStep

## Video is an accepted step type that this version declares and does
## not build. CutscenePlayer refuses any scene holding one before it starts
## (`is_built()`), so authoring it by accident is loud rather than a silent gap.


func is_built() -> bool:
	return false


func begin(_player: CutscenePlayer) -> void:
	push_error("VideoStep is not built in this version of Shanty.")
	completed.emit()


func skip_to_end(player: CutscenePlayer) -> void:
	begin(player)
