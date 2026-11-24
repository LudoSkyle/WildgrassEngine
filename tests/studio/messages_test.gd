extends GdUnitTestSuite

# The words of Studio's events (feature 10 quater): dialog files, codes and
# a colour picture written by the tests.

const Sandbox := preload("res://tests/support/sandbox.gd")
const StudioMessages := preload("res://addons/wildgrass/studio/studio_messages.gd")
const StudioEvents := preload("res://addons/wildgrass/studio/studio_events.gd")
const Events := preload("res://tests/studio/events_test.gd")

var _sandbox: Sandbox
var _messages: StudioMessages


func before_test() -> void:
	_sandbox = Sandbox.new()
	_sandbox.write("Data/Text/Dialogs/3.csv", "\n".join([
		"en,fr,kana",
		"\":[name=Ann,2]:Hi \\c[2]there\\c[0].\",\":[name=Anne,2]:Salut \\c[2]toi\\c[0].\",x",
		"\"Wait...[WAIT 30] done\",[~ 4],x",
		"\"Line one\\nlline two\",\"Ligne un\\nlligne deux\",x",
	]) + "\n")
	_sandbox.write("Data/Text/Dialogs/100011.csv", "en,fr\nYes,Oui\n\"\\c[2]No\",\"\\c[2]Non\"\n")
	var colors := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	colors.set_pixel(2, 1, Color8(255, 0, 0))
	DirAccess.make_dir_recursive_absolute(_sandbox.root + "graphics/windowskins")
	colors.save_png(_sandbox.root + "graphics/windowskins/_colors.png")
	_messages = StudioMessages.new(_sandbox.root + "Data")


func after_test() -> void:
	_sandbox.cleanup()


func _converted(text: String) -> String:
	return _messages.convert_text(text, "en")


func test_a_message_naming_a_dialog_line_is_a_key_its_words_in_each_language() -> void:
	assert_array(_messages.languages()).is_equal(["en", "fr"])
	assert_str(_messages.text_of("3, 0 :[name=Ann]:Hi there.")).is_equal("dialogs.3.0")
	assert_dict(_messages.translations["dialogs.3.0"]).is_equal({
		"en": "[speaker=Ann][speaker_color=#ff0000]Hi [color=#ff0000]there[/color].",
		"fr": "[speaker=Anne][speaker_color=#ff0000]Salut [color=#ff0000]toi[/color].",
	})
	# An untranslated cell takes the fallback language's words.
	assert_str(_messages.text_of("3,1")).is_equal("dialogs.3.1")
	assert_str(_messages.translations["dialogs.3.1"]["fr"]).is_equal("Wait…[pause=0.5] done")
	assert_str(_messages.translations[_messages.text_of("3, 2")]["en"]).is_equal("Line one\nline two")
	# A choice that is a whole `\t[11, 1]` is a key of file 100011.
	assert_str(_messages.text_of("\\t[11, 1]")).is_equal("dialogs.100011.1")
	assert_str(_messages.translations["dialogs.100011.1"]["fr"]).is_equal("[color=#ff0000]Non[/color]")
	# The fallback language's words, not the first column's.
	_sandbox.write("Data/Text/Dialogs/5.csv", "fr,en,es\nBonjour,Hello,[~ 1]\n")
	assert_str(_messages.line(5, 0, "es")).is_equal("Hello")
	# Written in the event itself: converted, no key.
	assert_str(_messages.text_of("Plain [words].")).is_equal("Plain [lb]words].")


func test_studio_s_codes_become_the_engine_s_placeholders_and_tags() -> void:
	_messages.text_variables.append("[POKE]")
	assert_str(_converted("\\v[5] \\N[1] \\n[2] \\E \\f[she§he] \\k[a]")).is_equal("{value:variable_5} {player} {actor_2} {flag:switch_1?e|} {flag:switch_1?she|he} {key:ui_accept}")
	assert_str(_converted("Got \\t[11, 0]! [POKE] [VAR PKNAME(0002)] [VAR 0000] 5 $")).is_equal("Got Yes! {poke} {pkname_2}  5\u00a0$")
	assert_str(_converted("\\s[b]bold\\s[bi]both\\s[r] plain")).is_equal("[b]bold[/b][b][i]both[/i][/b] plain")
	assert_str(_converted(":[align=center;lookto=3]:Look. \\\\v")).is_equal("[align=center][look_to=3]Look. \\v")
	# `\t` is read before the colours: its own codes are read too.
	assert_str(_converted("\\t[11, 1]")).is_equal("[color=#ff0000]No[/color]")


func test_what_the_engine_cannot_show_yet_is_counted_once_never_kept_as_code() -> void:
	_sandbox.write("Data/Text/Dialogs/4.csv", "en,fr\n\"\\G:[face=0,x;city=y]:Cash\\^ \\spd[2]\\img[a,b,0,0]\",\"\\GSous\"\n")
	var key := _messages.text_of("4, 0")
	assert_str(_messages.translations[key]["en"]).is_equal("Cash ")
	assert_dict(_messages.counts).is_equal({"message: money window": 1, "message: face": 1, "message: city": 1, "message: big text": 1, "message: writing speed": 1, "message: picture": 1})


func test_the_translation_file_holds_every_key_and_takes_the_words_as_written() -> void:
	_messages.text_of("3, 0")
	_messages.text_of(":[name=X]:\\t[11, 0]")
	_messages.text_of("\\t[11, 1]")
	var path := _sandbox.root + "maps/dialogs.csv"
	assert_bool(_messages.write_translations(path)).is_true()
	var file := FileAccess.open(path, FileAccess.READ)
	assert_array(Array(file.get_csv_line())).is_equal(["keys", "en", "fr"])
	assert_array(Array(file.get_csv_line()).slice(0, 2)).is_equal(["dialogs.3.0", "[speaker=Ann][speaker_color=#ff0000]Hi [color=#ff0000]there[/color]."])
	assert_str(file.get_csv_line()[0]).is_equal("dialogs.100011.1")
	var settings := ConfigFile.new()
	settings.load(path + ".import")
	assert_array([settings.get_value("params", "unescape_translations"), settings.get_value("params", "unescape_keys"), settings.get_value("remap", "importer")]).is_equal([false, false, "csv_translation"])


func test_messages_choices_numbers_and_text_options_are_the_engine_s_commands() -> void:
	var events := StudioEvents.new(_sandbox.root + "Data")
	events.gather_text_variables([[Events.command(355, ["set_variable(\"[POKE]\", name)"])]])
	assert_array(events.messages.text_variables).is_equal(["[POKE]"])
	var built := events.build_commands([
		Events.command(101, ["Hello [POKE],"]), Events.command(401, ["there."]),
		Events.command(102, [["\\t[11, 0]", "Maybe"], 5]), Events.command(402, [1, "Maybe"]), Events.command(403, []),
		Events.command(103, [7, 3]), Events.command(104, [0, 1]),
	])
	assert_str((built[0] as WgEventSay).text).is_equal("Hello {poke},\nthere.")
	var asked := built[1] as WgEventChoices
	assert_array([asked.choices, asked.cancel]).is_equal([["dialogs.100011.0", "Maybe"], 5])
	assert_int((built[2] as WgEventWhen).choice).is_equal(1)
	assert_object(built[3]).is_instanceof(WgEventWhenCancel)
	var number := built[4] as WgEventInputNumber
	assert_array([number.variable, number.digits]).is_equal([7, 3])
	var options := built[5] as WgEventTextOptions
	assert_array([options.place, options.frame]).is_equal([WgEventTextOptions.Place.TOP, false])
