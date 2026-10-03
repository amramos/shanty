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
## named through the TranslationServer, its settings are the defaults, it has
## played nothing, and its translations are the config's CSV, read as Play
## starts -- so Play shows your words whether or not the project registers
## them. A host whose conditions read real state, or whose
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
## not register itself. The base reads the config's CSV, one catalogue per
## locale column (`translations_from()`).
##
## **The CSV, not the `.translation` files Godot imports from it**: those are
## import products -- absent from a fresh clone, and a step behind the file
## until a Save's reimport finishes -- while the CSV is always there and is
## exactly what the tab saved.
func make_translations() -> Array[Translation]:
	if config == null or config.csv_path.is_empty() or not ShantyFiles.exists(config.csv_path):
		return []
	return translations_from(ShantyCsvDocument.parse(ShantyFiles.read_text(config.csv_path)))


## One `Translation` per locale column of `csv`, holding every non-empty cell
## as Godot's CSV importer reads it: an escape such as a backslash-n in a cell
## unescaped, and keys taken as written. A key on two rows, which the lint
## refuses, is read from its first.
static func translations_from(csv: ShantyCsvDocument) -> Array[Translation]:
	var made: Array[Translation] = []
	for locale: String in csv.locales():
		var translation := Translation.new()
		translation.locale = locale
		for key: String in csv.keys():
			var cell: String = csv.text(key, locale)
			if not cell.is_empty():
				translation.add_message(key, cell.c_unescape())
		made.append(translation)
	return made
