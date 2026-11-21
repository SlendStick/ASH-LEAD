class_name BaseMode
extends Node
## Base class every game mode extends. The mode owns *goals*: objective nodes,
## round flow, scoring and win conditions. All combat mechanics stay in
## MatchWorld, so a new mode is mostly a list of objectives and a tick function.

var world: Node
var cfg: Dictionary
var map: GeneratedMap
var mode_data: Dictionary
var objectives: Array[ObjectiveNode] = []
var score := {0: 0, 1: 0}
var round_active := true
var round_time := 0.0
var round_index := 1
var rounds_won := {0: 0, 1: 0}
var announced := {}
var bot_timer := 0.0
var last_second := -1


func start() -> void:
	world = get_parent()
	cfg = world.get("cfg")
	map = world.get("map")
	mode_data = Db.MODES.get(str(cfg.get("mode", "heist")), Db.MODES["heist"])
	world.set("team_score", score)
	setup_objectives()
	announce("РЕЖИМ: %s" % mode_data.get("name", ""), Color("35c9ff"))
	Signals.objective_changed.emit(str(mode_data.get("brief", "")), "", 0.0)


func setup_objectives() -> void:
	pass


func tick(delta: float) -> void:
	round_time += delta
	if not round_active:
		return
	tick_mode(delta)


func tick_mode(_delta: float) -> void:
	pass


## Every mode finishes an objective the same way: deactivate + tell the HUD.
## Keeping the emit here means the signal can never go silently dead again.
func complete_objective(o: ObjectiveNode, by_team: int = -1) -> void:
	if o == null:
		return
	o.deactivate()
	Signals.objective_completed.emit(o.label, by_team)


func announce(text: String, color: Color = Color("35c9ff")) -> void:
	Signals.match_event.emit(text, color, "mode")


func spawn_objective(kind: int, pos: Vector2, label: String, color: Color = Color("ff2b62"), owner_team: int = -1) -> ObjectiveNode:
	var o := ObjectiveNode.new()
	o.setup(kind, pos, label, world, color)
	o.team_owner = owner_team
	world.add_child(o)
	objectives.append(o)
	return o


func find_interactable(actor: Actor) -> Variant:
	var best: Variant = null
	var best_d := 88.0
	for o in objectives:
		if not o.active:
			continue
		if o.team_owner >= 0 and actor.team != o.team_owner:
			continue
		var d := o.global_position.distance_to(actor.global_position)
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return null
	var text := interaction_text(best, actor)
	if text == "":
		return null
	return {"node": best, "kind": "objective", "text": text, "time": interaction_time(best, actor)}


func interaction_text(o: ObjectiveNode, actor: Actor) -> String:
	return "Взаимодействовать: %s" % o.label


func interaction_time(o: ObjectiveNode, actor: Actor) -> float:
	return 1.6


func on_objective_interact(o: ObjectiveNode, actor: Actor) -> void:
	pass


func on_actor_died(_victim: Actor, _killer: Actor, _headshot: bool) -> void:
	pass


func on_alarm(_level: int) -> void:
	pass


func on_team_counts(_crim: int, _pol: int) -> void:
	pass


func team_eliminated(team: int) -> void:
	pass


func on_door_breached(_door: Node) -> void:
	pass


func on_possess(_actor: Actor) -> void:
	pass


func bot_point(_actor: Actor) -> Variant:
	if objectives.is_empty():
		return null
	var best: ObjectiveNode = null
	var best_d := 1e9
	for o in objectives:
		if not o.active:
			continue
		var d = o.global_position.distance_to(_actor.global_position)
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return null
	return best.global_position


func retreat_point(_actor: Actor) -> Variant:
	return null


func win(team: int, reason: String) -> void:
	if not round_active:
		return
	round_active = false
	rounds_won[team] = int(rounds_won.get(team, 0)) + 1
	Signals.round_ended.emit(team, reason)
	world.call("finish_match", team, reason)


func add_score(team: int, amount: int) -> void:
	score[team] = int(score.get(team, 0)) + amount
	world.set("team_score", score)
	Signals.score_changed.emit(team, score[team])


func objective_progress() -> float:
	return 0.0


func clear_objectives() -> void:
	for o in objectives:
		if is_instance_valid(o):
			o.queue_free()
	objectives.clear()


# ---------------------------------------------------------------------------
# NETWORK CONTRACT
# ---------------------------------------------------------------------------
# The host serialises the objective layer with net_state() and clients apply it
# with net_apply(). Only *objective* state travels (progress, owners, timers);
# actors, damage and doors are handled by the snapshot.

func net_state() -> Array:
	var rows: Array = []
	for o in objectives:
		if o == null or not is_instance_valid(o):
			continue
		rows.append({
			"id": o.objective_id,
			"k": o.kind,
			"x": int(o.global_position.x),
			"y": int(o.global_position.y),
			"p": roundf(o.progress * 100.0) / 100.0,
			"o": o.team_owner,
			"s": o.state,
			"l": o.label,
		})
	return rows


func net_apply(rows: Array) -> void:
	for row in rows:
		var id := str(row.get("id", ""))
		var found: ObjectiveNode = null
		for o in objectives:
			if o != null and o.objective_id == id:
				found = o
				break
		if found == null:
			var pos := Vector2(float(row.get("x", 0)), float(row.get("y", 0)))
			found = spawn_objective(int(row.get("k", 0)), pos, str(row.get("l", "")), Color("ff2b62"), int(row.get("o", -1)))
			found.objective_id = id
		found.progress = float(row.get("p", found.progress))
		found.team_owner = int(row.get("o", found.team_owner))
		found.state = int(row.get("s", found.state))
		found.queue_redraw()
