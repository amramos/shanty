class_name ShantyPreviewHost
extends RefCounted

## What Play asks of a host: the context, speakers and reading settings a scene
## plays with in the preview window, and the records a trigger chooses against.
## Subclass it in your project, override what your game provides, and name the
## script in your config's `preview_host_path`; with none named, Play uses
## this base as it is.
##
## **The base needs no code of yours.** Its context holds nothing (every
## condition asking `has_key()` fails), its speakers are your speakers folder
## named through the TranslationServer, its settings are the defaults, and it
## has played nothing. A host whose conditions read real state, or whose
## speakers are generated, overrides the matching method.
##
## Play runs in a game window, never in the editor, so a subclass needs no
## `@tool` and may use anything the game itself would.

## The config the tab has open; set before any `make_*` call.
var config: ShantyProjectConfig = null


## The host whose script `with_config` names, or this base when it names none
## or names something that is not a ShantyPreviewHost.
static func for_config(with_config: ShantyProjectConfig) -> ShantyPreviewHost:
	var host: ShantyPreviewHost = null
	var path: String = with_config.preview_host_path if with_config != null else ""
	if not path.is_empty():
		var script: GDScript = ShantyFiles.load_resource(path) as GDScript
		# Only a RefCounted is made: anything else could not be a preview host,
		# and a Node made here would outlive the check.
		if script != null and script.get_instance_base_type() == &"RefCounted":
			host = script.new() as ShantyPreviewHost
		if host == null:
			push_warning("Shanty Play: %s is not a ShantyPreviewHost; using the default." % path)
	if host == null:
		host = ShantyPreviewHost.new()
	host.config = with_config
	return host


## What conditions ask about the game. The base holds nothing.
func make_context() -> ShantyContext:
	return ShantyContext.new()


## Who the lines' speakers are. The base reads the config's speakers folder.
func make_speaker_provider() -> ShantySpeakerProvider:
	var folder: String = config.speakers_folder if config != null else ""
	return ShantyPreviewSpeakers.from_folder(folder)


## How the scene reads: text speed, names, reduced motion, the buses.
func make_settings() -> ShantyViewSettings:
	return ShantyViewSettings.new()


## What has already played, for a trigger's `once` candidates.
func make_records() -> Array[PlayedSceneRecord]:
	return []


## Catalogues to add while the preview plays, for strings the project does
## not register itself. The base adds none: the project's own play.
func make_translations() -> Array[Translation]:
	return []
