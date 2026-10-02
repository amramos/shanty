class_name ShantyMusic
extends RefCounted

## What a MusicStep did to the host's music, and the one call that undoes it.
## The bus and the player are the host's, named through ShantyViewSettings; this
## remembers what they were before the first change and puts exactly that back
## in `restore()`, which CutscenePlayer calls when its scene ends by any route.

var _host: Node = null
var _bus_name: StringName = &""
var _music_player: Node = null
var _ducked: bool = false
var _bus_volume_before: float = 0.0
var _duck_tween: Tween = null
var _swapped: bool = false
var _stream_before: AudioStream = null
var _was_playing: bool = false


## `host` owns the ramps' tweens, so they pause with it.
func _init(host: Node, settings: ShantyViewSettings) -> void:
	_host = host
	if settings != null:
		_bus_name = settings.music_bus
		_music_player = settings.music_player


## Lowers the music bus by `db` over `seconds`. A second duck lowers from the
## volume before the first, never compounding.
func duck(db: float, seconds: float) -> void:
	var bus: int = _bus_index()
	if bus < 0:
		return
	if not _ducked:
		_ducked = true
		_bus_volume_before = AudioServer.get_bus_volume_db(bus)
	_kill_duck_tween()
	var target: float = _bus_volume_before - absf(db)
	if seconds <= 0.0 or _host == null or not _host.is_inside_tree():
		AudioServer.set_bus_volume_db(bus, target)
		return
	_duck_tween = _host.create_tween()
	_duck_tween.tween_method(_set_bus_volume, AudioServer.get_bus_volume_db(bus), target, seconds)


## Plays `stream` on the host's player in place of what it was playing. Null
## silences it for the rest of the scene.
func swap(stream: AudioStream) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	if not _swapped:
		_swapped = true
		_stream_before = _stream_of(_music_player)
		_was_playing = _is_playing(_music_player)
	_set_stream(_music_player, stream, stream != null)


## Puts back whatever was changed. Safe to call more than once and when nothing
## was changed at all.
func restore() -> void:
	_kill_duck_tween()
	if _ducked:
		_ducked = false
		var bus: int = _bus_index()
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, _bus_volume_before)
	if _swapped:
		_swapped = false
		if _music_player != null and is_instance_valid(_music_player):
			_set_stream(_music_player, _stream_before, _was_playing)


func is_ducked() -> bool:
	return _ducked


func _bus_index() -> int:
	if _bus_name.is_empty():
		return -1
	return AudioServer.get_bus_index(_bus_name)


func _set_bus_volume(volume_db: float) -> void:
	var bus: int = _bus_index()
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, volume_db)


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


# The three engine players share no base class that owns `stream`, so each is
# named. Anything else the host hands over is ignored rather than guessed at.


static func _stream_of(node: Node) -> AudioStream:
	if node is AudioStreamPlayer:
		return (node as AudioStreamPlayer).stream
	if node is AudioStreamPlayer2D:
		return (node as AudioStreamPlayer2D).stream
	if node is AudioStreamPlayer3D:
		return (node as AudioStreamPlayer3D).stream
	return null


static func _is_playing(node: Node) -> bool:
	if node is AudioStreamPlayer:
		return (node as AudioStreamPlayer).playing
	if node is AudioStreamPlayer2D:
		return (node as AudioStreamPlayer2D).playing
	if node is AudioStreamPlayer3D:
		return (node as AudioStreamPlayer3D).playing
	return false


static func _set_stream(node: Node, stream: AudioStream, play: bool) -> void:
	if node is AudioStreamPlayer:
		var flat: AudioStreamPlayer = node
		flat.stream = stream
		if play and flat.is_inside_tree():
			flat.play()
	elif node is AudioStreamPlayer2D:
		var planar: AudioStreamPlayer2D = node
		planar.stream = stream
		if play and planar.is_inside_tree():
			planar.play()
	elif node is AudioStreamPlayer3D:
		var spatial: AudioStreamPlayer3D = node
		spatial.stream = stream
		if play and spatial.is_inside_tree():
			spatial.play()
