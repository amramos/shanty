class_name SkipHold
extends VBoxContainer

## The hold-to-skip affordance: a caption and a thin bar that fills while the
## advance input is held. Shown from a skippable scene's first frame so the
## player knows the hold exists before needing it; absent from a scene authored
## `skippable = false`. Purely visual -- CutscenePlayer times the hold.

const HINT_VARIATION: StringName = &"ShantyHint"
const BAR_VARIATION: StringName = &"ShantySkipBar"

## Translation key for the caption. The host's catalogue defines it.
@export var label_key: String = "SHANTY_HOLD_TO_SKIP"

var _label: Label = null
var _bar: ProgressBar = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 3)
	_label = Label.new()
	_label.theme_type_variation = HINT_VARIATION
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_bar = ProgressBar.new()
	_bar.theme_type_variation = BAR_VARIATION
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.custom_minimum_size = Vector2(72.0, 4.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_apply_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null:
		_apply_text()


## 0 is empty, 1 is the moment the scene skips.
func set_progress(ratio: float) -> void:
	if _bar != null:
		_bar.value = clampf(ratio, 0.0, 1.0)


func progress() -> float:
	return _bar.value if _bar != null else 0.0


func _apply_text() -> void:
	_label.text = tr(label_key)
