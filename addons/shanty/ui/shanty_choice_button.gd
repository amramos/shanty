class_name ShantyChoiceButton
extends Button

## One reply on the bar: a bordered box the host's theme styles through the
## `ShantyChoice` variation, with a small right-pointing triangle -- the "▸" --
## drawn in its left padding while it holds focus or the pointer. Drawn rather
## than typed for the reason ShantyContinueMarker gives: a pixel face is not
## guaranteed to carry the glyph (many do not).
##
## The triangle takes the focused text colour, so the box, the mark and the
## words light up together; its padding is the host's, read from the stylebox.

const VARIATION: StringName = &"ShantyChoice"
const MARKER_WIDTH: float = 4.0
const MARKER_HEIGHT: float = 8.0
## Space between the mark and the text it points at.
const MARKER_GAP: float = 6.0


func _init() -> void:
	theme_type_variation = VARIATION
	# Its text is set translated (for_choice()); never translated twice.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	# Hover moves the selection, so the mark is only ever on one reply.
	mouse_entered.connect(grab_focus)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## A button for `choice`, its text translated with speakers named through
## `provider` and highlight tags removed -- a button draws plain text.
static func for_choice(
	choice: DialogueChoice, provider: ShantySpeakerProvider
) -> ShantyChoiceButton:
	var button := ShantyChoiceButton.new()
	var key: String = choice.text_key if choice != null else ""
	button.text = ShantyText.strip_tags(
		ShantyText.resolve_names(TranslationServer.translate(key), provider)
	)
	return button


## Up and down cycle through `buttons` and nowhere else: left to the engine,
## focus would walk off the last reply into whatever the host draws beneath.
static func link_focus(buttons: Array[Button]) -> void:
	for index: int in buttons.size():
		var button: Button = buttons[index]
		var above: Button = buttons[(index - 1 + buttons.size()) % buttons.size()]
		var below: Button = buttons[(index + 1) % buttons.size()]
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
		button.focus_previous = button.get_path_to(above)
		button.focus_next = button.get_path_to(below)


func is_marked() -> bool:
	return has_focus() or is_hovered()


func _draw() -> void:
	if not is_marked():
		return
	var padding: float = get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)
	var left: float = maxf(1.0, padding - MARKER_GAP - MARKER_WIDTH)
	var top: float = floorf((size.y - MARKER_HEIGHT) * 0.5)
	var points := PackedVector2Array(
		[
			Vector2(left, top),
			Vector2(left + MARKER_WIDTH, top + MARKER_HEIGHT * 0.5),
			Vector2(left, top + MARKER_HEIGHT),
		]
	)
	draw_colored_polygon(points, get_theme_color(&"font_focus_color"))
