## What something says as the story moves on: `states` are `condition => text`
## entries, the last whose condition holds winning, else `text`; `ask` is a
## question before it, `Question?` for `text` or `condition => Question?` for
## one state.
extends RefCounted

const SEPARATOR := "=>"


## `{"text", "question"}` for `node` now.
static func choose(story: RefCounted, node: Node, text: String, states: Array[String], ask: String) -> Dictionary:
	var chosen_condition := ""
	var chosen := text
	for index in range(states.size() - 1, -1, -1):
		var parts := states[index].split(SEPARATOR, true, 1)
		if parts.size() != 2:
			story.log.warn(&"story", "%s: a state is 'condition => text', got \"%s\"" % [node.name, states[index]])
			continue
		if story.check(parts[0], node):
			chosen_condition = parts[0].strip_edges()
			chosen = parts[1].strip_edges()
			break
	var question := ""
	if not ask.is_empty():
		var asked := ask.split(SEPARATOR, true, 1)
		var condition := asked[0].strip_edges() if asked.size() == 2 else ""
		if condition == chosen_condition:
			question = (asked[1] if asked.size() == 2 else asked[0]).strip_edges()
	return {"text": chosen, "question": question}
