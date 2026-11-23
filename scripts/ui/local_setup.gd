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
	UiTheme.background(self)
	_restore_from_session()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	scroll.add_child(margin)
	var v := UiTheme.vbox(18)
	margin.add_child(v)

	var title := UiTheme.label("Partie à deux", 48)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(title)
	v.add_child(UiTheme.label("Sur le même téléphone, en se le passant", 24))

	v.add_child(_section("Joueurs"))
	for i in 2:
		var e := LineEdit.new()
		e.text = Session.player_names[i]
		e.placeholder_text = "Joueur %d" % (i + 1)
		e.max_length = 16
		e.custom_minimum_size = Vector2(0, 72)
		v.add_child(e)
		_names.append(e)

	v.add_child(_section("Difficulté"))
	var diffs := {"lait": "Lait\nfacile", "manne": "Manne\nmoyen", "solide": "Nourriture solide\ndifficile"}
	var dh := UiTheme.hbox(10)
	for d in CardData.DIFFICULTIES:
		var b := UiTheme.button(diffs[d], _on_difficulty.bind(d), 24)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 110)
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
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for c in labels:
		var b := UiTheme.button(labels[c], _on_content.bind(c), 24)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		_content_buttons[c] = b
	v.add_child(grid)

	_books_wrap = UiTheme.vbox(8)
	_books_wrap.add_child(UiTheme.label("Coche un ou plusieurs livres :", 24))
	_books_box = GridContainer.new()
	_books_box.columns = 2
	_books_wrap.add_child(_books_box)
	v.add_child(_books_wrap)

	_info = UiTheme.label("", 24)
	v.add_child(_info)
	_start = UiTheme.button("Commencer", _on_start, 36)
	v.add_child(_start)
	v.add_child(UiTheme.button("Retour", _back, 26))

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
	var l := UiTheme.label(text, 30, false, HORIZONTAL_ALIGNMENT_LEFT)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	return l


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
		cb.add_theme_font_size_override("font_size", 26)
		cb.button_pressed = book in _chosen_books
		cb.toggled.connect(_on_book_toggled.bind(book))
		_books_box.add_child(cb)
	_refresh_count()


func _refresh_count() -> void:
	var n := Session.bank.filter(_current_filter()).size()
	var needed := DeckBuilder.min_pool_size()
	if n >= needed:
		_info.text = "%d questions disponibles" % n
		_info.modulate = Color.WHITE
	else:
		_info.text = "Pas encore assez de questions (%d sur %d)" % [n, needed]
		_info.modulate = Color(1, 0.6, 0.5)
	_start.disabled = n < needed


func _on_start() -> void:
	for i in 2:
		var name := _names[i].text.strip_edges()
		Session.player_names[i] = name if not name.is_empty() else "Joueur %d" % (i + 1)
	if Session.player_names[0] == Session.player_names[1]:
		Session.player_names[1] += " (2)"
	Session.filter = _current_filter()
	get_tree().change_scene_to_file("res://scenes/local_match.tscn")


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
