class_name ShantyHostContract
extends RefCounted

## What a host provides so Shanty's screens look and read as the host intends.
## Every name here is looked up at runtime and a missing one degrades quietly --
## the engine's default look, a black ground, a raw key on screen -- so this list
## is the one place a host can check its theme and its catalogue against, and a
## new version that adds, renames or drops a name says so here first.
##
## **Theme items come from the project theme** (Project Settings > GUI > Theme >
## Custom). The cutscene player is a `CanvasLayer`, and a `CanvasLayer` does not
## inherit a parent Control's theme, so a theme set on the host's own scene does
## not reach it.

## Theme type variation -> the Control class whose items it styles. Declare each
## in the project theme as a variation of that class; any left undeclared draws
## with the engine's defaults.
const THEME_TYPE_VARIATIONS: Dictionary[StringName, StringName] = {
	&"ShantyBar": &"PanelContainer",
	&"ShantyPortrait": &"PanelContainer",
	&"ShantyName": &"Label",
	&"ShantyLine": &"RichTextLabel",
	&"ShantyChoice": &"Button",
	&"ShantyHint": &"Label",
	&"ShantySkipBar": &"ProgressBar",
	&"ShantyFrame": &"ColorRect",
}

## Every theme item Shanty's code reads by name, beyond what each control draws
## for itself, spelled as a theme `.tres` spells it: `<type>/<kind>/<item>`. With
## the variation declared on its base class, an item the theme leaves out is the
## base class's; the ground falls back to black.
const THEME_ITEMS: PackedStringArray = [
	# The reply button's box; its left margin sets where the drawn mark sits.
	"ShantyChoice/styles/normal",
	# The drawn mark beside the focused reply.
	"ShantyChoice/colors/font_focus_color",
	# The frame's ground (FRAME_GROUND_COLOR below).
	"ShantyFrame/colors/ground_color",
	# The continue marker, drawn in the name plate's text colour.
	"ShantyName/colors/font_color",
]

## The theme type and colour the cutscene frame's ground is drawn in: the ground
## behind a still, the letterbox bars, the fade, and -- at `FRAME_DIM_ALPHA` --
## the dim over the host's own screen while no still is up.
const FRAME_VARIATION: StringName = &"ShantyFrame"
const FRAME_GROUND_COLOR: StringName = &"ground_color"
## The ground when the host's theme declares none.
const FRAME_DEFAULT_GROUND: Color = Color(0.0, 0.0, 0.0)
const FRAME_DIM_ALPHA: float = 0.6

## Translation keys Shanty's own controls show. Each must be in the host's
## catalogue in every locale the host offers.
const TRANSLATION_KEYS: PackedStringArray = [
	# The caption under the hold-to-skip bar.
	"SHANTY_HOLD_TO_SKIP",
	# What stands in the line while the reply speaker's replies wait.
	"SHANTY_REPLY_PLACEHOLDER",
	# The caption a replay wears in the frame's top-right corner.
	"SHANTY_READING_AGAIN",
]

## The locale `DEFAULT_TEXT` is written in.
const DEFAULT_TEXT_LOCALE: String = "en"
## Each translation key's starting text, which the Shanty tab writes into a new
## CSV and adds to one that lacks the keys. A host's own wording, and every
## other locale, is the host's to write; nothing at runtime falls back to it.
const DEFAULT_TEXT: Dictionary[String, String] = {
	"SHANTY_HOLD_TO_SKIP": "Hold to skip",
	"SHANTY_REPLY_PLACEHOLDER": "…",
	"SHANTY_READING_AGAIN": "Reading again",
}
