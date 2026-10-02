class_name ShantyBackdrop
extends TextureRect

## The still behind a scene: drawn at the largest whole-number scale that fits
## the frame, centred, so every art pixel stays square, and moved by a PanStep
## in whole art pixels only. Whatever the still does not cover shows the
## player's ground colour -- a still narrower than the frame sits centred on it.

## Where the still sits relative to centre, in art pixels.
var _offset: Vector2i = Vector2i.ZERO
var _frame: Vector2 = Vector2.ZERO
var _pan_tween: Tween = null


## Shows `still` (null hides it) back at centre.
func show_still(still: Texture2D) -> void:
	_stop_pan()
	texture = still
	visible = still != null
	_offset = Vector2i.ZERO
	_place()


## Sizes and centres the still in a frame of `frame` UI pixels.
func layout(frame: Vector2) -> void:
	_frame = frame
	_place()


## UI pixels per art pixel at the current frame; 1 with no still.
func art_scale() -> float:
	if texture == null:
		return 1.0
	var art: Vector2 = texture.get_size()
	if art.x <= 0.0 or art.y <= 0.0:
		return 1.0
	return maxf(1.0, floorf(minf(_frame.x / art.x, _frame.y / art.y)))


func offset_pixels() -> Vector2i:
	return _offset


func is_panning() -> bool:
	return _pan_tween != null and _pan_tween.is_valid() and _pan_tween.is_running()


## Slides from `from` to `to` (art pixels from centre) over `seconds`, then
## calls `on_done`. `instant` -- reduced motion, a skip -- lands on `to` at once.
func pan(from: Vector2i, to: Vector2i, seconds: float, instant: bool, on_done: Callable) -> void:
	_stop_pan()
	if instant or seconds <= 0.0 or from == to or not is_inside_tree():
		_set_offset(to)
		on_done.call()
		return
	_set_offset(from)
	_pan_tween = create_tween()
	_pan_tween.tween_method(_pan_to.bind(Vector2(from), Vector2(to)), 0.0, 1.0, seconds)
	_pan_tween.finished.connect(on_done, CONNECT_ONE_SHOT)


## One frame of a pan, rounded to the art grid before it is drawn.
func _pan_to(progress: float, from: Vector2, to: Vector2) -> void:
	_set_offset(Vector2i(from.lerp(to, progress).round()))


func _set_offset(offset: Vector2i) -> void:
	_offset = offset
	_place()


func _stop_pan() -> void:
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


func _place() -> void:
	if texture == null:
		return
	var whole_scale: float = art_scale()
	size = texture.get_size() * whole_scale
	position = ((_frame - size) * 0.5).floor() + Vector2(_offset) * whole_scale
