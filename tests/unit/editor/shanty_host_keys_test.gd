extends GutTest

## A CSV the tab sets up for itself: Create config writes one with `keys`, the
## config's source locale, `_flags`, `_notes` and the host contract's three
## keys in English; a CSV lacking those keys is told so on open and given them
## on request; and the first locale added to a CSV with none becomes the source.

const Fixture := preload("res://tests/support/editor_fixture.gd")
const MADE: String = Fixture.ROOT + "/made"
const NEW_CONFIG: String = MADE + "/shanty_config.tres"
const NEW_CSV: String = MADE + "/" + ShantyProjectConfig.NEW_CSV_NAME


func before_each() -> void:
	Fixture.build()
	DirAccess.make_dir_recursive_absolute(MADE)


func after_all() -> void:
	Fixture.remove()


func test_a_created_config_starts_its_csv_with_a_locale_and_the_host_keys() -> void:
	assert_eq(ShantyFiles.create_config(NEW_CONFIG), OK)
	var model := ShantyEditorModel.new()

	assert_eq(model.open_path(NEW_CONFIG, true), ShantyEditorModel.Problem.NONE)
	assert_eq(model.config.csv_path, NEW_CSV)
	assert_eq(model.status, "", "nothing is missing")
	assert_eq(model.document.header(), PackedStringArray(["keys", "en", "_flags", "_notes"]))
	assert_eq(model.source_locale, "en", "Source is the config's source_locale")
	assert_eq(ShantyHostKeys.missing(model.document), PackedStringArray())
	for key: String in ShantyHostContract.TRANSLATION_KEYS:
		assert_eq(model.text(key, "en"), ShantyHostContract.DEFAULT_TEXT[key], key)
	assert_false(model.is_dirty())


func test_a_created_config_keeps_a_csv_already_beside_it() -> void:
	ShantyFiles.write_text(NEW_CSV, "keys,fr\nMINE,à moi\n")

	assert_eq(ShantyFiles.create_config(NEW_CONFIG), OK)
	assert_eq(ShantyFiles.read_text(NEW_CSV), "keys,fr\nMINE,à moi\n")


func test_a_csv_lacking_the_host_keys_says_so_and_gets_them_on_request() -> void:
	var model: ShantyEditorModel = Fixture.open_model()
	var keys: PackedStringArray = ShantyHostContract.TRANSLATION_KEYS

	assert_eq(ShantyHostKeys.missing(model.document), keys)
	for key: String in keys:
		assert_string_contains(model.status, key)
	assert_eq(ShantyHostKeys.add(model), keys)
	assert_true(model.is_dirty())
	assert_eq(ShantyHostKeys.missing(model.document), PackedStringArray())
	assert_eq(ShantyHostKeys.add(model), PackedStringArray(), "a second time adds nothing")
	var all: PackedStringArray = model.document.keys()
	assert_eq(all.slice(all.size() - 3), keys, "one block, in the contract's order")
	assert_eq(model.text("SHANTY_HOLD_TO_SKIP", "en"), "Hold to skip")
	assert_eq(model.text("SHANTY_HOLD_TO_SKIP", "pt_BR"), "", "other locales are the host's")
	assert_eq(model.notes("SHANTY_READING_AGAIN"), ShantyHostKeys.NOTE)
	assert_true(model.save().saved)
	assert_string_contains(Fixture.csv_on_disk(), "\nSHANTY_READING_AGAIN,Reading again,,")
	assert_true(Fixture.csv_on_disk().begins_with(Fixture.CSV), "every other row as it was")


func test_host_keys_add_no_notes_column_a_csv_lacks() -> void:
	var csv: ShantyCsvDocument = ShantyCsvDocument.parse("keys,en_GB\nA,a\n")

	ShantyHostKeys.add_rows(csv)
	assert_eq(csv.header(), PackedStringArray(["keys", "en_GB"]))
	assert_eq(csv.text("SHANTY_READING_AGAIN", "en_GB"), "Reading again", "an English variant")
	assert_true(csv.to_text().begins_with("keys,en_GB\nA,a\n"))


func test_the_first_locale_added_to_a_csv_with_none_is_the_source() -> void:
	var config: ShantyProjectConfig = Fixture.config()
	ShantyFiles.write_text(Fixture.CSV_PATH, "keys,_notes\n")
	var model := ShantyEditorModel.new()
	model.open(config, true)

	assert_eq(model.source_locale, "")
	assert_eq(model.suggested_locale(), "en", "the config's source_locale is suggested")
	assert_true(model.add_locale("en"))
	assert_eq(model.source_locale, "en", "Source, not Target")
	assert_eq(model.target_locale, "")
	assert_eq(model.suggested_locale(), "")
	assert_true(model.add_locale("fr"))
	assert_eq(model.source_locale, "en")
	assert_eq(model.target_locale, "fr")


func test_the_source_dropdown_offers_the_configured_source_locale_first() -> void:
	var config: ShantyProjectConfig = Fixture.config()
	config.source_locale = "pt_BR"
	var model := ShantyEditorModel.new()
	model.open(config, true)

	assert_eq(model.locales(), PackedStringArray(["en", "pt_BR"]))
	assert_eq(model.source_choices(), PackedStringArray(["pt_BR", "en"]))
	assert_eq(model.source_locale, "pt_BR")


func test_every_host_key_has_default_text() -> void:
	var keys: Array = ShantyHostContract.DEFAULT_TEXT.keys()
	keys.sort()
	var published: Array = Array(ShantyHostContract.TRANSLATION_KEYS)
	published.sort()

	assert_eq(keys, published)
