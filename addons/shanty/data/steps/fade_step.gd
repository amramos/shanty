class_name FadeStep
extends CutsceneStep

## Fades the whole frame to the player's ground colour, or in from it.

## True fades out to the ground colour; false fades in from it (starting there).
## The ground colour is black unless the host's theme sets one
## (ShantyHostContract.FRAME_VARIATION).
@export var to_black: bool = true
## Seconds. Zero cuts.
@export_range(0.0, 10.0, 0.05) var duration: float = 0.6


func begin(player: CutscenePlayer) -> void:
	player.fade(to_black, duration, completed.emit)


func skip_to_end(player: CutscenePlayer) -> void:
	player.fade(to_black, 0.0, completed.emit)
