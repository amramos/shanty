extends GutTest

## The frame's ground colour is the host's: the ground, both letterbox bars, the
## fade and the dim take `ground_color` on the `ShantyFrame` theme type, read at
## ready and again when the theme changes, with the dim keeping its alpha. With
## no such colour in the theme they are black.
##
## **The route a host really takes is the project theme**, because the player is
## a `CanvasLayer` and a theme on a Control or Window above it does not reach the
## frame. The last two tests hold both halves of that: a theme on the tree's root
## Window stops at the layer, and a colour in the theme context every control
## falls back to -- where the project theme lives -- arrives. Godot exposes no
## setter for the project theme at runtime, so the test writes into the engine's
## default theme, which is the same global context one step further down, and
## takes the colour out again afterwards.

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")
const HOST_GROUND: Color = Color(0.2, 0.4, 0.6)
const OPAQUE_RECTS: PackedStringArray = ["Ground", "LetterboxTop", "LetterboxBottom", "Fade"]

var _wrote_default_theme: bool = false
var _root_theme_before: Theme = null
var _replaced_root_theme: bool = false


func after_each() -> void:
	if _wrote_default_theme:
		ThemeDB.get_default_theme().clear_color(
			ShantyHostContract.FRAME_GROUND_COLOR, ShantyHostContract.FRAME_VARIATION
		)
		_wrote_default_theme = false
	if _replaced_root_theme:
		get_tree().root.theme = _root_theme_before
		_replaced_root_theme = false


func _theme(colour: Color) -> Theme:
	var theme := Theme.new()
	theme.set_color(
		ShantyHostContract.FRAME_GROUND_COLOR, ShantyHostContract.FRAME_VARIATION, colour
	)
	return theme


func _rect(player: CutscenePlayer, node_name: String) -> ColorRect:
	return player.get_node(node_name) as ColorRect


func _assert_ground(player: CutscenePlayer, expected: Color) -> void:
	for node_name: String in OPAQUE_RECTS:
		var actual: Color = _rect(player, node_name).color
		assert_true(
			actual.is_equal_approx(expected), "%s is %s, not %s" % [node_name, expected, actual]
		)
	var dim: Color = _rect(player, "Dim").color
	var dimmed: Color = Color(expected, ShantyHostContract.FRAME_DIM_ALPHA)
	assert_true(dim.is_equal_approx(dimmed), "Dim is %s, not %s" % [dimmed, dim])


func test_without_a_theme_colour_the_ground_is_black() -> void:
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(player.ground_colour(), ShantyHostContract.FRAME_DEFAULT_GROUND)
	_assert_ground(player, Color.BLACK)


func test_the_hosts_theme_colour_is_read_at_ready() -> void:
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	_rect(player, "Ground").theme = _theme(HOST_GROUND)
	add_child_autofree(player)

	_assert_ground(player, HOST_GROUND)


func test_a_theme_changed_while_ready_recolours_the_frame() -> void:
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	_rect(player, "Ground").theme = _theme(HOST_GROUND)

	_assert_ground(player, HOST_GROUND)


func test_a_translucent_theme_colour_still_draws_an_opaque_ground() -> void:
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	_rect(player, "Ground").theme = _theme(Color(HOST_GROUND, 0.25))
	add_child_autofree(player)

	_assert_ground(player, HOST_GROUND)


func test_the_scene_itself_carries_only_the_neutral_default() -> void:
	var text: String = FileAccess.get_file_as_string(PLAYER_SCENE.resource_path)
	var colours := RegEx.create_from_string("(?m)^color = (Color\\([^)]*\\))$")
	var found: PackedStringArray = []
	for found_colour: RegExMatch in colours.search_all(text):
		found.append(found_colour.get_string(1))

	assert_eq(found.size(), 5, "ground, two bars, dim and fade")
	for colour: String in found:
		assert_true(colour.begins_with("Color(0, 0, 0, "), "%s is neutral black" % colour)


func test_a_theme_on_the_root_window_stops_at_the_players_layer() -> void:
	_root_theme_before = get_tree().root.theme
	_replaced_root_theme = true
	get_tree().root.theme = _theme(HOST_GROUND)
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	add_child_autofree(player)

	assert_eq(
		player.ground_colour(),
		ShantyHostContract.FRAME_DEFAULT_GROUND,
		"why a host must use the project theme: a parent's theme never reaches the frame"
	)


func test_a_project_wide_theme_colour_reaches_the_player_under_its_layer() -> void:
	var global_theme: Theme = ThemeDB.get_default_theme()
	assert_false(
		global_theme.has_color(
			ShantyHostContract.FRAME_GROUND_COLOR, ShantyHostContract.FRAME_VARIATION
		),
		"the engine's own theme declares no frame ground"
	)
	global_theme.set_color(
		ShantyHostContract.FRAME_GROUND_COLOR, ShantyHostContract.FRAME_VARIATION, HOST_GROUND
	)
	_wrote_default_theme = true
	var host := Control.new()
	add_child_autofree(host)
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	host.add_child(player)

	assert_null(_rect(player, "Ground").theme, "no theme is set on the frame itself")
	assert_eq(player.ground_colour(), HOST_GROUND)
	_assert_ground(player, HOST_GROUND)
