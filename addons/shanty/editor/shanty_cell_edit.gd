@tool
extends LineEdit

## A translation cell. An empty cell is drawn as an empty dashed box -- the
## shape of a gap, never a badge or a word -- so a missing translation reads as
## room to write rather than as an error.

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const DASH: float = 4.0
const INSET: float = 1.0

var _empty_box: StyleBoxEmpty = StyleBoxEmpty.new()


func _ready() -> void:
	text_changed.connect(_on_text_changed.unbind(1))
	_on_text_changed()


func _draw() -> void:
	if not text.is_empty():
		return
	var colour: Color = Palette.muted()
	var box := Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)
	var corners: PackedVector2Array = [
		box.position,
		Vector2(box.end.x, box.position.y),
		box.end,
		Vector2(box.position.x, box.end.y),
	]
	for index: int in corners.size():
		draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], colour, 1.0, DASH)


## Sets the cell's text from the model, which `text_changed` does not report.
func show_text(value: String) -> void:
	text = value
	_on_text_changed()


func _on_text_changed() -> void:
	if text.is_empty():
		add_theme_stylebox_override(&"normal", _empty_box)
	else:
		remove_theme_stylebox_override(&"normal")
	queue_redraw()
