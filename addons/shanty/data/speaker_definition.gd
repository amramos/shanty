class_name SpeakerDefinition
extends Resource

## An authored speaker: a stable id the lines name, a translation key for the
## name shown on the plate, and the faces a line may ask for. A face a line
## names that is not here falls back to the first face (ShantySpeaker).

@export var speaker_id: StringName = &""
## Translation key, never literal text.
@export var name_key: String = ""
@export var faces: Array[SpeakerFace] = []
## A theme type variation for this speaker's name plate. Empty means the view's
## default plate variation; the host's theme decides what either looks like.
@export var colour_variation: StringName = &""
