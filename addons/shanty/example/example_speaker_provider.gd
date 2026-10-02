extends ShantySpeakerProvider

## The example's two speakers, read from their authored definitions, with a
## placeholder face drawn in code for each -- so the portrait path shows without
## any art files. A face the definition does draw wins over the placeholder; a
## speaker with no face at all would get the flat name plate instead.
##
## Any other id resolves through the base provider: a stand-in named by its id,
## loud on screen rather than silent.

const SPEAKERS: Array[SpeakerDefinition] = [
	preload("res://addons/shanty/example/speaker_keeper.tres"),
	preload("res://addons/shanty/example/speaker_visitor.tres"),
]
## Placeholder face size, in art pixels.
const FACE_SIZE: int = 48
const FACE_BORDER: int = 2
const FACE_BORDER_COLOUR: Color = Color.BLACK
## One flat colour per speaker, so the two are told apart at a glance.
const FACE_COLOURS: Dictionary[StringName, Color] = {
	&"keeper": Color8(138, 109, 58),
	&"visitor": Color8(163, 168, 136),
}

var _definitions: Dictionary[StringName, SpeakerDefinition] = {}
var _placeholders: Dictionary[StringName, Texture2D] = {}


func _init() -> void:
	for definition: SpeakerDefinition in SPEAKERS:
		if definition != null and not definition.speaker_id.is_empty():
			_definitions[definition.speaker_id] = definition


func resolve(speaker_id: StringName) -> ShantySpeaker:
	var definition: SpeakerDefinition = _definitions.get(speaker_id, null)
	if definition == null:
		return super.resolve(speaker_id)
	var speaker: ShantySpeaker = ShantySpeaker.from_definition(definition)
	for face: SpeakerFace in definition.faces:
		if face != null and face.texture == null:
			speaker.add_face(face.tag, _placeholder(speaker_id))
	return speaker


func _placeholder(speaker_id: StringName) -> Texture2D:
	if _placeholders.has(speaker_id):
		return _placeholders[speaker_id]
	var image := Image.create_empty(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(FACE_BORDER_COLOUR)
	var inner := Rect2i(
		FACE_BORDER, FACE_BORDER, FACE_SIZE - FACE_BORDER * 2, FACE_SIZE - FACE_BORDER * 2
	)
	image.fill_rect(inner, FACE_COLOURS.get(speaker_id, FACE_BORDER_COLOUR))
	var texture := ImageTexture.create_from_image(image)
	_placeholders[speaker_id] = texture
	return texture
