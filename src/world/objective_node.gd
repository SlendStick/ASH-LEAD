class_name ObjectiveNode
extends Node2D
## A world-space objective marker that can be interacted with:
## vault, cash register, getaway van, bomb site, hostage, capture point, VIP.
## Draws itself in neon-noir signage style and exposes state to modes + HUD.

enum Kind { VAULT, CASH, VAN, BOMB_SITE, HOSTAGE, CAPTURE, VIP, EXIT, DEFUSE, SAFE_DEPOSIT }

var kind := Kind.VAULT
var label := "ЦЕЛЬ"
var radius := 74.0
var team_owner := -1          ## which team may use it (-1 = any)
var active := true
var progress := 0.0
var state := "idle"
var world: Node
var color := Color("ff2b62")
var pulse := 0.0
var locked := true
var interacted_by: Array[int] = []
var data: Dictionary = {}
var objective_id := ""


func setup(k: int, pos: Vector2, text: String, w: Node, col: Color = Color("ff2b62")) -> void:
	kind = k
	global_position = pos
	if objective_id == "":
		objective_id = "obj_%d" % int(pos.x * 7 + pos.y * 13)
	label = text
	world = w
	color = col
	z_index = 1
	data = {}


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var a := 0.55 + 0.45 * sin(pulse * 2.4)
	var c := Color(color.r, color.g, color.b, a)
	# ground ring
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.35), 2.5)
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.12), 6.0)
	# progress arc
	if progress > 0.0:
		draw_arc(Vector2.ZERO, radius * 0.9, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(0.7, 1.0, 0.7, 0.9), 5.0)
	# icon by kind
	match kind:
		Kind.VAULT, Kind.SAFE_DEPOSIT:
			draw_circle(Vector2.ZERO, 26.0, Color(0.12, 0.12, 0.16, 0.9))
			draw_arc(Vector2.ZERO, 26.0, 0, TAU, 24, c, 3.0)
			draw_line(Vector2(-12, 0), Vector2(12, 0), c, 3.0)
			draw_line(Vector2(0, -12), Vector2(0, 12), c, 3.0)
		Kind.CASH:
			draw_rect(Rect2(-16, -11, 32, 22), Color(0.1, 0.2, 0.12, 0.9), true)
			draw_rect(Rect2(-16, -11, 32, 22), c, false, 2.0)
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.2, 0.8))
		Kind.VAN:
			draw_rect(Rect2(-46, -22, 92, 44), Color(0.08, 0.1, 0.12, 0.92), true)
			draw_rect(Rect2(-46, -22, 92, 44), c, false, 3.0)
			draw_rect(Rect2(20, -16, 24, 32), Color(0.2, 0.35, 0.5, 0.6), true)
			draw_circle(Vector2(-28, 20), 7.0, Color(0.05, 0.05, 0.06))
			draw_circle(Vector2(26, 20), 7.0, Color(0.05, 0.05, 0.06))
		Kind.BOMB_SITE:
			draw_arc(Vector2.ZERO, 30.0, 0, TAU, 28, c, 3.0)
			draw_line(Vector2(-14, -14), Vector2(14, 14), c, 4.0)
			draw_line(Vector2(14, -14), Vector2(-14, 14), c, 4.0)
		Kind.HOSTAGE:
			draw_circle(Vector2(0, -8), 9.0, Color(0.8, 0.78, 0.7, 0.9))
			draw_arc(Vector2(0, 10), 16.0, PI, TAU, 16, c, 4.0)
		Kind.CAPTURE:
			draw_circle(Vector2.ZERO, 18.0, Color(c.r, c.g, c.b, 0.25))
			draw_arc(Vector2.ZERO, 26.0, 0, TAU, 30, c, 3.0)
			draw_line(Vector2(0, -18), Vector2(0, 18), c, 4.0)
		Kind.DEFUSE:
			draw_rect(Rect2(-14, -10, 28, 20), Color(0.12, 0.05, 0.05, 0.95), true)
			draw_rect(Rect2(-14, -10, 28, 20), c, false, 2.0)
			draw_circle(Vector2(0, 0), 4.0, Color(1.0, 0.2, 0.2, 0.9))
		Kind.VIP:
			draw_circle(Vector2(0, -6), 10.0, Color(0.8, 0.8, 0.85, 0.9))
			draw_arc(Vector2(0, 10), 18.0, PI, TAU, 18, c, 4.0)
	# label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-radius, -radius - 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)


## Called by Actor.interact via modes.
func interact(actor: Actor) -> void:
	if world != null:
		var m = world.get("mode")
		if m != null and m.has_method("on_objective_interact"):
			m.call("on_objective_interact", self, actor)


func deactivate() -> void:
	active = false
	queue_redraw()
