class_name PanStep
extends CutsceneStep

## Slides the backdrop still from one offset to another over a duration. The
## offsets are in the still's own pixels, measured from where the player centres
## it, and the slide moves in whole art pixels only -- at any integer scale a
## half-pixel step would shimmer every edge in the picture.
##
## A reader who asked for reduced motion gets the end of the pan at once.

## Where the still starts, in art pixels from centre. Positive x moves it right.
@export var from_offset: Vector2i = Vector2i.ZERO
## Where the still comes to rest, in art pixels from centre.
@export var to_offset: Vector2i = Vector2i.ZERO
## Seconds. Zero cuts to `to_offset`.
@export_range(0.0, 30.0, 0.05) var duration: float = 2.0


func begin(player: CutscenePlayer) -> void:
	player.pan_backdrop(from_offset, to_offset, duration, completed.emit)


func skip_to_end(player: CutscenePlayer) -> void:
	player.pan_backdrop(to_offset, to_offset, 0.0, completed.emit)
