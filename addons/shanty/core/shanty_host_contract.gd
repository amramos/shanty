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
