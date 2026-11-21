## Makes a test's sandbox a Studio project, `project.studio` and all, and
## installs the Studio layer on its world's services.
extends RefCounted

const Studio := preload("res://addons/wildgrass/studio/studio.gd")


## `world` is a walking world; returns the layer, to uninstall after the test.
static func install(world: RefCounted) -> Studio:
	world.sandbox.set_setting("wildgrass/paths/studio", world.sandbox.root)
	world.sandbox.write("project.studio", "{}")
	world.config.register(&"studio", WgStudioConfig, "studio")
	var studio := Studio.new(world.paths, world.logger, world.config, world.hooks)
	studio.install(world.texts, world.items, world.quests)
	return studio
