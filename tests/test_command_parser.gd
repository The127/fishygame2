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
