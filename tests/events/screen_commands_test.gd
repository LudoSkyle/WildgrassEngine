extends GdUnitTestSuite

# The screen and sound commands (feature 21, step 2): lists built by the
# tests, run on the world's screen, weather and audio.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")
const Messages := preload("res://tests/events/messages_test.gd")
const Screen := preload("res://addons/wildgrass/screen/screen.gd")
const STEP := 1.0 / 60.0

var _world: World
var _player: WgWalker
var _texture: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player
	_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for kind: String in ["music", "ambience", "jingles", "effects"]:
		var stream := AudioStreamWAV.new()
		stream.mix_rate = 8000
		var data := PackedByteArray()
		data.resize(400)
		stream.data = data
		var path := _world.sandbox.root + "audio/%s/a.wav" % kind
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		stream.save_to_wav(path)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


## An event running `commands` by itself once, then switch 9 on.
func _autorun(commands: Array[WgEventCommand]) -> WgEvent:
	commands.append(Events.switch_on(9))
	commands.append(WgEventSetLocalSwitch.new())
	var event := WgEvent.new()
	event.name = "Event1"
	event.event_id = 1
	event.walkers = _world.walkers
	event.position = _world.tiles.center_of(Vector2i(2, 2))
	event.pages = [Events.page(commands, {"trigger": WgEventPage.Trigger.AUTORUN}), Events.page([], {"condition": "local:A"})]
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


func _advance(frames := 1) -> void:
	for _frame in frames:
		_world.events.advance(STEP)
		_world.screen.advance(STEP)
		_world.audio.advance(STEP)


## The event gone, its local switch and switch 9 off: a new list may run.
func _again() -> void:
	var event := _world.maps.current.entities_node().get_node("Event1")
	_world.story.clear_flag(_world.story.local(event, &"A"))
	_world.story.clear_flag(&"switch_9")
	event.free()


func _done() -> bool:
	return _world.story.has(&"switch_9")


static func _picture(action: WgEventPicture.Action, number := 1) -> WgEventPicture:
	var made := WgEventPicture.new()
	made.action = action
	made.number = number
	return made


func test_tone_flash_and_shake_start_and_the_list_goes_on() -> void:
	var toned := WgEventScreenTone.new()
	toned.tone = Vector4(-255, 0, 0, 100)
	toned.seconds = 10 * STEP
	var flashed := WgEventScreenFlash.new()
	flashed.color = Color(1, 1, 0, 1)
	flashed.seconds = 4 * STEP
	var shaken := WgEventScreenShake.new()
	shaken.power = 3
	shaken.speed = 4
	shaken.seconds = 2 * STEP
	_autorun([toned, flashed, shaken] as Array[WgEventCommand])
	_advance(1)
	assert_bool(_done()).is_true()
	assert_float(_world.screen.tone.x).is_equal_approx(-25.5, 0.001)
	assert_float(_world.screen.flash_color.a).is_equal_approx(0.75, 0.001)
	assert_float(_world.screen.shake).is_equal_approx(1.2, 0.001)


func test_a_scroll_waits_for_the_one_under_way() -> void:
	var first := WgEventScrollMap.new()
	first.direction = Vector2i.DOWN
	first.cells = 1
	first.speed = 3
	var back := WgEventScrollMap.new()
	back.direction = Vector2i.UP
	back.cells = 1
	back.speed = 6
	_autorun([first, back, WgEventWait.new()] as Array[WgEventCommand])
	_advance(1)
	assert_that(_world.screen.scroll_offset).is_equal(Vector2(0, 1))
	_advance(14)
	assert_bool(_done()).is_false()
	_advance(1)
	assert_that(_world.screen.scroll_offset).is_equal(Vector2(0, 16))
	_advance(3)
	assert_bool(_done()).is_true()
	assert_that(_world.screen.scroll_offset).is_equal(Vector2.ZERO)


func test_pictures_shown_from_variables_moved_turned_toned_and_erased() -> void:
	_world.story.set_value(&"variable_3", 40)
	_world.story.set_value(&"variable_4", 50)
	var shown := _picture(WgEventPicture.Action.SHOW, 7)
	shown.texture = _texture
	shown.by_variables = true
	shown.x_variable = 3
	shown.y_variable = 4
	shown.origin = Screen.Origin.CENTER
	shown.zoom = Vector2(150, 150)
	shown.opacity = 100
	shown.blend = Screen.Blend.SUBTRACT
	var moved := _picture(WgEventPicture.Action.MOVE, 7)
	moved.position = Vector2(0, 50)
	moved.origin = Screen.Origin.CENTER
	moved.zoom = Vector2(150, 150)
	moved.opacity = 100
	moved.blend = Screen.Blend.SUBTRACT
	moved.seconds = 2 * STEP
	var turned := _picture(WgEventPicture.Action.ROTATE, 7)
	turned.speed = 4
	var toned := _picture(WgEventPicture.Action.TONE, 7)
	toned.tone = Vector4(0, 60, 0, 0)
	_autorun([shown, moved, turned, toned] as Array[WgEventCommand])
	_advance(1)
	var picture := _world.screen.picture(7)
	assert_array([picture["texture"], picture["origin"], picture["position"], picture["zoom"], picture["opacity"], picture["blend"], picture["tone"], picture["angle"]]) \
		.is_equal([_texture, Screen.Origin.CENTER, Vector2(20, 50), Vector2(150, 150), 100.0, Screen.Blend.SUBTRACT, Vector4(0, 60, 0, 0), 2.0])
	_again()
	_autorun([_picture(WgEventPicture.Action.ERASE, 7)] as Array[WgEventCommand])
	_advance(2)
	assert_dict(_world.screen.picture(7)).is_empty()


func test_a_freeze_waits_for_the_message_and_the_transition_holds_the_list_until_it_ends() -> void:
	var transition := WgEventScreenTransition.new()
	transition.seconds = 5 * STEP
	_autorun([Messages.say("Hi"), WgEventFreezeScreen.new(), transition] as Array[WgEventCommand])
	_advance(2)
	assert_bool(_world.screen.frozen).is_false()
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	var pressed := InputEventAction.new()
	pressed.action = "ui_accept"
	pressed.pressed = true
	_world.screens.handle_input(pressed)
	_advance(1)
	assert_bool(_world.screen.frozen).is_true()
	assert_bool(_world.screen.is_transitioning()).is_true()
	_advance(3)
	assert_bool(_done()).is_false()
	_advance(3)
	assert_bool(_world.screen.frozen).is_false()
	assert_bool(_done()).is_true()


func test_a_freeze_waits_for_another_list_s_message() -> void:
	_world.dialogue.say("Elsewhere")
	_autorun([WgEventFreezeScreen.new()] as Array[WgEventCommand])
	_advance(3)
	assert_bool(_world.screen.frozen).is_false()
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	var pressed := InputEventAction.new()
	pressed.action = "ui_accept"
	pressed.pressed = true
	_world.screens.handle_input(pressed)
	_advance(2)
	assert_bool(_world.screen.frozen).is_true()


func test_a_transition_with_nothing_frozen_goes_on() -> void:
	_autorun([WgEventScreenTransition.new()] as Array[WgEventCommand])
	_advance(1)
	assert_bool(_done()).is_true()


func test_the_weather_is_set() -> void:
	var weather := WgEventWeather.new()
	weather.weather = &"rain"
	_autorun([weather] as Array[WgEventCommand])
	_advance(1)
	assert_that(_world.weather.current).is_equal(&"rain")


func test_sounds_play_fade_stop_and_come_back() -> void:
	var commands: Array[WgEventCommand] = []
	for kind: WgEventSound.Kind in [WgEventSound.Kind.MUSIC, WgEventSound.Kind.AMBIENCE, WgEventSound.Kind.EFFECT]:
		var sound := WgEventSound.new()
		sound.kind = kind
		sound.sound = &"a"
		sound.volume = 0.8
		sound.pitch = 1.2
		commands.append(sound)
	commands.append(WgEventMemorizeSound.new())
	var faded := WgEventFadeSound.new()
	faded.kind = WgEventFadeSound.Kind.AMBIENCE
	commands.append(faded)
	var silent := WgEventSound.new()
	silent.kind = WgEventSound.Kind.MUSIC
	commands.append(silent)
	commands.append(WgEventStopEffects.new())
	_autorun(commands)
	_advance(1)
	var audio := _world.audio
	assert_array([audio.music.name, audio.ambience.name, audio.ambience.current.playing]).is_equal([&"", &"", false])
	assert_bool(audio.voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing)).is_false()
	_again()
	var jingle := WgEventSound.new()
	jingle.kind = WgEventSound.Kind.JINGLE
	jingle.sound = &"a"
	var empty := WgEventSound.new()
	empty.kind = WgEventSound.Kind.EFFECT
	_autorun([WgEventRestoreSound.new(), jingle, empty] as Array[WgEventCommand])
	_advance(1)
	assert_bool(_done()).is_true()
	assert_array([audio.music.name, audio.music.playing()["volume"], snappedf(audio.music.current.pitch_scale, 0.001), audio.ambience.name]).is_equal([&"a", 0.8, 1.2, &"a"])
	assert_bool(audio.is_jingle_playing()).is_true()
	assert_bool(audio.voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing)).is_false()
