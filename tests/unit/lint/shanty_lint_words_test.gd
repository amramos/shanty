extends GutTest

## Where a forbidden word starts and ends: a combining mark belongs to its
## word, case never matters, and an apostrophe is an edge -- so a contraction
## or an elision is still caught -- while a word holding one matches itself.

const COMBINING_ACUTE: int = 0x0301


static func _found(text: String, words: Array[String]) -> PackedStringArray:
	return ShantyLintText.forbidden_words_in(text, PackedStringArray(words))


func test_a_decomposed_accent_belongs_to_its_word() -> void:
	var decomposed: String = "He" + String.chr(COMBINING_ACUTE) + " left."

	assert_eq(_found(decomposed, ["he"]), PackedStringArray(), "h, e and a mark are one word")
	assert_eq(_found("Hé left.", ["he"]), PackedStringArray(), "and so is the composed form")
	assert_eq(_found(decomposed + " He did.", ["he"]), PackedStringArray(["he"]))


func test_a_mark_before_a_word_joins_it_to_the_word_before() -> void:
	var joined: String = "e" + String.chr(COMBINING_ACUTE) + "he"

	assert_eq(_found(joined, ["he"]), PackedStringArray())


func test_case_never_matters() -> void:
	assert_eq(_found("SHE LEFT.", ["she"]), PackedStringArray(["she"]))
	assert_eq(_found("she left.", ["SHE"]), PackedStringArray(["SHE"]))
	assert_eq(_found("ÉLLE est là.", ["élle"]), PackedStringArray(["élle"]), "beyond ASCII too")


func test_an_apostrophe_is_an_edge_so_contractions_and_elisions_are_caught() -> void:
	assert_eq(_found("She's gone.", ["she"]), PackedStringArray(["she"]))
	assert_eq(_found("Voici l'homme.", ["homme"]), PackedStringArray(["homme"]))
	assert_eq(_found("Voici l’homme.", ["homme"]), PackedStringArray(["homme"]))


func test_a_word_holding_an_apostrophe_matches_only_itself() -> void:
	assert_eq(_found("She's gone.", ["she's"]), PackedStringArray(["she's"]))
	assert_eq(_found("She’s gone.", ["she's"]), PackedStringArray(["she's"]), "either mark")
	assert_eq(_found("She is gone.", ["she's"]), PackedStringArray())
	assert_eq(_found("Shells.", ["she's", "she"]), PackedStringArray())
