extends PanelContainer
## PAYDAY-style arsenal between lives: buy weapons, armour, gadgets and perks
## with the money earned in the match. Everything they buy is spawned in hand.

var world: Node
var grid: GridContainer
var money_label: Label
var tab := 0
var tabs := ["ОРУЖИЕ", "БРОНЯ", "ГАДЖЕТЫ", "ПЕРКИ"]


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.015, 0.012, 0.03, 0.96), Color(0.5, 0.25, 0.7, 0.6), 1, 3))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	position = Vector2(-470, -320)
	custom_minimum_size = Vector2(940, 640)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	header.add_child(UiKit.neon_title("АРСЕНАЛ", 34, UiKit.P["magenta"]))
	money_label = UiKit.make_label("$0", 26, UiKit.P["amber"])
	header.add_child(money_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := UiKit.make_small_button("ЗАКРЫТЬ [B]", UiKit.P["cyan"])
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	box.add_child(tab_row)
	for i in range(tabs.size()):
		var b := UiKit.make_small_button(tabs[i], UiKit.P["magenta"] if i == tab else UiKit.P["grey"])
		var idx := i
		b.pressed.connect(func() -> void:
			tab = idx
			_refresh())
		tab_row.add_child(b)
	box.add_child(UiKit.make_separator())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	_refresh()


func open() -> void:
	_refresh()


func refresh() -> void:
	if visible:
		_update_money()


func _update_money() -> void:
	var p = world.get("local_actor") if world != null else null
	money_label.text = Util.fmt_cash(int(p.money) if p != null else 0)


func _clear() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()


func _refresh() -> void:
	if grid == null:
		return
	_clear()
	_update_money()
	match tab:
		0:
			_weapons()
		1:
			_armor()
		2:
			_gadgets()
		3:
			_perks()


func _weapons() -> void:
	for wid in Db.WEAPON_ORDER:
		var w: Dictionary = Db.WEAPONS[wid]
		var cls := str(w.get("class", "primary"))
		if cls == "gadget":
			continue
		grid.add_child(_card(wid, w))


func _armor() -> void:
	for aid in Db.ARMOR.keys():
		var a: Dictionary = Db.ARMOR[aid]
		grid.add_child(_simple_card(str(a["name"]), str(a["desc"]), int(a["price"]), Color("35c9ff"), func() -> void:
			_buy_armor(str(aid))))


func _gadgets() -> void:
	for gid in ["grenade", "flashbang", "smoke", "molotov", "remote_charge", "medkit", "fortify", "breach_kit"]:
		if not Db.WEAPONS.has(gid):
			continue
		var w: Dictionary = Db.WEAPONS[gid]
		grid.add_child(_card(gid, w))


func _perks() -> void:
	for pid in Db.PERKS.keys():
		var p: Dictionary = Db.PERKS[pid]
		grid.add_child(_simple_card(str(p["name"]), str(p["desc"]), int(p["price"]), Color("b6ff2b"), func() -> void: pass))


func _card(wid: String, w: Dictionary) -> Control:
	var price := int(w.get("price", 0))
	var stats := "УРОН %.0f | ТЕМП %.0f | МАГ %d | ТОЧН %.1f" % [float(w.get("dmg", 0)), float(w.get("rpm", 0)), int(w.get("mag", 0)), float(w.get("spread", 0))]
	var kind := str(w.get("kind", ""))
	var col := Color("ff2b62")
	if kind == "rifle":
		col = Color("35c9ff")
	elif kind == "smg":
		col = Color("b6ff2b")
	elif kind == "shotgun":
		col = Color("ffb02b")
	elif kind == "sniper":
		col = Color("8d2bff")
	elif kind == "melee":
		col = Color("7b7890")
	elif kind == "throw":
		col = Color("2bff9a")
	return _simple_card("%s [%s]" % [w.get("name", wid), w.get("short", "")], str(w.get("desc", "")) + "\n" + stats, price, col, func() -> void: _buy_weapon(wid))


func _simple_card(title: String, desc: String, price: int, col: Color, cb: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.05, 0.04, 0.075, 0.9), Color(col.r, col.g, col.b, 0.35), 1, 2))
	card.custom_minimum_size = Vector2(284, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var t1 := UiKit.make_label(title, 14, col)
	v.add_child(t1)
	var d := UiKit.make_label(desc, 11, Color(0.75, 0.75, 0.82, 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(256, 0)
	v.add_child(d)
	var buy := UiKit.make_small_button("КУПИТЬ %s" % Util.fmt_cash(price), col)
	buy.pressed.connect(cb)
	v.add_child(buy)
	return card


func _buy_weapon(wid: String) -> void:
	var p = world.get("local_actor")
	if p == null or p.dead:
		return
	var price := int(Db.WEAPONS[wid].get("price", 0))
	if int(p.money) < price:
		Sfx.play_ui("ui_deny")
		Signals.notify.emit("Не хватает денег", "bad")
		return
	var cls := str(Db.WEAPONS[wid].get("class", "primary"))
	if price > 0:
		p.money -= price
	p.add_weapon(wid)
	if cls == "gadget":
		p.gadget_charges[wid] = int(p.gadget_charges.get(wid, 0)) + 1
	p.switch_to(wid)
	Sfx.play_ui("ui_buy")
	Signals.notify.emit("Куплено: %s" % Db.WEAPONS[wid]["name"], "good")
	_update_money()


func _buy_armor(aid: String) -> void:
	var p = world.get("local_actor")
	if p == null or p.dead:
		return
	var price := int(Db.ARMOR[aid].get("price", 0))
	if int(p.money) < price:
		Sfx.play_ui("ui_deny")
		Signals.notify.emit("Не хватает денег", "bad")
		return
	p.money -= price
	p.give_armor(aid)
	Sfx.play_ui("ui_buy")
	Signals.notify.emit("Броня: %s" % Db.ARMOR[aid]["name"], "good")
	_update_money()
