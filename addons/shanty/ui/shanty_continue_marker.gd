class_name ShantyContinueMarker
extends Control

## The small downward triangle at the end of a finished line: "press to go on".
## Drawn rather than typed, because a pixel face is not guaranteed to carry an
## arrow glyph. Takes the name plate's colour from the host theme.

const PLATE_VARIATION: StringName = &"ShantyName"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(8.0, 6.0)


func _draw() -> void:
	var colour: Color = get_theme_color(&"font_color", PLATE_VARIATION)
	var left: float = size.x - 8.0
	var top: float = floorf((size.y - 4.0) * 0.5)
	var points := PackedVector2Array(
		[Vector2(left, top), Vector2(left + 8.0, top), Vector2(left + 4.0, top + 4.0)]
	)
	draw_colored_polygon(points, colour)
