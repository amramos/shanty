extends GutTest

## CutscenePlayer's steps over Shanty-only fixtures: a scene
## holding a step this version does not build is refused before it starts; a
## wait ends on a tap unless it may not; a pan moves on the art grid and jumps
## for reduced motion; and whatever a MusicStep changed is put back when the
## scene ends.

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")
const TEST_BUS: StringName = &"ShantyStepsTestBus"

var _player: CutscenePlayer
var _finished: Array = []


func before_each() -> void:
	_finished = []
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.finished.connect(
		func(record: PlayedSceneRecord, effects: Array[ShantyEffect]) -> void:
			_finished.append([record, effects])
	)


func _scene(steps: Array[CutsceneStep]) -> CutsceneDefinition:
	var scene := CutsceneDefinition.new()
	scene.scene_id = &"steps"
	scene.steps = steps
	return scene


func _texture(width: int, height: int) -> Texture2D:
	return ImageTexture.create_from_image(
		Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	)


func _tap() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		get_viewport().push_input(event)
		await wait_process_frames(1)


func test_a_scene_with_an_unbuilt_step_is_refused_before_it_starts() -> void:
	for unbuilt: CutsceneStep in [AnimateStep.new(), VideoStep.new()]:
		_finished.clear()
		var backdrop := BackdropStep.new()
		_player.play(_scene([backdrop, unbuilt]), null, null, null)

		assert_push_error("does not build")
		assert_eq(_finished.size(), 1, "finished at once, inside play()")
		assert_false(_player.is_running())
		if _finished.is_empty():
			continue
		var record: PlayedSceneRecord = _finished[0][0]
		assert_true(record.scene_id.is_empty(), "an empty record names no scene")
		assert_eq((_finished[0][1] as Array).size(), 0, "and carries no effects")
		assert_false(unbuilt.is_built())


func test_a_wait_ends_on_a_tap_unless_it_is_uninterruptible() -> void:
	var wait := WaitStep.new()
	wait.seconds = 20.0
	_player.play(_scene([wait]), null, null, null)
	await wait_process_frames(3)
	assert_true(_player.is_running(), "still waiting")
	await _tap()
	await wait_until(func() -> bool: return not _finished.is_empty(), 2.0)
	assert_eq(_finished.size(), 1, "a tap cut the wait short")

	_finished.clear()
	var held := WaitStep.new()
	held.seconds = 0.5
	held.uninterruptible = true
	_player.play(_scene([held]), null, null, null)
	await wait_process_frames(3)
	await _tap()
	await wait_process_frames(3)
	assert_true(_player.is_running(), "an uninterruptible wait ignores the tap")
	await wait_until(func() -> bool: return not _finished.is_empty(), 2.0)
	assert_eq(_finished.size(), 1, "and ends on its own time")


func test_a_pan_moves_in_whole_art_pixels_and_lands_where_it_was_told() -> void:
	var backdrop := BackdropStep.new()
	backdrop.texture = _texture(200, 120)
	var pan := PanStep.new()
	pan.from_offset = Vector2i(-30, 0)
	pan.to_offset = Vector2i(30, 4)
	pan.duration = 0.5
	_player.play(_scene([backdrop, pan]), null, null, null)
	var still: ShantyBackdrop = _player.backdrop()
	var scale: float = 0.0
	for _frame: int in range(12):
		await wait_process_frames(1)
		scale = still.art_scale()
		var centred: Vector2 = ((get_viewport().get_visible_rect().size - still.size) * 0.5).floor()
		var moved: Vector2 = (still.position - centred) / scale
		assert_eq(moved, moved.round(), "on the art grid at every frame")
	await wait_until(func() -> bool: return not _finished.is_empty(), 2.0)
	assert_eq(still.offset_pixels(), Vector2i(30, 4))


func test_reduced_motion_jumps_a_pan_to_its_end() -> void:
	var backdrop := BackdropStep.new()
	backdrop.texture = _texture(200, 120)
	var pan := PanStep.new()
	pan.from_offset = Vector2i(-30, 0)
	pan.to_offset = Vector2i(30, 0)
	pan.duration = 10.0
	var settings := ShantyViewSettings.new()
	settings.reduced_motion = true
	_player.play(_scene([backdrop, pan]), null, null, settings)
	await wait_until(func() -> bool: return not _finished.is_empty(), 1.0)
	assert_eq(_finished.size(), 1, "no ten-second pan")
	assert_eq(_player.backdrop().offset_pixels(), Vector2i(30, 0))


func test_reduced_motion_cuts_a_fade() -> void:
	var settings := ShantyViewSettings.new()
	settings.reduced_motion = true
	var fade := FadeStep.new()
	fade.duration = 5.0
	_player.play(_scene([fade] as Array[CutsceneStep]), null, null, settings)
	await wait_process_frames(3)

	assert_eq(_finished.size(), 1, "a five-second fade ended at once")
	var cover: ColorRect = _player.find_child("Fade", true, false)
	assert_eq(cover.modulate.a, 1.0, "on black, where the fade was going")


func test_a_narrow_still_is_centred_on_the_ground() -> void:
	var backdrop := BackdropStep.new()
	backdrop.texture = _texture(444, 360)
	_player.play(_scene([backdrop, WaitStep.new()]), null, null, null)
	await wait_process_frames(2)
	var still: ShantyBackdrop = _player.backdrop()
	var frame: Vector2 = get_viewport().get_visible_rect().size
	assert_almost_eq(still.position.x * 2.0 + still.size.x, frame.x, 1.0, "centred across")
	assert_eq(still.size, Vector2(444, 360) * still.art_scale(), "at a whole scale")


func test_a_duck_is_restored_when_the_scene_ends() -> void:
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, TEST_BUS)
	AudioServer.set_bus_volume_db(bus, -3.0)
	var duck := MusicStep.new()
	duck.duck_db = 12.0
	duck.duration = 0.0
	var wait := WaitStep.new()
	wait.seconds = 0.3
	wait.uninterruptible = true
	var settings := ShantyViewSettings.new()
	settings.music_bus = TEST_BUS
	_player.play(_scene([duck, wait]), null, null, settings)
	await wait_process_frames(3)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), -15.0, 0.01, "ducked")
	await wait_until(func() -> bool: return not _finished.is_empty(), 2.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), -3.0, 0.01, "restored at the end")
	AudioServer.remove_bus(bus)


func test_a_swap_is_restored_when_the_scene_ends() -> void:
	var music: AudioStreamPlayer = add_child_autofree(AudioStreamPlayer.new())
	var before := AudioStreamWAV.new()
	music.stream = before
	var swap := MusicStep.new()
	swap.mode = MusicStep.Mode.SWAP
	swap.stream = AudioStreamWAV.new()
	var wait := WaitStep.new()
	wait.seconds = 0.2
	wait.uninterruptible = true
	var settings := ShantyViewSettings.new()
	settings.music_player = music
	_player.play(_scene([swap, wait]), null, null, settings)
	await wait_process_frames(3)
	assert_eq(music.stream, swap.stream, "swapped for the scene")
	await wait_until(func() -> bool: return not _finished.is_empty(), 2.0)
	assert_eq(music.stream, before, "put back after it")
