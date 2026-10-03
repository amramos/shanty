@tool
class_name ShantySpeakerEdits
extends RefCounted

## Edits to speakers, over a `ShantyEditorModel`. A speaker's display name is a
## key in the same CSV as every line, so it gets the same source and target
## cells, the same coverage and the same Save.

const ID_PATTERN: String = "^[a-z0-9_]+$"


## The speaker with `id`, or null.
static func find(model: ShantyEditorModel, id: StringName) -> SpeakerDefinition:
	for speaker: SpeakerDefinition in model.speakers:
		if speaker.speaker_id == id:
			return speaker
	return null


## Every speaker id, in list order.
static func ids(model: ShantyEditorModel) -> PackedStringArray:
	var found: PackedStringArray = []
	for speaker: SpeakerDefinition in model.speakers:
		found.append(String(speaker.speaker_id))
	return found


## The face tags of the speaker with `id`; empty for an unknown speaker.
static func face_tags(model: ShantyEditorModel, id: StringName) -> PackedStringArray:
	var tags: PackedStringArray = []
	var speaker: SpeakerDefinition = find(model, id)
	if speaker != null:
		for face: SpeakerFace in speaker.faces:
			if face != null:
				tags.append(String(face.tag))
	return tags


## A new speaker saved as `<speakers folder>/<id>.tres`, its name key named by
## the scheme and given a row beside the other speakers' names. Null, changing
## nothing and with `model.refusal` saying why, for an id that is not
## lower-case `a-z0-9_` or is taken, a file that exists or that anything else
## this session claimed (`ShantyEditorModel.new_path()`), and with no config.
static func add_speaker(model: ShantyEditorModel, id: String) -> SpeakerDefinition:
	if not model.accepts_id(id, ID_PATTERN):
		return null
	var path: String = model.new_path(
		"speaker", model.config.speakers_folder, id, find(model, StringName(id)) != null
	)
	if path.is_empty():
		return null
	var speaker := SpeakerDefinition.new()
	speaker.speaker_id = StringName(id)
	speaker.name_key = model.config.scheme().speaker_key(id)
	_ensure_row(model, speaker.name_key)
	model.speakers.append(speaker)
	model.adopt(speaker, path)
	return speaker


## Points the speaker at another name key, giving it a row when it has none.
## A key another speaker already uses is shared, not copied.
static func set_name_key(model: ShantyEditorModel, speaker: SpeakerDefinition, key: String) -> bool:
	if key.is_empty() or key.contains(","):
		return false
	_ensure_row(model, key)
	speaker.name_key = key
	model.touch(speaker)
	return true


## Adds a face with `tag`. False for an empty or repeated tag.
static func add_face(model: ShantyEditorModel, speaker: SpeakerDefinition, tag: String) -> bool:
	if tag.is_empty() or face_tags(model, speaker.speaker_id).has(tag):
		return false
	var face := SpeakerFace.new()
	face.tag = StringName(tag)
	var faces: Array[SpeakerFace] = speaker.faces
	faces.append(face)
	speaker.faces = faces
	model.touch(speaker)
	return true


static func remove_face(model: ShantyEditorModel, speaker: SpeakerDefinition, index: int) -> bool:
	if index < 0 or index >= speaker.faces.size():
		return false
	var faces: Array[SpeakerFace] = speaker.faces
	faces.remove_at(index)
	speaker.faces = faces
	model.touch(speaker)
	return true


## Renames a face's tag. Lines that named the old tag are not rewritten; the
## lint reports them.
static func set_face_tag(
	model: ShantyEditorModel, speaker: SpeakerDefinition, index: int, tag: String
) -> bool:
	if index < 0 or index >= speaker.faces.size() or tag.is_empty():
		return false
	if face_tags(model, speaker.speaker_id).has(tag):
		return false
	speaker.faces[index].tag = StringName(tag)
	model.touch(speaker)
	return true


## Sets a face's texture; null is allowed and draws the flat plate.
static func set_face_texture(
	model: ShantyEditorModel, speaker: SpeakerDefinition, index: int, texture: Texture2D
) -> bool:
	if index < 0 or index >= speaker.faces.size():
		return false
	speaker.faces[index].texture = texture
	model.touch(speaker)
	return true


static func _ensure_row(model: ShantyEditorModel, key: String) -> void:
	if model.document.has_key(key):
		return
	var names: PackedStringArray = []
	for speaker: SpeakerDefinition in model.speakers:
		names.append(speaker.name_key)
	model.add_row(key, model.document.last_of(names))
