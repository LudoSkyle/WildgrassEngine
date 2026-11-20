## Writes down each time a node of this script enters the tree.
extends Node2D

static var entered: Array[String] = []


func _enter_tree() -> void:
	entered.append(name)
