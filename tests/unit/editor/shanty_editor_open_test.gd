extends GutTest

## Opening the config the project setting names: an empty setting, a missing
## file, a resource that is not a config and a config naming no CSV each come
## back as a typed problem and leave the model empty, never half-open; and a
## config made by Create config opens at once.

const Fixture := preload("res://tests/support/editor_fixture.gd")
const NEW_CONFIG: String = Fixture.ROOT + "/made/shanty_config.tres"
const SPEAKER_PATH: String = "res://addons/shanty/example/speaker_keeper.tres"


func before_each() -> void:
	Fixture.build()


func after_all() -> void:
	Fixture.remove()


## A model holding the fixture, so each refusal is seen to empty it.
func _open_model() -> ShantyEditorModel:
	var model: ShantyEditorModel = Fixture.open_model()
	assert_eq(model.problem, ShantyEditorModel.Problem.NONE)
	assert_eq(model.conversations.size(), 1, "the fixture is open before the refusal")
	return model


func _assert_empty(model: ShantyEditorModel) -> void:
	assert_null(model.config)
	assert_eq(model.locales(), PackedStringArray())
	assert_eq(model.speakers.size(), 0)
	assert_eq(model.conversations.size(), 0)
	assert_eq(model.source_locale, "")
	assert_false(model.is_dirty())
	assert_eq(model.lint().size(), 0, "linting an empty model finds nothing and does not crash")


func test_an_empty_setting_is_its_own_problem() -> void:
	var model: ShantyEditorModel = _open_model()

	assert_eq(model.open_path(""), ShantyEditorModel.Problem.NO_SETTING)
	assert_string_contains(model.status, ShantyProjectConfig.SETTING)
	_assert_empty(model)


func test_a_missing_file_is_its_own_problem() -> void:
	var model: ShantyEditorModel = _open_model()

	assert_eq(model.open_path("res://nowhere/config.tres"), ShantyEditorModel.Problem.NO_FILE)
	assert_string_contains(model.status, "res://nowhere/config.tres")
	_assert_empty(model)


func test_a_resource_that_is_not_a_config_is_its_own_problem() -> void:
	var model: ShantyEditorModel = _open_model()

	assert_eq(model.open_path(SPEAKER_PATH), ShantyEditorModel.Problem.NOT_A_CONFIG)
	assert_string_contains(model.status, "is not a ShantyProjectConfig")
	_assert_empty(model)


func test_a_config_naming_no_csv_opens_nothing() -> void:
	var model: ShantyEditorModel = _open_model()
	var config: ShantyProjectConfig = Fixture.config()
	config.csv_path = ""

	model.open(config)
	assert_eq(model.problem, ShantyEditorModel.Problem.NO_CSV_PATH)
	_assert_empty(model)


func test_nothing_can_be_made_without_a_config() -> void:
	var model := ShantyEditorModel.new()
	model.open_path("")

	assert_null(ShantySpeakerEdits.add_speaker(model, "ana"))
	assert_null(ShantyConversationEdits.add_conversation(model, "talk"))


func test_the_setting_defaults_to_the_example_inside_the_addon() -> void:
	assert_eq(ShantyProjectConfig.DEFAULT_PATH, "res://addons/shanty/example/shanty_config.tres")
	assert_true(FileAccess.file_exists(ShantyProjectConfig.DEFAULT_PATH))
	var model := ShantyEditorModel.new()
	assert_eq(model.open_path(ShantyProjectConfig.DEFAULT_PATH), ShantyEditorModel.Problem.NONE)


func test_a_created_config_opens_on_a_csv_save_will_create() -> void:
	DirAccess.make_dir_recursive_absolute(NEW_CONFIG.get_base_dir())
	assert_eq(ShantyFiles.create_config(NEW_CONFIG), OK)
	var model := ShantyEditorModel.new()

	assert_eq(model.open_path(NEW_CONFIG, true), ShantyEditorModel.Problem.NONE)
	assert_eq(
		model.config.csv_path, NEW_CONFIG.get_base_dir().path_join(ShantyProjectConfig.NEW_CSV_NAME)
	)
	assert_string_contains(model.status, "Save creates it")
	assert_not_null(ShantySpeakerEdits.add_speaker(model, "ana"), "its folders are usable")
	assert_true(model.save().saved)
	assert_true(FileAccess.file_exists(model.config.csv_path))
