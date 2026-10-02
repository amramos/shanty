class_name SpeakerFace
extends Resource

## One expression a speaker can wear, chosen by a line's `face` tag. The
## texture may be null while the art is unfinished: the view then draws a flat
## plate with the speaker's name rather than an empty frame.

## The emotion tag a `DialogueLine.face` names, e.g. `&"neutral"`, `&"wary"`.
@export var tag: StringName = &""
## The portrait itself. Null is tolerated, never an error.
@export var texture: Texture2D = null
