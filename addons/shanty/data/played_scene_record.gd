class_name PlayedSceneRecord
extends RefCounted

## What a host remembers about a scene once it has finished: which scene, on
## which playthrough of the host's counting, and which reply was taken on each line
## that asked for one. Written at the scene's end, never its start, so a scene
## abandoned halfway plays again.
##
## It also keeps the scene's title, synopsis key and `remembered` flag as they
## were at that playing, so a replay list can name it from the record alone.
##
## Plain ids, strings, integers and one bool, so it round-trips through JSON
## exactly. The reader is tolerant the way a hand-editable save file needs: a wrong type
## falls back to the default rather than raising.

## Separates a conversation id from a line's text key in a choice key.
const CHOICE_KEY_SEPARATOR: String = "/"

var scene_id: StringName = &""
var playthrough_ordinal: int = 0
## Where the scene played, in the host's own naming -- a level, a town, a
## room. Empty when the host recorded none; a replay list then names only the
## playthrough. Shanty never interprets it.
var place_id: StringName = &""
## `choice_key(conversation, line)` -> index of the reply chosen there. Keyed by
## conversation as well as line, because one scene may hold several
## conversations and a text key is only unique within one of them.
##
## A key with no separator is the flat shape an unreleased build wrote. It is
## read and kept rather than rejected -- a save file is never refused for it --
## but it names no line any more, so a replay finds no answer under it.
var choices: Dictionary[String, int] = {}
## What a replay list shows for this playing, copied from the scene as it stood
## when it played (`snapshot_scene()`), so the entry outlives the scene: a scene
## file renamed, removed or no longer `remembered` still has its memory. Empty
## title and `remembered` false on a record written before they were kept.
var title_key: String = ""
var synopsis_key: String = ""
var remembered: bool = false


## The key a reply on line `text_key` of conversation `conversation_id` is
## recorded under. The one formula both the recorder and a replay use.
static func choice_key(conversation_id: StringName, text_key: String) -> String:
	return String(conversation_id) + CHOICE_KEY_SEPARATOR + text_key


## Copies from `scene` what a replay list needs, as the scene is at this playing.
func snapshot_scene(scene: CutsceneDefinition) -> void:
	if scene == null:
		return
	title_key = scene.title_key
	synopsis_key = scene.synopsis_key
	remembered = scene.remembered


static func from_dictionary(data: Dictionary) -> PlayedSceneRecord:
	var record := PlayedSceneRecord.new()
	var id: Variant = data.get("scene_id", "")
	if id is String or id is StringName:
		record.scene_id = StringName(id)
	var ordinal: Variant = data.get("playthrough_ordinal", 0)
	if ordinal is int or ordinal is float:
		record.playthrough_ordinal = int(ordinal)
	var place: Variant = data.get("place_id", "")
	if place is String or place is StringName:
		record.place_id = StringName(place)
	var title: Variant = data.get("title_key", "")
	if title is String:
		record.title_key = title
	var synopsis: Variant = data.get("synopsis_key", "")
	if synopsis is String:
		record.synopsis_key = synopsis
	var kept: Variant = data.get("remembered", false)
	if kept is bool:
		record.remembered = kept
	var stored: Variant = data.get("choices", {})
	if stored is Dictionary:
		var map: Dictionary = stored
		for key: Variant in map:
			var index: Variant = map[key]
			if key is String and (index is int or index is float):
				record.choices[key] = int(index)
	return record


func to_dictionary() -> Dictionary:
	var plain_choices: Dictionary = {}
	for key: String in choices:
		plain_choices[key] = choices[key]
	return {
		"scene_id": String(scene_id),
		"playthrough_ordinal": playthrough_ordinal,
		"place_id": String(place_id),
		"choices": plain_choices,
		"title_key": title_key,
		"synopsis_key": synopsis_key,
		"remembered": remembered,
	}
