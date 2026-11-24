class_name TopBar
extends Control
## Barre du haut commune (accueil, aventure…) : un bandeau bleu nuit d'un bord à l'autre,
## collé en haut de l'écran sous la barre d'état d'Android (référence validée le 2026-11-23).
## Elle porte l'avatar, le pseudo, le niveau et sa barre d'XP, les talents et le réglage, et
## se met à jour seule avec le compte. Les coordonnées sont des pixels de l'image d'accueil
## (941 px de large), mise à la largeur de l'écran.
##
## Usage : var bar := TopBar.attach(self) ; le contenu de l'écran commence à bar.bottom().

signal message(text: String)  ## Un texte à afficher en bulle (toucher les talents).

const P := preload("res://scripts/ui/ui_theme.gd")
const COINS := preload("res://assets/duel/pieces.png")
const CROWN_ICON := preload("res://assets/duel/couronne.png")

const ART_W := 941.0
const BAND_H := 146.0
const BAND_Y := 6.0  ## Haut du bandeau dans l'image : les rectangles ci-dessous en partent.
const AVATAR := Rect2(46, 18, 124, 124)
const PROFILE_TAP := Rect2(40, 18, 444, 124)
const XP_BAR := Rect2(200, 126, 230, 8)
const TALENT_PILL := Rect2(580, 32, 250, 92)
const GEAR := Rect2(842, 35, 74, 74)
const SHADOW := 16.0

var _s := 1.0
var _safe := 0.0
var _name: Label
var _initial: Label
var _level: Label
var _xp_fill: Panel
var _talents: Label
var _rank_s: Control  ## Badge du Rang S, à droite du niveau.


## Pose la barre sur un écran : ses bulles s'affichent sur l'écran, et elle passe au premier
## plan une fois l'écran construit (les fenêtres ouvertes ensuite la recouvrent).
static func attach(host: Control) -> TopBar:
	var bar := TopBar.new()
	host.add_child(bar)
	bar.message.connect(func(text: String): Glass.toast(host, text))
	host.ready.connect(func(): host.move_child(bar, -1), CONNECT_ONE_SHOT)
	return bar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := get_viewport_rect().size.x
	_s = width / ART_W
	_safe = _safe_top()
	position = Vector2.ZERO
	size = Vector2(width, bottom() + SHADOW * _s)
	_build()
	refresh()
	Online.account_changed.connect(refresh)
	Online.state_changed.connect(func(_state): refresh())


## Bas du bandeau, en pixels de l'écran.
func bottom() -> float:
	return _safe + BAND_H * _s


func refresh() -> void:
	# Le compte gardé sur le téléphone s'affiche tout de suite, avant que le serveur réponde.
	var online: bool = Online.is_known()
	_name.text = Online.username if online else ("Connexion…" if Online.state == Online.State.CONNECTING else "Hors ligne")
	_initial.text = (Online.username.substr(0, 1) if online else "?").to_upper()
	_talents.text = str(Online.talents()) if online else "–"
	var p := Progression.from_xp(Online.xp() if online else 0)
	_level.text = "Niveau %d" % p["level"]
	_rank_s.visible = online and Progression.has_rank_s(Online.rank_place)
	_rank_s.position.x = _level.position.x + _level.get_combined_minimum_size().x + 6 * _s
	var ratio := float(p["in_level"]) / float(p["to_next"])
	_xp_fill.visible = ratio > 0.0
	# Un minimum visible, pour que la barre ne paraisse pas cassée à 1 XP.
	_xp_fill.size.x = maxf(XP_BAR.size.x * _s * ratio, XP_BAR.size.y * _s)


func _build() -> void:
	var band := _gradient(Rect2(0, 0, size.x, bottom()), Color("1c3672"), Color("0e1f4c"))
	add_child(band)
	var line := ColorRect.new()
	line.color = Color(Color("c99a3c"), 0.55)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(0, bottom() - maxf(2, 2 * _s))
	line.size = Vector2(size.x, maxf(2, 2 * _s))
	add_child(line)
	add_child(_gradient(Rect2(0, bottom(), size.x, SHADOW * _s), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)))

	_name = _text(34, Color.WHITE)
	_put(_name, Rect2(196, 34, 330, 44))
	var crown := _icon(CROWN_ICON)
	_put(crown, Rect2(198, 86, 36, 32))
	_level = _text(27, Color("f6c24a"))
	_put(_level, Rect2(242, 84, 200, 36))
	_rank_s = Glass.s_badge(14)
	_rank_s.size = _rank_s.custom_minimum_size
	_rank_s.position.y = _level.position.y + (_level.size.y - _rank_s.size.y) / 2
	add_child(_rank_s)
	var bar := _patch(Color(1, 1, 1, 0.14), 4)
	_put(bar, XP_BAR)
	_xp_fill = _patch(Color("f6b93b"), 4)
	_xp_fill.size = Vector2(0, bar.size.y)
	bar.add_child(_xp_fill)

	var avatar := Control.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(avatar, AVATAR)
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color("1f8f8c")
	s.set_corner_radius_all(int(AVATAR.size.x * _s))
	s.border_color = Color("f6c24a")
	s.set_border_width_all(int(maxf(3, 6 * _s)))
	s.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", s)
	avatar.add_child(ring)
	_initial = P.title("", 26, P.CREAM)
	_initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(_initial)

	_put(_icon(COINS), Rect2(586, 40, 92, 80))
	_talents = _text(40, Color.WHITE)
	_put(_talents, Rect2(688, 34, 140, 46))
	var unit := _text(25, Color("f6c24a"))
	unit.text = "Talents"
	_put(unit, Rect2(688, 82, 140, 34))
	_put(Gear.new(), GEAR.grow(-8))

	_tap(PROFILE_TAP, _open_profile)
	_tap(TALENT_PILL, func(): message.emit("Les talents se gagnent en jouant, et 10 arrivent chaque jour avec le pain quotidien."))
	_tap(GEAR, _open_profile)


func _open_profile() -> void:
	get_tree().change_scene_to_file("res://scenes/profile.tscn")


## Place un élément d'après son rectangle dans l'image.
func _put(c: Control, r: Rect2) -> void:
	c.position = Vector2(r.position.x * _s, _safe + (r.position.y - BAND_Y) * _s)
	c.size = r.size * _s
	add_child(c)


func _tap(r: Rect2, action: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(action)
	_put(b, r)


func _text(img_px: float, color: Color) -> Label:
	var l := P.label("", img_px * _s / P.SCALE, color, 900, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _icon(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _patch(color: Color, radius_img: float) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", P.box(color, int(radius_img * _s)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _gradient(r: Rect2, from: Color, to: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = r.position
	tr.size = r.size
	return tr


## Hauteur de la barre d'état d'Android (zone sûre), en pixels du jeu.
func _safe_top() -> float:
	var win := DisplayServer.window_get_size()
	if OS.get_name() != "Android" or win.y <= 0:
		return 0.0
	return DisplayServer.get_display_safe_area().position.y * get_viewport_rect().size.y / win.y


## Roue des réglages dorée, dessinée.
class Gear extends Control:
	const TEETH := 8

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var outer := r * 0.98
		var inner := r * 0.74
		var points := PackedVector2Array()
		for i in TEETH * 4:
			var a := TAU * i / (TEETH * 4) - PI / 2
			var radius := outer if (i % 4 == 1 or i % 4 == 2) else inner
			points.append(c + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(points, Color("f2d58c"))
		draw_circle(c, r * 0.62, Color("f2d58c"))
		draw_circle(c, r * 0.3, Color("13275e"))
		draw_arc(c, r * 0.62, 0, TAU, 48, Color("c99a3c"), maxf(1.5, r * 0.06), true)
