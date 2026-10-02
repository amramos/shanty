@tool
extends RefCounted

## Colours the Shanty tab borrows from the editor's own theme, so it reads as
## part of the editor in any editor theme. No `class_name`: only the tab's own
## scripts reach it, through `preload()`.

const FALLBACK_WARNING: Color = Color(1.0, 0.8, 0.35)
const FALLBACK_ERROR: Color = Color(1.0, 0.45, 0.45)
const FALLBACK_SUCCESS: Color = Color(0.45, 0.85, 0.55)
const FALLBACK_MUTED: Color = Color(0.6, 0.6, 0.6)


static func warning() -> Color:
	return _editor_colour(&"warning_color", FALLBACK_WARNING)


static func error() -> Color:
	return _editor_colour(&"error_color", FALLBACK_ERROR)


static func success() -> Color:
	return _editor_colour(&"success_color", FALLBACK_SUCCESS)


static func muted() -> Color:
	return _editor_colour(&"font_disabled_color", FALLBACK_MUTED)


## A small label in `colour`, for keys and states under a cell.
static func caption(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_font_size_override(&"font_size", 11)
	return label


static func _editor_colour(name: StringName, fallback: Color) -> Color:
	var theme: Theme = EditorInterface.get_editor_theme()
	if theme == null or not theme.has_color(name, &"Editor"):
		return fallback
	return theme.get_color(name, &"Editor")


## Writes a key's state under its cell: `KEY · key ok`, or the first finding
## about it in the colour of its severity, every finding in the tooltip.
static func show_key_state(label: Label, key: String, issues: Array[ShantyLintIssue]) -> void:
	var found: Array[ShantyLintIssue] = ShantyLint.for_key(issues, key)
	if found.is_empty():
		label.text = "%s · key ok" % key
		label.add_theme_color_override(&"font_color", success())
		label.tooltip_text = ""
		return
	var worst: ShantyLintIssue = found[0]
	var lines: PackedStringArray = []
	for issue: ShantyLintIssue in found:
		lines.append(issue.describe())
		if issue.is_error() and not worst.is_error():
			worst = issue
	label.text = "%s · %s" % [key, worst.message]
	label.add_theme_color_override(&"font_color", error() if worst.is_error() else warning())
	label.tooltip_text = "\n".join(lines)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
