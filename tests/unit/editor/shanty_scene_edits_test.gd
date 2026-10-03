extends GutTest

## Scene edits over the model: a new scene's title and synopsis keys named by
## the scheme with their rows as one block; steps added, inserted, moved and
## removed without touching the others; a summary per step; and Save writing the
## scene and its rows, refused like any other file someone changed on disk.

const Fixture := preload("res://tests/support/editor_fixture.gd")
const BACKDROP: String = Fixture.STEPS + "backdrop_step.gd"
const FADE: String = Fixture.STEPS + "fade_step.gd"
const SAY: String = Fixture.STEPS + "say_step.gd"
const WAIT: String = Fixture.STEPS + "wait_step.gd"

var _model: ShantyEditorModel


func before_each() -> void:
	_model = Fixture.open_model()


func after_each() -> void:
	_model = null


func after_all() -> void:
	Fixture.remove()


func _types(scene: CutsceneDefinition) -> PackedStringArray:
	var types: PackedStringArray = []
	for step: CutsceneStep in scene.steps:
		types.append(ShantyLintStory.type_name(step))
	return types


func test_a_new_scene_has_its_title_and_synopsis_rows_as_one_block() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	ShantySceneEdits.add_scene(_model, "farewell")

	assert_eq(scene.title_key, "SCENE_TITLE_OPENING")
	assert_eq(scene.synopsis_key, "SCENE_SYNOPSIS_OPENING")
	assert_eq(_model.path_of(scene), Fixture.SCENES + "/opening.tres")
	assert_eq(
		_model.document.keys().slice(5),
		PackedStringArray(
			[
				"SCENE_TITLE_OPENING",
				"SCENE_SYNOPSIS_OPENING",
				"SCENE_TITLE_FAREWELL",
				"SCENE_SYNOPSIS_FAREWELL",
			]
		),
		"each scene's two rows sit together, after the scenes before it"
	)
	assert_null(ShantySceneEdits.add_scene(_model, "opening"), "a taken id is refused")
	assert_null(ShantySceneEdits.add_scene(_model, "Not An Id"))


func test_a_synopsis_comes_and_goes_with_its_row() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")

	assert_true(ShantySceneEdits.remove_key(_model, scene, &"synopsis_key"))
	assert_eq(scene.synopsis_key, "")
	assert_false(_model.document.has_key("SCENE_SYNOPSIS_OPENING"), "its unused row goes too")
	assert_true(ShantySceneEdits.add_key(_model, scene, &"synopsis_key"))
	assert_false(ShantySceneEdits.add_key(_model, scene, &"synopsis_key"), "it has one already")
	assert_eq(
		_model.document.keys().slice(5),
		PackedStringArray(["SCENE_TITLE_OPENING", "SCENE_SYNOPSIS_OPENING"]),
		"back beside its title"
	)


func test_steps_are_added_inserted_moved_and_removed_without_touching_the_others() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	var backdrop: CutsceneStep = ShantySceneEdits.add_step(_model, scene, BACKDROP)
	var fade_out: CutsceneStep = ShantySceneEdits.add_step(_model, scene, FADE)
	var say: CutsceneStep = ShantySceneEdits.insert_step_after(_model, scene, 0, SAY)
	var first: CutsceneStep = ShantySceneEdits.insert_step_after(_model, scene, -1, WAIT)

	assert_eq(_types(scene), PackedStringArray(["WaitStep", "BackdropStep", "SayStep", "FadeStep"]))
	assert_true(ShantySceneEdits.move_step(_model, scene, 0, 3))
	assert_eq(scene.steps, [backdrop, say, fade_out, first] as Array[CutsceneStep])
	assert_false(ShantySceneEdits.move_step(_model, scene, 0, 4), "nowhere to go")
	assert_true(ShantySceneEdits.remove_step(_model, scene, 1))
	assert_eq(scene.steps, [backdrop, fade_out, first] as Array[CutsceneStep])
	assert_false(ShantySceneEdits.remove_step(_model, scene, 3))


func test_a_step_that_is_not_a_built_step_is_refused() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")

	assert_null(ShantySceneEdits.add_step(_model, scene, Fixture.STEPS + "animate_step.gd"))
	assert_null(ShantySceneEdits.add_step(_model, scene, Fixture.STEPS + "video_step.gd"))
	assert_null(ShantySceneEdits.add_step(_model, scene, Fixture.CONDITION_SCRIPT))
	assert_null(ShantySceneEdits.insert_step_after(_model, scene, 5, FADE))
	assert_eq(scene.steps.size(), 0)


func test_each_step_is_summarised_from_its_values() -> void:
	var say := SayStep.new()
	assert_eq(ShantySceneEdits.summary(say), "Say: (no conversation)")
	say.conversation = _model.conversations[0]
	assert_eq(ShantySceneEdits.summary(say), "Say: talk")
	assert_eq(ShantySceneEdits.conversation_of(say), _model.conversations[0])
	var backdrop := BackdropStep.new()
	backdrop.letterbox = true
	assert_eq(ShantySceneEdits.summary(backdrop), "Backdrop: ground colour, letterbox")
	var fade := FadeStep.new()
	fade.to_black = false
	fade.duration = 0.5
	assert_eq(ShantySceneEdits.summary(fade), "Fade in 0.5 s")
	var wait := WaitStep.new()
	wait.uninterruptible = true
	assert_eq(ShantySceneEdits.summary(wait), "Wait 1 s, no tap")
	var pan := PanStep.new()
	pan.to_offset = Vector2i(16, 0)
	assert_eq(ShantySceneEdits.summary(pan), "Pan (0, 0) → (16, 0), 2 s")
	var music := MusicStep.new()
	assert_eq(ShantySceneEdits.summary(music), "Music: duck 12 dB, 0.5 s")
	music.mode = MusicStep.Mode.SWAP
	assert_eq(ShantySceneEdits.summary(music), "Music: silence")


func test_a_saved_scene_round_trips_with_its_rows_and_steps() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	ShantySceneEdits.add_step(_model, scene, BACKDROP)
	var say: SayStep = ShantySceneEdits.add_step(_model, scene, SAY) as SayStep
	say.conversation = _model.conversations[0]
	ShantySceneEdits.edit(_model, scene, &"remembered", true)
	_model.set_text("SCENE_TITLE_OPENING", "en", "The opening")
	var result: ShantySaveResult = _model.save()

	assert_true(result.saved, result.message)
	assert_true(result.resource_paths.has(Fixture.SCENES + "/opening.tres"))
	var reopened := ShantyEditorModel.new()
	reopened.open(Fixture.config(), true)
	var loaded: CutsceneDefinition = ShantySceneEdits.find(reopened, &"opening")
	assert_not_null(loaded)
	assert_true(loaded.remembered)
	assert_eq(_types(loaded), PackedStringArray(["BackdropStep", "SayStep"]))
	assert_eq(ShantySceneEdits.summary(loaded.steps[1]), "Say: talk")
	assert_eq(reopened.text("SCENE_TITLE_OPENING", "en"), "The opening")
	assert_eq(ShantyLint.errors_in(reopened.lint()), [] as Array[ShantyLintIssue])


func test_a_scene_changed_on_disk_refuses_the_save() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	assert_true(_model.save().saved)
	var theirs := CutsceneDefinition.new()
	theirs.scene_id = &"opening"
	theirs.skippable = false
	ResourceSaver.save(theirs, Fixture.SCENES + "/opening.tres")
	ShantySceneEdits.add_step(_model, scene, FADE)
	var result: ShantySaveResult = _model.save()

	assert_false(result.saved)
	assert_eq(result.stale_paths, PackedStringArray([Fixture.SCENES + "/opening.tres"]))
	assert_false(
		(
			(
				ResourceLoader.load(
					Fixture.SCENES + "/opening.tres", "", ResourceLoader.CACHE_MODE_IGNORE
				)
				as CutsceneDefinition
			)
			. skippable
		),
		"their file is left as they wrote it"
	)


func test_lint_marks_an_unplayable_scene_the_model_holds() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	scene.steps = [AnimateStep.new()] as Array[CutsceneStep]
	var rules: Array[StringName] = []
	for issue: ShantyLintIssue in ShantyLint.errors_in(_model.lint()):
		rules.append(issue.rule)

	assert_eq(rules, [ShantyLint.RULE_UNPLAYABLE_SCENE] as Array[StringName])


func test_a_new_scene_saying_a_new_conversation_names_its_file() -> void:
	var conversation: ConversationDefinition = ShantyConversationEdits.add_conversation(
		_model, "lamp_talk"
	)
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	var say: SayStep = ShantySceneEdits.add_step(_model, scene, SAY) as SayStep
	say.conversation = conversation
	assert_true(_model.save().saved)

	var text: String = ShantyFiles.read_text(Fixture.SCENES + "/opening.tres")
	assert_string_contains(text, 'path="%s/lamp_talk.tres"' % Fixture.CONVERSATIONS)
	assert_false(text.contains('ConversationDefinition" id='), "not a copy embedded in the scene")
	assert_eq(conversation.resource_path, Fixture.CONVERSATIONS + "/lamp_talk.tres")


func test_a_steps_still_and_conversation_are_set_through_the_model() -> void:
	var scene: CutsceneDefinition = ShantySceneEdits.add_scene(_model, "opening")
	ShantySceneEdits.add_step(_model, scene, BACKDROP)
	ShantySceneEdits.add_step(_model, scene, SAY)
	assert_true(_model.save().saved)
	var still: Texture2D = load("res://addons/shanty/editor/shanty_icon.svg")
	var talk: ConversationDefinition = _model.conversations[0]

	assert_true(ShantySceneEdits.set_step_property(_model, scene, 0, &"texture", still))
	assert_true(_model.is_dirty(), "the scene is marked edited")
	assert_true(ShantySceneEdits.set_step_property(_model, scene, 1, &"conversation", talk))
	assert_eq(ShantySceneEdits.summary(scene.steps[0]), "Backdrop: shanty_icon.svg")
	assert_eq(ShantySceneEdits.summary(scene.steps[1]), "Say: talk")
	assert_false(ShantySceneEdits.set_step_property(_model, scene, 2, &"texture", still), "no step")
	assert_false(ShantySceneEdits.set_step_property(_model, scene, 1, &"texture", still))
	assert_false(
		ShantySceneEdits.set_step_property(_model, scene, 1, &"conversation", still),
		"a texture is no conversation"
	)
	assert_eq((scene.steps[1] as SayStep).conversation, talk, "a refusal changes nothing")
	assert_true(ShantySceneEdits.set_step_property(_model, scene, 0, &"texture", null), "cleared")
	ShantySceneEdits.set_step_property(_model, scene, 0, &"texture", still)
	assert_true(_model.save().saved)
	var reopened := ShantyEditorModel.new()
	reopened.open(Fixture.config(), true)
	var loaded: CutsceneDefinition = ShantySceneEdits.find(reopened, &"opening")
	assert_eq((loaded.steps[0] as BackdropStep).texture.resource_path, still.resource_path)
	assert_eq(ShantySceneEdits.summary(loaded.steps[1]), "Say: talk", "a reference to its file")
