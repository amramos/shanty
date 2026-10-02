class_name ShantySpeaker
extends RefCounted

## A speaker as the view draws it: a resolved display name, a face per tag and
## the theme variation for the name plate. Built by a ShantySpeakerProvider.

var display_name: String = ""
var colour_variation: StringName = &""
## False when the provider had no speaker by that id and made up a stand-in;
## the view will not hand a reply turn to a speaker nobody knows.
var known: bool = true
## tag -> texture, in authored order; the first entry is the fallback face.
var _faces: Dictionary[StringName, Texture2D] = {}
var _fallback_tag: StringName = &""


## A speaker from an authored definition, its name already translated.
static func from_definition(definition: SpeakerDefinition) -> ShantySpeaker:
	var speaker := ShantySpeaker.new()
	if definition == null:
		return speaker
	speaker.display_name = TranslationServer.translate(definition.name_key)
	speaker.colour_variation = definition.colour_variation
	for face: SpeakerFace in definition.faces:
		if face != null:
			speaker.add_face(face.tag, face.texture)
	return speaker


func add_face(tag: StringName, texture: Texture2D) -> void:
	if _faces.is_empty():
		_fallback_tag = tag
	_faces[tag] = texture


## The face for `tag`, or the first face when the tag is unknown or its
## texture is missing. Null only when the speaker has no drawn face at all.
func face_texture(tag: StringName) -> Texture2D:
	var texture: Texture2D = _faces.get(tag, null)
	if texture != null:
		return texture
	return _faces.get(_fallback_tag, null)
