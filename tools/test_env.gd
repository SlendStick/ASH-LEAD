class_name TestEnv
extends RefCounted
## Shared bootstrap for headless test scripts.
##
## When Godot runs with `--script`, autoload singletons are not always
## instantiated. Tests need them (the game code references the singletons),
## so we create them explicitly in declaration order.

const AUTOLOADS := [
	"SettingsManager",
	"InputManager",
	"Localization",
	"AudioManager",
	"ProfileManager",
	"Game",
	"NetManager",
]


static func ensure_autoloads(root: Node) -> void:
	for autoload_name in AUTOLOADS:
		if root.get_node_or_null("/root/" + autoload_name) != null:
			continue
		var path := "res://autoload/%s.gd" % String(autoload_name).to_snake_case()
		var script: Variant = load(path)
		if script == null:
			push_error("ASH&LEAD: cannot load autoload %s" % path)
			continue
		var node: Node = script.new()
		node.name = autoload_name
		root.add_child(node)
