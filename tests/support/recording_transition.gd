## A transition that records the calls of the engine.
extends WgTransition

static var calls: Array[String] = []


func cover() -> void:
	calls.append("cover %s" % seconds)


func uncover() -> void:
	calls.append("uncover")
