## A guarded passage, on the free cell beside a guard. Stepped on, the player
## backs away while the guard steps in behind it; the guard speaks, then goes
## back to its post. The player always gets control back.
class_name WgRoadblock
extends WgTrigger

## The guard: a character on a neighbouring cell.
@export var guard: NodePath
## What the guard says; empty: its WgTalk's.
@export_multiline var text := ""


func _triggered(walker: WgWalker) -> void:
	var walkers := walker.walkers
	var into := walker.facing
	var keeper := get_node_or_null(guard) as WgWalker
	var options := {}
	var said := text
	if keeper != null:
		for child: Node in keeper.get_children():
			if child is WgTalk:
				var talk := child as WgTalk
				said = talk.current_text(walkers.story) if said.is_empty() else said
				if not talk.speaker.is_empty():
					options["speaker"] = talk.speaker
				if talk.speaker_color.a > 0.0:
					options["speaker_color"] = talk.speaker_color
				break
	var post_facing := keeper.facing if keeper != null else Vector2i.ZERO
	var step_in := walker.cell - keeper.cell if keeper != null else Vector2i.ZERO
	var moved := false
	if keeper != null and step_in.length_squared() == 1 and walker.can_step(-into):
		walkers.set_still(keeper, true)
		while is_instance_valid(keeper) and keeper.is_moving:
			await walker.get_tree().process_frame
		# Both start in the same frame: the guard steps into the cell the
		# player is leaving.
		walker.step(-into, false, false)
		moved = is_instance_valid(keeper) and keeper.step(step_in)
		while walker.is_moving or (moved and is_instance_valid(keeper) and keeper.is_moving):
			await walker.get_tree().process_frame
	if is_instance_valid(keeper):
		keeper.turn_toward(walker)
	await walkers.dialogue.say(said, options)
	if moved and is_instance_valid(keeper):
		await walkers.walk(keeper, [-step_in])
	if is_instance_valid(keeper):
		keeper.turn(post_facing)
		walkers.set_still(keeper, false)
	var input := walker.controller as WgPlayerInput
	if input != null:
		input.block(into)
