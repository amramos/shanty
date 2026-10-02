class_name ShantySpeakerProvider
extends RefCounted

## Resolves a line's `speaker_id` into something the view can draw. The host
## subclasses it: authored speakers from its own data, generated characters
## from its own composer. The base knows nobody.


func resolve(speaker_id: StringName) -> ShantySpeaker:
	var unknown := ShantySpeaker.new()
	unknown.display_name = String(speaker_id)
	unknown.known = false
	return unknown
