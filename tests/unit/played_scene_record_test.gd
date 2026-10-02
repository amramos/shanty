extends GutTest

## PlayedSceneRecord's JSON shape: exact round-trip, tolerant of a hand-edited
## file the way every save record is.

const KEY: String = "arrival/DLG_ARRIVAL_03"


func _record() -> PlayedSceneRecord:
	var record := PlayedSceneRecord.new()
	record.scene_id = &"the_lamp_lit"
	record.playthrough_ordinal = 3
	record.place_id = &"town:north_gate"
	record.choices[KEY] = 1
	record.title_key = "TITLE"
	record.synopsis_key = "SYNOPSIS"
	record.remembered = true
	return record


func test_a_choice_key_names_the_conversation_and_the_line() -> void:
	assert_eq(PlayedSceneRecord.choice_key(&"arrival", "DLG_ARRIVAL_03"), KEY)
	assert_ne(
		PlayedSceneRecord.choice_key(&"first", "DLG_ASK"),
		PlayedSceneRecord.choice_key(&"second", "DLG_ASK"),
		"one text key in two conversations is two answers"
	)


func test_a_record_round_trips_through_its_dictionary() -> void:
	var original: PlayedSceneRecord = _record()

	var decoded := PlayedSceneRecord.from_dictionary(original.to_dictionary())

	assert_eq(decoded.scene_id, &"the_lamp_lit")
	assert_eq(decoded.playthrough_ordinal, 3)
	assert_eq(decoded.place_id, &"town:north_gate")
	assert_eq(decoded.choices.get(KEY, -1), 1)
	assert_eq(decoded.title_key, "TITLE")
	assert_eq(decoded.synopsis_key, "SYNOPSIS")
	assert_true(decoded.remembered)
	assert_eq(decoded.to_dictionary(), original.to_dictionary(), "a fixed point")


func test_a_record_survives_json_text() -> void:
	var text: String = JSON.stringify(_record().to_dictionary())

	var decoded := PlayedSceneRecord.from_dictionary(JSON.parse_string(text))

	assert_eq(decoded.to_dictionary(), _record().to_dictionary())
	assert_eq(typeof(decoded.playthrough_ordinal), TYPE_INT, "JSON's floats come back as ints")


func test_the_dictionary_holds_only_plain_json_types() -> void:
	var data: Dictionary = _record().to_dictionary()

	assert_eq(
		data.keys(),
		[
			"scene_id",
			"playthrough_ordinal",
			"place_id",
			"choices",
			"title_key",
			"synopsis_key",
			"remembered",
		]
	)
	assert_eq(typeof(data["scene_id"]), TYPE_STRING, "no StringName on disk")
	assert_eq(typeof(data["place_id"]), TYPE_STRING)
	var choices: Dictionary = data["choices"]
	assert_eq(choices.get_typed_key_builtin(), TYPE_STRING, "replies keyed by String")
	assert_eq(choices.get_typed_value_builtin(), TYPE_INT, "and indexed by int")
	var record: PlayedSceneRecord = _record()
	var copied: Dictionary = record.to_dictionary()["choices"]
	copied["edited"] = 9
	assert_false(record.choices.has("edited"), "a copy, never the record's own")


func test_wrong_types_fall_back_rather_than_fail() -> void:
	var decoded := PlayedSceneRecord.from_dictionary(
		{"scene_id": 7, "playthrough_ordinal": "two", "choices": {"A": "x", "B": 2, "3": 1}}
	)

	assert_eq(decoded.scene_id, &"")
	assert_eq(decoded.playthrough_ordinal, 0)
	assert_eq(decoded.place_id, &"", "a record written before places names none")
	assert_eq(decoded.title_key, "", "a record written before titles names none")
	assert_false(decoded.remembered)
	var expected: Dictionary[String, int] = {"B": 2, "3": 1}
	assert_eq(decoded.choices, expected, "only String -> number pairs survive")
	assert_eq(PlayedSceneRecord.from_dictionary({}).choices.size(), 0)


func test_the_unreleased_flat_key_is_read_without_failing() -> void:
	var decoded := PlayedSceneRecord.from_dictionary(
		{"scene_id": "arrival", "choices": {"DLG_ARRIVAL_03": 1, KEY: 0}}
	)

	assert_eq(decoded.scene_id, &"arrival", "the rest of the record still loads")
	assert_eq(decoded.choices.get(KEY, -1), 0, "the current shape is read")
	assert_eq(decoded.choices.get("DLG_ARRIVAL_03", -1), 1, "the flat key is kept, not fatal")


func test_a_scene_snapshot_copies_what_a_replay_list_shows() -> void:
	var scene := CutsceneDefinition.new()
	scene.title_key = "T"
	scene.synopsis_key = "S"
	scene.remembered = true
	var record := PlayedSceneRecord.new()

	record.snapshot_scene(scene)
	scene.remembered = false

	assert_eq([record.title_key, record.synopsis_key], ["T", "S"])
	assert_true(record.remembered, "as the scene stood when it played")
	record.snapshot_scene(null)
	assert_eq(record.title_key, "T", "no scene leaves the record as it was")
