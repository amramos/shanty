class_name CutsceneDefinition
extends Resource

## A short scene: an ordered list of steps with an id the host records once the
## scene has finished. Played by CutscenePlayer.

@export var scene_id: StringName = &""
## Translation key for the scene's title, for a replay list.
@export var title_key: String = ""
## Whether the host's replay list keeps this scene once it has played. Off by
## default: a writer opts a scene into the book, so a bark-sized beat or a
## repeating one never crowds it.
@export var remembered: bool = false
## Optional translation key for one sentence a replay list shows under the
## title. Empty shows none. May name a speaker with `{name:<speaker_id>}`
## (ShantyText.resolve_names()).
@export var synopsis_key: String = ""
## When false the hold-to-skip affordance is not shown and holding does nothing.
@export var skippable: bool = true
@export var steps: Array[CutsceneStep] = []


## True when every step is one this version of Shanty builds
## (CutsceneStep.is_built()). CutscenePlayer refuses a scene that is not.
func is_playable() -> bool:
	for step: CutsceneStep in steps:
		if step != null and not step.is_built():
			return false
	return true
