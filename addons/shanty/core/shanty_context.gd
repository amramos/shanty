class_name ShantyContext
extends RefCounted

## What a condition may ask about the host's world. The host subclasses this
## over its own state; Shanty never reads that state directly, which is what
## keeps the runner pure and the addon independent of any one host.


## True when the host holds the story key `id`.
func has_key(_id: StringName) -> bool:
	return false


## The host's count of the playthrough, run or chapter being played; 0 when it
## has none. Recorded on every played scene.
func playthrough_ordinal() -> int:
	return 0
