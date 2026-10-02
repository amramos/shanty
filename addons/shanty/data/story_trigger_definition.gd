class_name StoryTriggerDefinition
extends Resource

## The candidates for one host boundary (`chapter_start`, `level_completed`...).
## The host names the boundary; Shanty never decides when one happens.

@export var trigger_id: StringName = &""
@export var candidates: Array[StoryCandidate] = []
