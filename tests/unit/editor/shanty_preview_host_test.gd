extends GutTest

## The preview host Play opens, instanced headlessly with a request pointing at
## the example: it plays the scene through the real CutscenePlayer to its end
## -- with Shanty's default `ShantyPreviewHost` and with the example's own --
## prints every effect and the record, plays what a trigger chooses, and puts
## back the locale, highlight and strings it changed. A request is taken as it
## is read, so it plays once, and one that is incomplete or names the wrong
## kind of file is refused with its own reason.

const HOST_SCENE: PackedScene = preload("res://addons/shanty/editor/preview/preview_host.tscn")
const ROOT: String = "user://shanty_preview_host_test"
const REQUEST: String = ROOT + "/request.cfg"
## The example's folders and strings with no preview host named: the default.
const BARE_CONFIG: String = "res://tests/support/bare_preview_config.tres"
const EXAMPLE: String = "res://addons/shanty/example/"
const EXAMPLE_CONFIG: String = EXAMPLE + "shanty_config.tres"
const SCENE: String = EXAMPLE + "example_scene.tres"
const SCENE_ID: StringName = &"shanty_example_lamp"
## Seconds a playing may take from its first line to its end; a hang fails.
const TIME_LIMIT: float = 15.0
const STEP: float = 0.05


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)


func after_all() -> void:
	for file: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(file))
	DirAccess.remove_absolute(ROOT)


func _host(resource_path: String, config_path: String, locale: String = "en") -> Control:
	var request := ShantyPlay.new()
	request.resource_path = resource_path
	request.config_path = config_path
	request.locale = locale
	assert_eq(request.write(REQUEST), OK)
	return _open_host()


## The host over whatever is at `REQUEST` now.
func _open_host() -> Control:
	var host: Control = HOST_SCENE.instantiate()
	host.set(&"request_path", REQUEST)
	add_child_autofree(host)
	return host


func _caption(host: Control) -> String:
	return (host.get_node(^"%Caption") as Label).text


func _player(host: Control) -> CutscenePlayer:
	return host.call(&"player")


## Taps the bar every `STEP` seconds until `done` holds. False on a hang.
func _tap_until(host: Control, done: Callable) -> bool:
	var waited: float = 0.0
	while waited < TIME_LIMIT:
		if done.call():
			return true
		if _player(host) != null:
			_player(host).dialogue_view().handle_tap()
		await get_tree().create_timer(STEP).timeout
		waited += STEP
	return done.call()


## Plays to the question, takes reply `index`, and plays to the end.
func _play_through(host: Control, index: int) -> void:
	var offered: Callable = func() -> bool:
		return _player(host) != null and _player(host).dialogue_view().choice_buttons().size() == 2
	assert_true(await _tap_until(host, offered), "the question's replies are offered")
	if not offered.call():
		return
	_player(host).dialogue_view().choice_buttons()[index].pressed.emit()
	var finished: Callable = func() -> bool: return host.get(&"record") != null
	assert_true(await _tap_until(host, finished), "the scene reaches its end")


func _report(host: Control) -> String:
	return "\n".join(host.get(&"report") as PackedStringArray)


func test_the_default_host_plays_the_scene_to_its_end_and_prints_the_record() -> void:
	var host: Control = _host(SCENE, BARE_CONFIG)
	assert_eq((host.get(&"host") as ShantyPreviewHost).get_script(), ShantyPreviewHost)
	assert_not_null(_player(host), "the real player plays it")
	await _play_through(host, 0)

	var record: PlayedSceneRecord = host.get(&"record")
	assert_not_null(record)
	if record == null:
		return
	assert_eq(record.scene_id, SCENE_ID)
	var key: String = PlayedSceneRecord.choice_key(SCENE_ID, "SHANTY_EXAMPLE_LINE_3")
	assert_eq(record.choices.get(key, -1), 0)
	assert_string_contains(_report(host), "record {")
	assert_string_contains(_report(host), String(SCENE_ID))
	assert_string_contains(_report(host), "effect example_effect {flag: example_visitor_lit_lamp")
	var caption: Label = host.get_node(^"%Caption")
	assert_true(caption.visible)
	assert_eq(caption.text, "Played shanty_example_lamp. Press Escape or close.")
	assert_null(_player(host), "the player is freed once it has finished")


func test_the_example_host_plays_with_its_own_strings_context_and_locale() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	var host: Control = _host(SCENE, EXAMPLE_CONFIG, "pt_BR")
	var first_line: Callable = func() -> bool:
		return _player(host) != null and _player(host).dialogue_view().current_line() != null
	assert_true(await _tap_until(host, first_line), "a line is shown")
	var view: DialogueView = _player(host).dialogue_view()

	assert_eq(TranslationServer.get_locale(), "pt_BR", "the request's locale")
	assert_eq(view.current_line().text_key, "SHANTY_EXAMPLE_LINE_1", "the example's context")
	assert_false(view.line_text().contains("SHANTY_EXAMPLE"), "the example's strings, added")
	await _play_through(host, 1)
	assert_string_contains(_report(host), "example_keeper_lit_lamp")

	remove_child(host)
	assert_eq(TranslationServer.get_locale(), previous_locale, "the locale is put back")
	assert_eq(
		TranslationServer.translate("SHANTY_EXAMPLE_LINE_1"),
		"SHANTY_EXAMPLE_LINE_1",
		"and the strings it added are gone again"
	)


func test_a_trigger_plays_the_scene_it_chooses() -> void:
	var host: Control = _host(EXAMPLE + "example_trigger.tres", EXAMPLE_CONFIG)

	assert_string_contains(_report(host), "'lamp' chose 'shanty_example_lamp'.")
	assert_not_null(_player(host))


func test_with_no_request_it_says_so_and_plays_nothing() -> void:
	var host: Control = HOST_SCENE.instantiate()
	host.set(&"request_path", ROOT + "/nothing.cfg")
	add_child_autofree(host)

	assert_null(_player(host))
	assert_string_contains((host.get_node(^"%Caption") as Label).text, "Nothing to play")


func test_a_request_plays_once_and_a_second_launch_finds_nothing() -> void:
	var first: Control = _host(SCENE, EXAMPLE_CONFIG)

	assert_not_null(_player(first), "the first launch plays")
	assert_false(FileAccess.file_exists(REQUEST), "the request is taken as it is read")
	var second: Control = _open_host()
	assert_null(_player(second))
	assert_string_contains(_caption(second), "Nothing to play: no request")


func test_an_incomplete_request_is_refused_naming_what_it_lacks() -> void:
	for field: String in ShantyPlay.fields():
		var file := ConfigFile.new()
		file.set_value(ShantyPlay.SECTION, "resource_path", SCENE)
		file.set_value(ShantyPlay.SECTION, "locale", "en")
		file.set_value(ShantyPlay.SECTION, "config_path", EXAMPLE_CONFIG)
		file.erase_section_key(ShantyPlay.SECTION, field)
		file.save(REQUEST)
		var host: Control = _open_host()

		assert_null(_player(host), field)
		assert_string_contains(_caption(host), "names no %s" % field)


func test_a_request_outside_the_project_or_of_the_wrong_kind_is_refused() -> void:
	var cases: Dictionary[String, Array] = {
		"is not a res:// path": ["user://shanty_preview_host_test/scene.tres", EXAMPLE_CONFIG],
		"is not a canonical res:// path":
		[EXAMPLE + "../example/example_scene.tres", EXAMPLE_CONFIG],
		"does not exist": [EXAMPLE + "nowhere.tres", EXAMPLE_CONFIG],
		"is not a scene or a trigger": [EXAMPLE_CONFIG, EXAMPLE_CONFIG],
		"is not a ShantyProjectConfig": [SCENE, SCENE],
	}
	for reason: String in cases:
		var host: Control = _host(cases[reason][0], cases[reason][1])

		assert_null(_player(host), reason)
		assert_string_contains(_caption(host), reason)
