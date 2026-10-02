class_name WaitStep
extends CutsceneStep

## Holds the frame for a while -- a beat of black, a still left to be looked at.
## A tap ends the wait early unless it is authored `uninterruptible`; holding to
## skip the scene ends it either way, when the scene is skippable.

## Seconds.
@export_range(0.0, 30.0, 0.05) var seconds: float = 1.0
## When true a tap does not cut the wait short.
@export var uninterruptible: bool = false


func begin(player: CutscenePlayer) -> void:
	player.wait(seconds, not uninterruptible, completed.emit)


func skip_to_end(player: CutscenePlayer) -> void:
	player.end_wait()
	completed.emit()
