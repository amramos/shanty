extends GutTest

## ShantyText: the one writer's tag and the colour the host gives it.

var _previous_colour: Color


func before_each() -> void:
	_previous_colour = ShantyText.highlight_colour()


func after_each() -> void:
	ShantyText.set_highlight_colour(_previous_colour)


func test_a_highlight_becomes_a_colour_tag_in_the_hosts_colour() -> void:
	ShantyText.set_highlight_colour(Color8(255, 170, 0))

	var rendered: String = ShantyText.highlight("the [hl]brass key[/hl] turns")

	assert_eq(rendered, "the [color=#ffaa00]brass key[/color] turns")


func test_every_highlight_in_a_line_is_mapped() -> void:
	ShantyText.set_highlight_colour(Color.WHITE)

	var rendered: String = ShantyText.highlight("[hl]one[/hl] and [hl]two[/hl]")

	assert_eq(rendered.count("[color=#ffffff]"), 2)
	assert_false(rendered.contains("[hl]"))
	assert_false(rendered.contains("[/hl]"))


func test_text_without_a_tag_passes_through_unchanged() -> void:
	assert_eq(ShantyText.highlight("One more time."), "One more time.")


func test_render_translates_the_key_before_mapping() -> void:
	# An unknown key translates to itself, which is enough to see the order:
	# the tag inside the key's text is mapped after translation.
	ShantyText.set_highlight_colour(Color.WHITE)

	assert_eq(ShantyText.render("[hl]X[/hl]"), "[color=#ffffff]X[/color]")


func test_strip_tags_leaves_only_what_a_reader_sees() -> void:
	assert_eq(ShantyText.strip_tags("the [hl]key[/hl] turns"), "the key turns")
	assert_eq(ShantyText.strip_tags("no tags at all"), "no tags at all")
	assert_eq(
		ShantyText.strip_tags("a [b]bold[/b] claim [sic]"),
		"a [b]bold[/b] claim [sic]",
		"only the highlight is markup, so every other bracket is what a reader sees"
	)


## The text a RichTextLabel actually draws for `bbcode`.
func _drawn(bbcode: String) -> String:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	add_child_autofree(label)
	label.text = bbcode
	return label.get_parsed_text()


func test_a_stray_tag_and_a_literal_bracket_render_as_text() -> void:
	ShantyText.set_highlight_colour(Color.WHITE)
	# An unknown key translates to itself, standing in for a translator's text.
	var line: String = "a [b]bold[/b] claim, [sic] and [hl]the key[/hl] ["

	var rendered: String = ShantyText.render(line)

	assert_false(rendered.contains("[b]"), "no live bold tag reaches the label")
	assert_true(rendered.contains("[color=#ffffff]the key[/color]"), "the highlight still maps")
	assert_eq(_drawn(rendered), "a [b]bold[/b] claim, [sic] and the key [")
	assert_eq(_drawn(rendered), ShantyText.strip_tags(line), "strip_tags agrees with the label")


func test_a_url_tag_in_a_translation_is_not_live() -> void:
	var rendered: String = ShantyText.highlight("[url=x]click[/url]")

	assert_eq(_drawn(rendered), "[url=x]click[/url]")


class RenamingProvider:
	extends ShantySpeakerProvider

	var names: Dictionary[StringName, String] = {}

	func resolve(speaker_id: StringName) -> ShantySpeaker:
		if not names.has(speaker_id):
			return super.resolve(speaker_id)
		var speaker := ShantySpeaker.new()
		speaker.display_name = names[speaker_id]
		return speaker


## A speaker is named by token, so a host that renames one -- or takes the name
## away -- changes every line that names them without touching a translation.
func test_a_name_token_reads_whatever_the_provider_calls_the_speaker_now() -> void:
	var provider := RenamingProvider.new()
	provider.names[&"keeper"] = "Ada Vell"
	var text: String = "{name:keeper} asked, and {name:keeper} waited."

	assert_eq(ShantyText.resolve_names(text, provider), "Ada Vell asked, and Ada Vell waited.")
	provider.names[&"keeper"] = "Unknown"
	assert_eq(ShantyText.resolve_names(text, provider), "Unknown asked, and Unknown waited.")


func test_an_unknown_token_names_the_speaker_by_id_and_plain_text_is_untouched() -> void:
	assert_eq(ShantyText.resolve_names("{name:stranger} spoke"), "stranger spoke")
	assert_eq(ShantyText.resolve_names("no {token} here"), "no {token} here")


func test_render_names_before_it_escapes_and_highlights() -> void:
	var provider := RenamingProvider.new()
	provider.names[&"keeper"] = "Ada Vell"

	var rendered: String = ShantyText.render("[hl]{name:keeper}[/hl]", provider)

	assert_eq(rendered, "[color=#ffffff]Ada Vell[/color]")
