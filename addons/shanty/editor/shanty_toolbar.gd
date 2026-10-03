@tool
extends HBoxContainer

## The tab's toolbar: the Config menu, reachable whatever is open; the working
## (source) locale and the target locale, both filled from the CSV header and
## nothing else; + Locale; the coverage strip; Reload, Lint, Save and Play. It
## only reports what the writer pressed.

signal locales_chosen(source: String, target: String)
signal locale_requested(locale: String)
signal reload_pressed
signal lint_pressed
signal save_pressed
signal create_config_pressed
signal inspect_config_pressed
signal host_keys_pressed
signal play_pressed

## The Config menu's items, by id.
enum ConfigItem { CREATE, INSPECT, HOST_KEYS }

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")

var _config_menu: MenuButton = MenuButton.new()
var _source: OptionButton = OptionButton.new()
var _target: OptionButton = OptionButton.new()
var _new_locale: LineEdit = LineEdit.new()
var _coverage: HBoxContainer = HBoxContainer.new()
var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	_config_menu.text = "Config ▾"
	_config_menu.flat = false
	_config_menu.tooltip_text = "The ShantyProjectConfig the tab reads"
	var items: PopupMenu = _config_menu.get_popup()
	items.add_item("Create config…", ConfigItem.CREATE)
	items.set_item_tooltip(
		items.get_item_index(ConfigItem.CREATE),
		"Save a new ShantyProjectConfig, point the project at it and open it"
	)
	items.add_item("Open config in Inspector", ConfigItem.INSPECT)
	items.add_item("Add host keys", ConfigItem.HOST_KEYS)
	items.set_item_tooltip(
		items.get_item_index(ConfigItem.HOST_KEYS),
		"Add rows for the keys Shanty's own controls show, with their English text"
	)
	items.id_pressed.connect(_on_config_item)
	add_child(_config_menu)
	_add_caption("Source")
	add_child(_source)
	_add_caption("Target")
	add_child(_target)
	_new_locale.placeholder_text = "new locale"
	_new_locale.custom_minimum_size.x = 96
	_new_locale.text_submitted.connect(_on_add_locale.unbind(1))
	add_child(_new_locale)
	_add_button("+ Locale", _on_add_locale)
	add_child(VSeparator.new())
	_coverage.size_flags_horizontal = SIZE_EXPAND_FILL
	_coverage.tooltip_text = "Filled cells per locale. A report: an empty cell never blocks Save."
	add_child(_coverage)
	_add_button("Reload", reload_pressed.emit)
	_add_button("Lint", lint_pressed.emit)
	_add_button("Save", save_pressed.emit)
	add_child(VSeparator.new())
	var play: Button = _add_button("Play", play_pressed.emit)
	play.tooltip_text = "Play the picked scene, or the scene the picked trigger chooses"
	_source.item_selected.connect(_on_locale_selected.unbind(1))
	_target.item_selected.connect(_on_locale_selected.unbind(1))


## With no config open there is none to inspect; Create config… is always
## offered.
func show_config_missing(missing: bool) -> void:
	var items: PopupMenu = _config_menu.get_popup()
	items.set_item_disabled(items.get_item_index(ConfigItem.INSPECT), missing)
	items.set_item_disabled(items.get_item_index(ConfigItem.HOST_KEYS), missing)


## The Config menu, for the tests.
func config_menu() -> PopupMenu:
	return _config_menu.get_popup()


## Fills the dropdowns with the CSV's locales -- Source's in `sources`' order,
## the config's own first -- and names `suggested` in the new-locale field
## while there is no source to pick.
func show_locales(
	sources: PackedStringArray,
	locales: PackedStringArray,
	source: String,
	target: String,
	suggested: String = ""
) -> void:
	_fill(_source, sources, source)
	_fill(_target, locales, target)
	_new_locale.placeholder_text = (
		"new locale" if suggested.is_empty() else "new locale, e.g. %s" % suggested
	)


## `en 12/12 · pt_BR 9/12`, an incomplete locale in the editor's warning colour.
func show_coverage(reports: Array[ShantyLocaleCoverage]) -> void:
	for child: Node in _coverage.get_children():
		child.queue_free()
	for index: int in reports.size():
		if index > 0:
			_coverage.add_child(Palette.caption("·", Palette.muted()))
		var report: ShantyLocaleCoverage = reports[index]
		var colour: Color = Palette.success() if report.is_complete() else Palette.warning()
		var label: Label = Palette.caption(report.summary(), colour)
		label.add_theme_font_size_override(&"font_size", 13)
		if not report.is_complete():
			label.tooltip_text = "Empty: " + ", ".join(report.empty_keys)
		label.mouse_filter = MOUSE_FILTER_STOP
		_coverage.add_child(label)


func _fill(button: OptionButton, locales: PackedStringArray, chosen: String) -> void:
	button.clear()
	for locale: String in locales:
		button.add_item(locale)
	var at: int = locales.find(chosen)
	button.select(at)


func _on_config_item(id: int) -> void:
	match id:
		ConfigItem.CREATE:
			create_config_pressed.emit()
		ConfigItem.INSPECT:
			inspect_config_pressed.emit()
		ConfigItem.HOST_KEYS:
			host_keys_pressed.emit()


func _on_locale_selected() -> void:
	locales_chosen.emit(_selected(_source), _selected(_target))


func _on_add_locale() -> void:
	var locale: String = _new_locale.text.strip_edges()
	if not locale.is_empty():
		locale_requested.emit(locale)
		_new_locale.clear()


static func _selected(button: OptionButton) -> String:
	return button.get_item_text(button.selected) if button.selected >= 0 else ""


func _add_caption(text: String) -> void:
	var label := Label.new()
	label.text = text
	add_child(label)


func _add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)
	return button
