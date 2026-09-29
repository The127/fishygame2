extends GutTest


func test_parses_command_and_args() -> void:
	var r: Dictionary = CommandParser.new().parse("#join red fish")
	assert_eq(r["command"], "join")
	assert_eq(r["args"], PackedStringArray(["red", "fish"]))


func test_case_insensitive_command() -> void:
	assert_eq(CommandParser.new().parse("#JoIn")["command"], "join")


func test_no_prefix_ignored() -> void:
	assert_true(CommandParser.new().parse("join").is_empty())
	assert_true(CommandParser.new().parse("hello #join").is_empty())


func test_prefix_only_ignored() -> void:
	assert_true(CommandParser.new().parse("#").is_empty())
	assert_true(CommandParser.new().parse("#   ").is_empty())


func test_custom_prefix() -> void:
	var p := CommandParser.new("!")
	assert_eq(p.parse("!Go 1")["command"], "go")
	assert_true(p.parse("#go").is_empty())


func test_extra_whitespace() -> void:
	var r: Dictionary = CommandParser.new().parse("  #join   a   b ")
	assert_eq(r["args"], PackedStringArray(["a", "b"]))


func test_whitespace_after_prefix_is_not_a_command() -> void:
	assert_true(CommandParser.new().parse("# join").is_empty())
	assert_true(CommandParser.new().parse("#").is_empty())


func test_tab_separators() -> void:
	var r: Dictionary = CommandParser.new().parse("#join\tred\tfish")
	assert_eq(r["command"], "join")
	assert_eq(r["args"], PackedStringArray(["red", "fish"]))


func test_nbsp_and_newline_separators() -> void:
	var r: Dictionary = CommandParser.new().parse("#join\u00a0red\nfish")
	assert_eq(r["command"], "join")
	assert_eq(r["args"], PackedStringArray(["red", "fish"]))


func test_7tv_tag_character_ignored() -> void:
	var r: Dictionary = CommandParser.new().parse("#join red " + char(0xE0000))
	assert_eq(r["command"], "join")
	assert_eq(r["args"], PackedStringArray(["red"]))
	assert_eq(CommandParser.new().parse("#join" + char(0xE0000))["command"], "join")


func test_zero_width_characters_ignored() -> void:
	var zwsp: String = char(0x200B)
	assert_eq(CommandParser.new().parse(zwsp + "#jo" + zwsp + "in")["command"], "join")
	assert_true(CommandParser.new().parse("#" + zwsp + " join").is_empty())
