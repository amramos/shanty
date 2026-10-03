extends GutTest

## The Shanty tab instantiated with no editor running, as a test runs it: it
## opens the configured project, and with no usable config it shows the empty
## state and says why, without touching `EditorInterface` or a null config.

const MAIN_SCREEN: PackedScene = preload("res://addons/shanty/editor/shanty_main_screen.tscn")
const Fixture := preload("res://tests/support/editor_fixture.gd")

var _saved_setting: Variant = null


func before_each() -> void:
	_saved_setting = ProjectSettings.get_setting(ShantyProjectConfig.SETTING)


func after_each() -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, _saved_setting)


func _started_screen() -> Control:
	var screen: Control = MAIN_SCREEN.instantiate()
	add_child_autofree(screen)
	screen.call(&"start")
	return screen


func test_the_tab_opens_the_configured_example_headlessly() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")

	assert_not_null(model.config)
	assert_eq(model.conversations.size(), 1)
	assert_string_contains((screen.get_node(^"%Status") as Label).text, "example_strings.csv")


func test_an_empty_setting_shows_the_empty_state_and_says_why() -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, "")
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")

	assert_null(model.config)
	var status: String = (screen.get_node(^"%Status") as Label).text
	assert_string_contains(status, "No Shanty config")
	assert_string_contains(status, "Create config")
	var hint: Label = screen.get_node(^"%Hint")
	assert_true(hint.visible)
	assert_string_contains(hint.text, "No Shanty config is open")
	var menu: PopupMenu = _config_menu(screen)
	assert_false(menu.is_item_disabled(0), "Create config… is offered")
	assert_true(menu.is_item_disabled(1), "there is no config to inspect")
	assert_true(menu.is_item_disabled(2), "nor a CSV to add host keys to")


func test_the_config_menu_offers_create_config_while_a_config_is_open() -> void:
	var screen: Control = _started_screen()
	var menu: PopupMenu = _config_menu(screen)

	assert_not_null((screen.call(&"model") as ShantyEditorModel).config)
	assert_eq(menu.get_item_text(0), "Create config…")
	assert_false(menu.is_item_disabled(0))
	assert_eq(menu.get_item_text(1), "Open config in Inspector")
	assert_false(menu.is_item_disabled(1))
	assert_eq(menu.get_item_text(2), "Add host keys")
	assert_false(menu.is_item_disabled(2))
	screen.call(&"_add_host_keys")
	assert_string_contains(
		(screen.get_node(^"%Status") as Label).text, "already has every host key"
	)


func _config_menu(screen: Control) -> PopupMenu:
	return (screen.get_node(^"%Toolbar") as Node).call(&"config_menu")


func test_requests_without_a_config_are_answered_not_crashed_on() -> void:
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, "res://nowhere/config.tres")
	var screen: Control = _started_screen()

	for kind: StringName in [&"speaker", &"conversation", &"scene", &"trigger"]:
		screen.call(&"_on_create_requested", kind, "ana")
	screen.call(&"_play")
	screen.call(&"_on_locale_requested", "de")
	screen.call(&"_save")
	screen.call(&"_open", true)

	assert_null((screen.call(&"model") as ShantyEditorModel).config)
	assert_string_contains((screen.get_node(^"%Status") as Label).text, "does not exist")


func test_each_kind_picked_shows_its_own_form_and_the_preview_follows() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	# The speaker form is left out: its texture picker exists only in the editor.
	var forms: Dictionary[String, Resource] = {
		"LineTable": model.conversations[0],
		"ScenePane": model.scenes[0],
		"TriggerPane": model.triggers[0],
	}
	for form: String in forms:
		screen.call(&"_select", forms[form])
		for other: String in forms:
			assert_eq((screen.get_node("%" + other) as Control).visible, other == form, "%s" % form)
		assert_false((screen.get_node(^"%SpeakerForm") as Control).visible)

	screen.call(&"_select", model.scenes[0])
	var line: RichTextLabel = (screen.get_node(^"%BarPreview").call(&"view") as Control).get_node(
		^"%Line"
	)
	assert_string_contains(line.text, "lamp", "a scene previews its first said line")
	model.set_text("SHANTY_EXAMPLE_LINE_1", "en", "Words typed a moment ago.")
	assert_eq(line.text, "Words typed a moment ago.", "the preview follows the typing")


func _tree(screen: Control) -> Tree:
	return screen.get_node(^"%List").get(&"_tree")


func _row_texts(screen: Control) -> PackedStringArray:
	var texts: PackedStringArray = []
	for section: TreeItem in _tree(screen).get_root().get_children():
		for item: TreeItem in section.get_children():
			texts.append(item.get_text(0))
	return texts


func _item_of(screen: Control, resource: Resource) -> TreeItem:
	for section: TreeItem in _tree(screen).get_root().get_children():
		for item: TreeItem in section.get_children():
			if item.get_metadata(0) == resource:
				return item
	return null


func test_an_id_changed_in_a_form_updates_its_row_and_the_free_ids_once() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	var trigger: StoryTriggerDefinition = model.triggers[0]
	screen.call(&"_pick", trigger)
	var list: Node = screen.get_node(^"%List")
	assert_eq(list.get(&"_free_trigger_ids"), PackedStringArray(["chapter_start"]))
	var root: TreeItem = _tree(screen).get_root()

	assert_true(ShantyTriggerEdits.set_id(model, trigger, "chapter_start"))
	model.touch(trigger)
	assert_same(_tree(screen).get_root(), root, "not refilled inside the edit")
	await wait_process_frames(1)

	assert_true(_row_texts(screen).has("chapter_start"), str(_row_texts(screen)))
	assert_false(_row_texts(screen).has("lamp"))
	assert_eq(list.get(&"_free_trigger_ids"), PackedStringArray(["lamp"]))
	assert_same(_tree(screen).get_selected().get_metadata(0), trigger, "the pick is kept")
	assert_false(screen.get(&"_list_refresh_queued"), "two edits, one refill, done")
	# The example's trigger is the cached resource other tests load: put it back.
	ShantyTriggerEdits.set_id(model, trigger, "lamp")


func test_a_pick_in_the_list_never_refills_it_synchronously() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	var root: TreeItem = _tree(screen).get_root()
	var item: TreeItem = _item_of(screen, model.scenes[0])

	item.select(0)

	assert_same(screen.get(&"_selected"), model.scenes[0], "the pick reached the tab")
	assert_same(_tree(screen).get_root(), root, "the tree was not cleared under its own signal")
	assert_true(is_instance_valid(item) and item.is_selected(0))
	await wait_process_frames(1)
	assert_same(_tree(screen).get_selected().get_metadata(0), model.scenes[0])


func test_play_is_refused_with_its_reason_while_edits_are_unsaved() -> void:
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	screen.call(&"_select", model.scenes[0])
	model.set_text("SHANTY_EXAMPLE_LINE_1", "en", "Unsaved.")
	screen.call(&"_play")

	assert_string_contains((screen.get_node(^"%Status") as Label).text, "Save first")


func test_a_save_refused_for_a_changed_file_offers_reload_beside_the_reason() -> void:
	var config_path: String = Fixture.ROOT + "/shanty_config.tres"
	ResourceSaver.save(Fixture.build(), config_path)
	ProjectSettings.set_setting(ShantyProjectConfig.SETTING, config_path)
	var screen: Control = _started_screen()
	var model: ShantyEditorModel = screen.call(&"model")
	var reload: Button = screen.get_node(^"%StatusReload")
	assert_false(reload.visible)
	model.set_text("DLG_TALK_02", "pt_BR", "Tchau.")
	ShantyFiles.write_text(Fixture.CSV_PATH, Fixture.CSV + "THEIRS,Theirs,,\n")
	screen.call(&"_save")

	assert_string_contains((screen.get_node(^"%Status") as Label).text, "changed on disk")
	assert_true(reload.visible, "Reload is offered where the reason is")
	reload.pressed.emit()
	assert_false(model.is_dirty(), "the unsaved edit is dropped")
	assert_true(model.document.has_key("THEIRS"), "and their change is read")
	assert_false(reload.visible)
	Fixture.remove()
