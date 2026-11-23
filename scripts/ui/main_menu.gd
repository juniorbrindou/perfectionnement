extends Control
## Écran d'accueil (maquette « Accueil ») : arche de pierre éclairée, titre dans une
## bulle, paquet de cartes qui s'ouvre en éventail, modes de jeu en bas.

const P := preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	theme = P.get_theme()
	var wall := Shapes.StoneWall.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wall)

	var arch := Shapes.Arch.new()
	_place_center_x(arch, 300, 560, 90)
	add_child(arch)
	var light := Shapes.Glow.new()
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.center = Vector2(0.5, 0.3)
	light.color = Color("fff2c2")
	light.radius_ratio = 0.7
	arch.add_child(light)

	var floor_panel := Panel.new()
	var fs := P.box(Color("5a2d12"), 0)
	fs.corner_radius_top_left = P.px(120)
	fs.corner_radius_top_right = P.px(120)
	floor_panel.add_theme_stylebox_override("panel", fs)
	floor_panel.anchor_top = 1.0
	floor_panel.anchor_bottom = 1.0
	floor_panel.anchor_right = 1.0
	floor_panel.offset_left = -P.px(40)
	floor_panel.offset_right = P.px(40)
	floor_panel.offset_top = -P.px(250)
	floor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_panel)

	for side in [-1, 1]:
		var who := "David" if side < 0 else "Esther"
		var slot := Panel.new()
		var ss := P.box(Color(P.NIGHT, 0.25), P.px(48))
		ss.corner_radius_bottom_left = P.px(16)
		ss.corner_radius_bottom_right = P.px(16)
		ss.border_color = Color(P.CREAM, 0.7)
		ss.set_border_width_all(P.px(3))
		slot.add_theme_stylebox_override("panel", ss)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size = Vector2(P.px(96), P.px(150))
		slot.position = Vector2(P.px(8) if side < 0 else P.px(390 - 8 - 96), P.px(250))
		var sl := P.label("Illustration\n%s" % who, 12, P.CREAM, 900)
		sl.set_anchors_preset(Control.PRESET_FULL_RECT)
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(sl)
		add_child(slot)

	_title_bubble()
	_card_fan()
	_bottom_actions()
	_player_pill()


## Pastille du joueur en haut à gauche : pseudo et état de connexion ; ouvre le profil.
var _pill: Button
var _pill_row: HBoxContainer


func _player_pill() -> void:
	_pill = Button.new()
	_pill.focus_mode = Control.FOCUS_NONE
	var s := P.box(Color(P.NIGHT, 0.75), P.px(999), P.px(6), P.px(5))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_pill.add_theme_stylebox_override(state, s)
	_pill.position = Vector2(P.px(16), P.px(40))
	_pill.custom_minimum_size = Vector2(P.px(150), P.px(36))
	_pill.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/profile.tscn"))
	add_child(_pill)
	_pill_row = P.hbox(8)
	_pill_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pill_row.offset_left = P.px(5)
	_pill_row.offset_right = -P.px(12)
	_pill.add_child(_pill_row)
	_refresh_pill()
	Online.account_changed.connect(_refresh_pill)
	Online.state_changed.connect(_on_online_state)


func _on_online_state(_s) -> void:
	_refresh_pill()


func _refresh_pill() -> void:
	for child in _pill_row.get_children():
		child.queue_free()
	var online: bool = Online.is_online()
	var shown: String = Online.username if online else ("Connexion…" if Online.state == Online.State.CONNECTING else "Hors ligne")
	var av := P.avatar(shown if online else "?", P.TEAL if online else Color("8d86a3"), 26)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pill_row.add_child(av)
	var l := P.label(shown, 14, P.CREAM, 900, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pill_row.add_child(l)
	_pill.reset_size()

func _place_center_x(c: Control, w: float, h: float, top: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = -P.px(w) / 2.0
	c.offset_right = P.px(w) / 2.0
	c.offset_top = P.px(top)
	c.offset_bottom = P.px(top + h)


func _title_bubble() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_center_x(holder, 330, 110, 108)
	add_child(holder)
	var bubble := PanelContainer.new()
	var s := P.box(P.CREAM, P.px(26), P.px(20), P.px(12))
	s.border_color = P.VIOLET
	s.set_border_width_all(P.px(5))
	s.border_width_bottom = P.px(11)
	bubble.add_theme_stylebox_override("panel", s)
	bubble.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := P.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(P.title("Perfectionnement", 34, P.FRAMBOISE))
	v.add_child(P.label("Le duel des cartes bibliques", 14, P.VIOLET, 900))
	bubble.add_child(v)
	holder.add_child(bubble)
	holder.resized.connect(func(): holder.pivot_offset = holder.size / 2)
	holder.rotation_degrees = -3


## Deux cartes questions et un dos, qui s'ouvrent en éventail à l'arrivée.
func _card_fan() -> void:
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_center_x(stage, 300, 290, 330)
	add_child(stage)
	var cards: Array[Control] = [
		_mini_question(P.TEAL, "Combien de fils Jacob avait-il ?", ["Sept", "Douze", "Dix", "Trois"]),
		_mini_question(P.GOLD, "Quel roi demanda la sagesse ?", ["David", "Saül", "Salomon", "Josias"]),
		_back_card(),
	]
	var sizes := [Vector2(128, 186), Vector2(128, 186), Vector2(146, 212)]
	var targets := [Vector2(6, 40), Vector2(166, 40), Vector2(77, 10)]
	var angles := [-14.0, 13.0, 0.0]
	for i in cards.size():
		var c := cards[i]
		c.size = Vector2(P.px(sizes[i].x), P.px(sizes[i].y))
		c.pivot_offset = c.size / 2
		c.position = Vector2(P.px(targets[2].x), P.px(targets[2].y))
		stage.add_child(c)
	var t := create_tween().set_parallel()
	for i in 2:
		var target := Vector2(P.px(targets[i].x), P.px(targets[i].y))
		t.tween_property(cards[i], "position", target, 0.7).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(cards[i], "rotation_degrees", angles[i], 0.7).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mini_question(color: Color, question: String, answers: Array) -> Control:
	var card := PanelContainer.new()
	var s := P.box(color, P.px(14), P.px(10), P.px(10))
	s.border_color = P.YELLOW
	s.set_border_width_all(P.px(4))
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = P.px(10)
	s.shadow_offset = Vector2(0, P.px(8))
	card.add_theme_stylebox_override("panel", s)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := P.vbox(8)
	card.add_child(v)
	var q := PanelContainer.new()
	q.add_theme_stylebox_override("panel", P.box(P.CREAM, P.px(10), P.px(6), P.px(8)))
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_child(P.label(question, 10, P.NIGHT, 900))
	v.add_child(q)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", P.box(P.FRAMBOISE, P.px(8), P.px(8), P.px(6)))
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := P.vbox(0)
	for i in answers.size():
		var row := P.hbox(4)
		for part in [["%s)" % CardView.LETTERS[i], P.YELLOW], [answers[i], P.CREAM]]:
			var l := P.title(part[0], 12, part[1], HORIZONTAL_ALIGNMENT_LEFT)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(l)
		lines.add_child(row)
	band.add_child(lines)
	v.add_child(band)
	return card


func _back_card() -> Control:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", P.box(P.FRAMBOISE, P.px(16)))
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := Shapes.CardBackArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(art)
	var border := Panel.new()
	var bs := P.box(Color.TRANSPARENT, P.px(16))
	bs.border_color = P.YELLOW
	bs.set_border_width_all(P.px(5))
	bs.draw_center = false
	border.add_theme_stylebox_override("panel", bs)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(border)
	return card


func _bottom_actions() -> void:
	var m := P.margins(18, 0, 18, 24)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var v := P.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_END
	m.add_child(v)
	var play := P.button("Jouer à deux", func(): get_tree().change_scene_to_file("res://scenes/local_setup.tscn"), 25)
	play.custom_minimum_size = Vector2(0, P.px(68))
	v.add_child(play)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", P.px(8))
	for mode_name in ["Aventure", "En ligne", "Salons"]:
		var b := P.button("%s\nbientôt" % mode_name, func(): pass, 15, "GhostButton")
		b.disabled = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, P.px(56))
		grid.add_child(b)
	v.add_child(grid)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
