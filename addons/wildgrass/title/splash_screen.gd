## A splash image before the title: it fades in, stays, fades out, over
## black; confirm skips it. The engine's scene shows the image whole, centred;
## a game points `wildgrass/screens/splash` to its own.
##
## Opened by `Wildgrass.title`; arguments: `texture`, `dialogue` (the
## engine's).
class_name WgSplashScreen
extends WgScreen

const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")

@export var fade_in_seconds := 0.4
@export var stay_seconds := 1.0
@export var fade_out_seconds := 0.4

@export_group("Nodes")
## The `TextureRect` of the image.
@export var image: NodePath = ^"Image"

var dialogue: Dialogue
## Seconds since it opened.
var elapsed := 0.0


func _on_open(args: Dictionary) -> void:
	dialogue = args["dialogue"] if args.has("dialogue") else _engine_service(&"dialogue")
	var shown := get_node_or_null(image) as TextureRect
	if shown != null:
		shown.texture = args.get("texture") as Texture2D
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func _on_input(event: InputEvent) -> bool:
	if dialogue != null and dialogue.is_action(event, "confirm"):
		close()
	return true


## Moves the splash on by `delta` seconds; closes it at the end.
func advance(delta: float) -> void:
	if is_closed():
		return
	elapsed += delta
	if elapsed >= fade_in_seconds + stay_seconds + fade_out_seconds:
		close()
		return
	var shown := get_node_or_null(image) as CanvasItem
	if shown != null:
		shown.modulate.a = opacity()


## How much the image shows, 0 to 1.
func opacity() -> float:
	if elapsed < fade_in_seconds:
		return elapsed / fade_in_seconds
	var leaving := elapsed - fade_in_seconds - stay_seconds
	if leaving <= 0.0:
		return 1.0
	return clampf(1.0 - leaving / fade_out_seconds, 0.0, 1.0) if fade_out_seconds > 0.0 else 0.0


func _engine_service(key: StringName) -> Variant:
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
