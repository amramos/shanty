extends GutTest

## Play's model: the request the tab writes and the preview host reads, when
## Play is refused, how an effect is printed, and which `ShantyPreviewHost` a
## config gets -- the host's own, or Shanty's default with no code of the
## host's at all.

const Fixture := preload("res://tests/support/editor_fixture.gd")
const REQUEST: String = "user://shanty_play_test.cfg"
const EXAMPLE_HOST: String = "res://addons/shanty/example/example_preview_host.gd"
const SetFlagEffect := preload("res://addons/shanty/example/example_effect.gd")
const SCENE: String = "res://addons/shanty/example/example_scene.tres"
const CONFIG: String = "res://addons/shanty/example/shanty_config.tres"


func after_each() -> void:
	ShantyFiles.remove(REQUEST)


func after_all() -> void:
	Fixture.remove()


func test_a_request_round_trips_through_its_file() -> void:
	var request := ShantyPlay.new()
	request.resource_path = "res://story/opening.tres"
	request.locale = "pt_BR"
	request.config_path = "res://story/shanty_config.tres"
	assert_eq(request.write(REQUEST), OK)

	var read: ShantyPlay = ShantyPlay.read(REQUEST)
	assert_eq(read.resource_path, "res://story/opening.tres")
	assert_eq(read.locale, "pt_BR")
	assert_eq(read.config_path, "res://story/shanty_config.tres")


func test_no_file_reads_as_none_and_an_empty_request_names_what_it_lacks() -> void:
	assert_null(ShantyPlay.read(REQUEST))
	ShantyPlay.new().write(REQUEST)
	assert_eq(
		ShantyPlay.read(REQUEST).check(), "Nothing to play: the request names no resource_path."
	)


func test_a_field_the_file_does_not_hold_is_named_by_the_check() -> void:
	var file := ConfigFile.new()
	file.set_value(ShantyPlay.SECTION, "resource_path", SCENE)
	file.set_value(ShantyPlay.SECTION, "config_path", 7)
	file.save(REQUEST)

	assert_string_contains(ShantyPlay.read(REQUEST).check(), "names no locale")
	file.set_value(ShantyPlay.SECTION, "locale", "en")
	file.save(REQUEST)
	assert_string_contains(ShantyPlay.read(REQUEST).check(), "names no config_path", "not text")
	ShantyFiles.write_text(REQUEST, "[play\nnot a config file")
	assert_string_contains(ShantyPlay.read(REQUEST).check(), "not one the Shanty tab wrote")
	assert_engine_error("ConfigFile parse error")


func test_taking_a_request_removes_it() -> void:
	ShantyPlay.for_selection(load(SCENE), "en").write(REQUEST)

	assert_not_null(ShantyPlay.take(REQUEST))
	assert_false(FileAccess.file_exists(REQUEST))
	assert_null(ShantyPlay.take(REQUEST), "a replay finds nothing")


func test_each_path_must_be_a_canonical_res_path_of_its_kind() -> void:
	var cases: Dictionary[String, Array] = {
		"": [SCENE, CONFIG],
		"the config user://shanty_config.tres is not a res:// path":
		[SCENE, "user://shanty_config.tres"],
		"the scene or trigger C:/story/opening.tres is not a res:// path":
		["C:/story/opening.tres", CONFIG],
		"is not a res:// path; Play loads only the project's own files":
		["/abs/opening.tres", CONFIG],
		"the scene or trigger res://../outside.tres is not a canonical":
		["res://../outside.tres", CONFIG],
		"res://addons//shanty/example/example_scene.tres is not a canonical":
		["res://addons//shanty/example/example_scene.tres", CONFIG],
		"res://addons/shanty/./example/example_scene.tres is not a canonical":
		["res://addons/shanty/./example/example_scene.tres", CONFIG],
		"is not a canonical res:// path":
		["res://addons\\shanty\\example\\example_scene.tres", CONFIG],
		"the config res://nowhere/config.tres does not exist": [SCENE, "res://nowhere/config.tres"],
		"Refused: %s is not a scene or a trigger." % CONFIG: [CONFIG, CONFIG],
		"Refused: %s is not a ShantyProjectConfig." % SCENE: [SCENE, SCENE],
	}
	for expected: String in cases:
		var request := ShantyPlay.new()
		request.resource_path = cases[expected][0]
		request.config_path = cases[expected][1]
		request.locale = "en"
		var refusal: String = request.check()

		if expected.is_empty():
			assert_eq(refusal, "")
			assert_eq(request.target, load(SCENE) as Resource)
			assert_eq(request.config.resource_path, CONFIG)
		else:
			assert_string_contains(refusal, expected)
			assert_null(request.target, expected)


func test_play_is_refused_until_a_saved_scene_or_trigger_is_picked() -> void:
	var model: ShantyEditorModel = Fixture.open_model()
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(model, "opening")

	assert_string_contains(ShantyPlay.refusal(model, model.speakers[0]), "Pick a scene")
	assert_string_contains(ShantyPlay.refusal(model, scene), "Save first")
	assert_true(model.save().saved)
	assert_eq(ShantyPlay.refusal(model, scene), "")
	var trigger: StoryTriggerDefinition = ShantyTriggerEdits.add_trigger(model, "start")
	assert_string_contains(ShantyPlay.refusal(model, trigger), "Save first")
	assert_string_contains(ShantyPlay.refusal(ShantyEditorModel.new(), scene), "no Shanty config")


func test_a_request_for_the_selection_names_its_file_and_the_open_config() -> void:
	var scene: CutsceneDefinition = load("res://addons/shanty/example/example_scene.tres")
	var request: ShantyPlay = ShantyPlay.for_selection(scene, "fr")

	assert_eq(request.resource_path, scene.resource_path)
	assert_eq(request.locale, "fr")
	assert_eq(request.config_path, ShantyFiles.config_path())
	assert_eq(request.check(), "", "the tab's own request holds")


func test_an_effect_prints_as_its_type_and_values() -> void:
	var effect: ShantyEffect = SetFlagEffect.new()
	effect.set(&"flag", &"lamp_lit")

	assert_eq(ShantyPlay.describe(effect), "example_effect {flag: lamp_lit, value: true}")
	assert_eq(ShantyPlay.describe(null), "(none)")


func test_a_config_with_no_preview_host_gets_the_default() -> void:
	var config := ShantyProjectConfig.new()
	config.speakers_folder = "res://addons/shanty/example"
	var host: ShantyPreviewHost = ShantyPreviewHost.for_config(config)

	assert_eq(host.get_script(), ShantyPreviewHost)
	assert_eq(host.config, config)
	assert_false(host.make_context().has_key(&"example_lamp_dark"), "it holds nothing")
	assert_true(host.make_speaker_provider().resolve(&"keeper").known, "the speakers folder")
	assert_false(host.make_speaker_provider().resolve(&"nobody").known)
	assert_eq(host.make_records().size(), 0)
	assert_eq(host.make_translations().size(), 0)
	assert_eq(host.make_settings().text_speed_chars_per_second, 40.0)


func test_a_config_naming_a_preview_host_gets_it() -> void:
	var config := ShantyProjectConfig.new()
	config.preview_host_path = EXAMPLE_HOST
	var host: ShantyPreviewHost = ShantyPreviewHost.for_config(config)

	assert_eq((host.get_script() as Script).resource_path, EXAMPLE_HOST)
	assert_true(host.make_context().has_key(&"example_lamp_dark"), "the example's own context")
	assert_eq(host.make_translations().size(), 3, "the example's three locale columns")


func test_a_script_that_is_not_a_preview_host_falls_back_to_the_default() -> void:
	for path: String in [
		"res://addons/shanty/example/example_context.gd",
		"res://addons/shanty/example/example_host.gd",
		"res://nowhere/host.gd",
	]:
		var config := ShantyProjectConfig.new()
		config.preview_host_path = path

		assert_eq(ShantyPreviewHost.for_config(config).get_script(), ShantyPreviewHost, path)
	assert_push_warning("is not a ShantyPreviewHost")


func test_the_example_names_its_preview_host_and_its_moments() -> void:
	var config: ShantyProjectConfig = ShantyFiles.configured()

	assert_eq(config.preview_host_path, EXAMPLE_HOST)
	assert_eq(config.trigger_ids, PackedStringArray(["lamp", "chapter_start"]))
	assert_eq(config.highlight_colour.to_html(false), "eda12b", "the example host's own colour")
