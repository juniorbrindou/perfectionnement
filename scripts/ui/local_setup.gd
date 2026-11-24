extends Control
## Configuration d'une partie à deux sur le même téléphone :
## noms, difficulté et contenu (PRD §3.2).

enum ContentChoice { BIBLE, AT, NT, BOOKS }

var _names: Array[LineEdit] = []
var _difficulty := "lait"
var _content := ContentChoice.BIBLE
var _chosen_books: Array[String] = []
var _diff_buttons := {}
var _content_buttons := {}
var _books_box: GridContainer
var _books_wrap: Control
var _info: Label
var _start: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	Glass.background(self, 0.6)
	_restore_from_session()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.offset_top = TopBar.attach(self).bottom()
	var margin := UiTheme.margins(20, 20, 20, 30)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var v := UiTheme.vbox(12)
	margin.add_child(v)

	v.add_child(Glass.title("Partie à deux", 34, Glass.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UiTheme.label("Un seul téléphone, que vous vous passez à chaque question.", 15, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))

	v.add_child(_section("Joueurs"))
	var colors := [Color("1fa9a3"), Color("3a6fd8")]
	for i in 2:
		var row := UiTheme.hbox(10)
		var av := Glass.avatar(Session.player_names[i], colors[i], 44)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(av)
		var e := LineEdit.new()
		e.text = Session.player_names[i]
		e.placeholder_text = "Joueur %d" % (i + 1)
		e.max_length = 16
		e.add_theme_font_size_override("font_size", UiTheme.px(17))
		e.custom_minimum_size = Vector2(0, UiTheme.px(50))
		for state in ["normal", "focus"]:
			e.add_theme_stylebox_override(state, Glass.panel_style(Glass.PANEL_DARK, 14, Color(Glass.RING, 0.7) if state == "focus" else Color(1, 1, 1, 0.25), 14, 6))
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(e)
		v.add_child(row)
		_names.append(e)

	v.add_child(_section("Difficulté"))
	var diffs := {"lait": "Lait\nfacile", "manne": "Manne\nmoyen", "solide": "Nourriture\nsolide"}
	var dh := UiTheme.hbox(8)
	for d in CardData.DIFFICULTIES:
		var b := UiTheme.button(diffs[d], _on_difficulty.bind(d), 16, "ChipToggle")
		b.toggle_mode = true
		_dye(b, UiTheme.difficulty_color(d))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UiTheme.px(68))
		dh.add_child(b)
		_diff_buttons[d] = b
	v.add_child(dh)

	v.add_child(_section("Contenu"))
	var labels := {
		ContentChoice.BIBLE: "Toute la Bible",
		ContentChoice.AT: "Ancien Testament",
		ContentChoice.NT: "Nouveau Testament",
		ContentChoice.BOOKS: "Livres choisis",
	}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiTheme.px(8))
	grid.add_theme_constant_override("v_separation", UiTheme.px(8))
	for c in labels:
		var b := UiTheme.button(labels[c], _on_content.bind(c), 15, "ChipToggle")
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, UiTheme.px(50))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_glass_toggle(b)
		grid.add_child(b)
		_content_buttons[c] = b
	v.add_child(grid)

	_books_wrap = UiTheme.vbox(6)
	_books_wrap.add_child(UiTheme.label("Coche un ou plusieurs livres.", 14, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
	_books_box = GridContainer.new()
	_books_box.columns = 2
	_books_wrap.add_child(_books_box)
	v.add_child(_books_wrap)

	v.add_child(UiTheme.spacer(6))
	_info = UiTheme.label("", 14, Glass.PALE)
	v.add_child(_info)
	_start = UiTheme.button("Commencer la partie", _on_start, 23)
	_start.custom_minimum_size = Vector2(0, UiTheme.px(64))
	v.add_child(_start)
	v.add_child(Glass.button("Retour", _back, 18, 56))

	_refresh()


func _restore_from_session() -> void:
	var f := Session.filter
	_difficulty = f.difficulty
	match f.scope:
		ContentFilter.Scope.TESTAMENT:
			_content = ContentChoice.AT if f.testament == "AT" else ContentChoice.NT
		ContentFilter.Scope.BOOKS:
			_content = ContentChoice.BOOKS
			_chosen_books = f.books.duplicate()


func _section(text: String) -> Label:
	var l := UiTheme.title(text, 19, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(0, UiTheme.px(30))
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## Bouton de difficulté : contour puis plein dans la couleur de la carte.
func _dye(b: Button, color: Color) -> void:
	var off := UiTheme.box(Color(color, 0.18), UiTheme.px(14), UiTheme.px(8), UiTheme.px(8))
	off.border_color = color.lightened(0.2)
	off.set_border_width_all(UiTheme.px(3))
	var on := UiTheme.box(color, UiTheme.px(14), UiTheme.px(8), UiTheme.px(8))
	on.border_color = Glass.RING
	on.set_border_width_all(UiTheme.px(3))
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, off)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, on)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, UiTheme.CREAM)

## Choix de contenu : verre bleu nuit, doré quand il est choisi.
func _glass_toggle(b: Button) -> void:
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, Glass.panel_style(Glass.PANEL_DARK, 14, Color(1, 1, 1, 0.25), 8, 6))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, Glass.panel_style(Glass.GOLD, 14, Color("ffe9a8"), 8, 6))
	for state in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(state, UiTheme.CREAM)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, Glass.INK)


func _on_difficulty(d: String) -> void:
	_difficulty = d
	_chosen_books.clear()
	_refresh()


func _on_content(c: ContentChoice) -> void:
	_content = c
	_refresh()


func _on_book_toggled(on: bool, book: String) -> void:
	if on and not book in _chosen_books:
		_chosen_books.append(book)
	elif not on:
		_chosen_books.erase(book)
	_refresh_count()


func _current_filter() -> ContentFilter:
	match _content:
		ContentChoice.AT:
			return ContentFilter.for_testament(_difficulty, "AT")
		ContentChoice.NT:
			return ContentFilter.for_testament(_difficulty, "NT")
		ContentChoice.BOOKS:
			return ContentFilter.for_books(_difficulty, _chosen_books)
	return ContentFilter.bible(_difficulty)


func _refresh() -> void:
	for d in _diff_buttons:
		_diff_buttons[d].set_pressed_no_signal(d == _difficulty)
	for c in _content_buttons:
		_content_buttons[c].set_pressed_no_signal(c == _content)
	_books_wrap.visible = _content == ContentChoice.BOOKS
	for child in _books_box.get_children():
		child.queue_free()
	for book in Session.bank.books_for(_difficulty):
		var cb := CheckBox.new()
		cb.text = book
		cb.add_theme_font_size_override("font_size", UiTheme.px(15))
		cb.button_pressed = book in _chosen_books
		cb.toggled.connect(_on_book_toggled.bind(book))
		_books_box.add_child(cb)
	_refresh_count()


func _refresh_count() -> void:
	var n := Session.bank.filter(_current_filter()).size()
	var needed := DeckBuilder.min_pool_size()
	if n >= needed:
		_info.text = "%d questions disponibles" % n
		_info.add_theme_color_override("font_color", Glass.PALE)
	else:
		_info.text = "Pas encore assez de questions (%d sur %d)" % [n, needed]
		_info.add_theme_color_override("font_color", Color("ff8fa3"))
	_start.disabled = n < needed


func _on_start() -> void:
	for i in 2:
		var typed := _names[i].text.strip_edges()
		Session.player_names[i] = typed if not typed.is_empty() else "Joueur %d" % (i + 1)
	if Session.player_names[0] == Session.player_names[1]:
		Session.player_names[1] += " (2)"
	Session.filter = _current_filter()
	get_tree().change_scene_to_file("res://scenes/local_match.tscn")


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
