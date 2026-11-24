class_name Splash
extends CanvasLayer
## Animation de démarrage « Le duel s'ouvre » (docs/SPLASH.md, validée le 2026-11-24) : deux
## cartes se percutent, la Bible s'élève de la lumière, l'enseigne « Perfectionnement » apparaît,
## puis le logo glisse jusqu'au titre peint de l'accueil, qui apparaît dessous.
##
## Le minutage et les courbes reprennent exactement docs/maquettes/splash.html (scène de
## 375 × 812 px, mise à la taille de l'écran). Tout est calculé à partir d'une seule horloge : un
## toucher n'importe où passe directement à l'accueil. Les calques du logo sont des fichiers
## (assets/logo/logo_livre.png, logo_enseigne.png) : les remplacer suffit, sans toucher au code.
##
## Usage : l'accueil l'ajoute au démarrage à froid seulement (Splash.shown).

const LIVRE := preload("res://assets/logo/logo_livre.png")
const ENSEIGNE := preload("res://assets/logo/logo_enseigne.png")
const CARD_BACK := preload("res://assets/duel/dos_carte.png")
const FRAME := Vector2(375, 812)  ## Scène de l'aperçu validé.
const END_MS := 3060.0
## Titre peint de l'accueil (pixels de assets/accueil/accueil.png, 941 px de large) : le logo
## finit exactement dessus.
const HOME_TITLE := Rect2(84, 115, 784, 410)
const HOME_ART := Vector2(941, 1672)

static var shown := false  ## Une seule fois par lancement.

var _t := 0.0  ## Millisecondes depuis le début.
var _k := 1.0  ## Échelle scène → écran.
var _screen := Vector2.ZERO
var _center := Vector2.ZERO  ## Centre de la scène (50 %, 46 %).
var _root: Control
var _backdrop: Control  ## Fond, poussière et colonne : s'effacent pour laisser voir l'accueil.
var _dust: Dust
var _column: TextureRect
var _cards: Array[TextureRect] = []
var _flash: TextureRect
var _sparks: Sparks
var _logo: Control
var _livre: TextureRect
var _enseigne: TextureRect
var _shine: ShaderMaterial
var _logo_from := Rect2()
var _logo_to := Rect2()
var _cues := {300: "carte", 790: "feu", 1300: "juste"}  ## Sons, à l'instant (ms).
var _done := false


func _ready() -> void:
	layer = 90
	_screen = get_viewport().get_visible_rect().size
	_k = _screen.x / FRAME.x
	_center = Vector2(_screen.x * 0.5, _screen.y * 0.46)
	Sound.begin_intro()

	_root = Control.new()
	_root.size = _screen
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_finish())
	add_child(_root)

	_backdrop = Control.new()
	_backdrop.size = _screen
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)
	var bg := TextureRect.new()
	bg.texture = _radial([Color("0d2a6b"), Color("071b48"), Color("03102a"), Color("03102a")], [0.0, 0.4, 0.75, 1.0], 0.9)
	_stretch(bg, Rect2(Vector2.ZERO, _screen))
	_backdrop.add_child(bg)
	_dust = Dust.new(_k)
	_dust.size = _screen
	_backdrop.add_child(_dust)
	_column = TextureRect.new()
	_column.texture = _band()
	_stretch(_column, Rect2(_screen.x / 2 - 80 * _k, 0, 160 * _k, _screen.y))
	_column.pivot_offset = _column.size / 2
	_backdrop.add_child(_column)

	for side in [-1.0, 1.0]:
		var c := TextureRect.new()
		c.texture = CARD_BACK
		_stretch(c, Rect2(_center - Vector2(56, 66) * _k, Vector2(112, 133) * _k))
		c.pivot_offset = c.size / 2
		c.set_meta("side", side)
		_root.add_child(c)
		_cards.append(c)

	_flash = TextureRect.new()
	_flash.texture = _radial([Color("fffbe6"), Color("ffd36a"), Color(1.0, 0.7, 0.24, 0.0), Color(1.0, 0.7, 0.24, 0.0)], [0.0, 0.3, 0.7, 1.0], 0.5, Vector2(0.5, 0.5))
	_stretch(_flash, Rect2(_center - Vector2(15, 15) * _k, Vector2(30, 30) * _k))
	_flash.pivot_offset = _flash.size / 2
	_root.add_child(_flash)
	_sparks = Sparks.new(_center, _k)
	_sparks.size = _screen
	_root.add_child(_sparks)

	# Le logo : livre derrière, enseigne devant, reflet sur l'enseigne.
	_logo_from = Rect2(_center - Vector2(182, 96) * _k, Vector2(365, 191) * _k)
	var s := _screen.x / HOME_ART.x
	var top := maxf(_screen.y - HOME_ART.y * s, 0.0)
	_logo_to = Rect2(HOME_TITLE.position.x * s, top + HOME_TITLE.position.y * s, HOME_TITLE.size.x * s, HOME_TITLE.size.y * s)
	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_logo)
	_livre = _layer(LIVRE, Vector2(0.51, 0.28))
	_enseigne = _layer(ENSEIGNE, Vector2(0.5, 0.62))
	var shine := _layer(ENSEIGNE, Vector2(0.5, 0.62))
	_shine = ShaderMaterial.new()
	_shine.shader = preload("res://scripts/ui/splash_reflet.gdshader")
	shine.material = _shine
	shine.set_meta("shine", true)
	_logo_rect(_logo_from)
	_update()


func _process(delta: float) -> void:
	if _done:
		return
	var before := _t
	_t += delta * 1000.0
	for at in _cues:
		if before < at and _t >= at:
			_play(_cues[at])
	_update()
	if _t >= END_MS:
		_finish()


## Passe à l'accueil (fin de l'animation, ou toucher).
func _finish() -> void:
	if _done:
		return
	_done = true
	Sound.end_intro()
	queue_free()


func _play(effect: String) -> void:
	var p := Sound.play(effect, -2.0)
	if p and effect == "feu":  # Le feu ne dure que 0,7 s, en fondu.
		var t := p.create_tween()
		t.tween_property(p, "volume_db", -40.0, 0.7)
		t.tween_callback(p.stop)


# ---------------------------------------------------------------- L'horloge

func _update() -> void:
	var t := _t
	_dust.t = t
	_dust.queue_redraw()
	_sparks.t = t
	_sparks.queue_redraw()

	# 1. Les deux cartes se rencontrent, puis 3. se retournent dans la lumière.
	for c in _cards:
		var side: float = c.get_meta("side")
		var p := _bezier(0.2, 0.8, 0.3, 1.0, _progress(t, 280, 520))
		var x := lerpf(330.0, 34.0, p)
		var rot := lerpf(30.0, 8.0, p)
		var alpha := _keys(p, [[0.0, 0.0], [0.3, 1.0], [1.0, 1.0]])
		var flip := 0.0
		if t >= 860:
			var q := _bezier(0.42, 0.0, 1.0, 1.0, _progress(t, 860, 300))
			x = lerpf(34.0, 10.0, q)
			flip = q * 90.0
			alpha = 1.0 - q
		c.position = _center - Vector2(56, 66) * _k + Vector2(side * x * _k, 0)
		c.rotation_degrees = side * rot
		c.scale = Vector2(maxf(cos(deg_to_rad(flip)), 0.001), 1.0)
		c.modulate.a = alpha

	# 2. Choc : éclair et secousse (les étincelles sont dessinées par Sparks).
	var fp := _bezier(0.0, 0.0, 0.58, 1.0, _progress(t, 790, 600))
	_flash.modulate.a = _keys(fp, [[0.0, 0.0], [0.35, 1.0], [1.0, 0.0]]) if t >= 790 else 0.0
	var fs := _keys(fp, [[0.0, 0.5], [0.35, 9.0], [1.0, 14.0]])
	_flash.scale = Vector2(fs, fs)
	var sp := _progress(t, 800, 260)
	var shake := Vector2.ZERO
	if sp > 0.0 and sp < 1.0:
		shake = _keys2(sp, [[0.0, Vector2.ZERO], [0.25, Vector2(-5, 3)], [0.5, Vector2(4, -3)], [0.75, Vector2(-2, 1)], [1.0, Vector2.ZERO]]) * _k
	_root.position = shake

	# La colonne de lumière dorée.
	var cp := _progress(t, 850, 900)
	_column.modulate.a = _keys(cp, [[0.0, 0.0], [0.4, 1.0], [1.0, 0.0]]) if t >= 850 else 0.0
	_column.scale = Vector2(_keys(cp, [[0.0, 0.2], [0.4, 1.0], [1.0, 1.4]]), 1.0)

	# 4. La Bible s'élève et s'ouvre.
	var lp := _bezier(0.2, 0.8, 0.3, 1.0, _progress(t, 920, 520))
	var ly := _keys(lp, [[0.0, 60.0], [0.7, -6.0], [1.0, 0.0]]) * _k
	var lsx := _keys(lp, [[0.0, 0.35], [0.7, 1.06], [1.0, 1.0]])
	var lsy := _keys(lp, [[0.0, 0.2], [0.7, 1.06], [1.0, 1.0]])
	var glow := _keys(lp, [[0.0, 3.0], [0.7, 1.6], [1.0, 1.0]])
	_livre.position = Vector2(0, ly)
	_livre.scale = Vector2(lsx, lsy)
	_livre.modulate = Color(glow, glow, glow, _keys(lp, [[0.0, 0.0], [0.7, 1.0], [1.0, 1.0]]) * _fade_out(t))

	# 5. L'enseigne apparaît avec un léger rebond.
	var ep := _bezier(0.3, 1.2, 0.5, 1.0, _progress(t, 1280, 480))
	var es := _keys(ep, [[0.0, 1.16], [0.7, 0.97], [1.0, 1.0]])
	_enseigne.scale = Vector2(es, es)
	_enseigne.modulate.a = _keys(ep, [[0.0, 0.0], [0.35, 1.0], [1.0, 1.0]]) * _fade_out(t)

	# 6. Le reflet balaie les lettres (bande de 105°, comme le dégradé de la maquette).
	var rp := _bezier(0.42, 0.0, 0.58, 1.0, _progress(t, 1780, 520))
	_shine.set_shader_parameter("center", -1.5 + 4.0 * rp)
	for child in _logo.get_children():
		if child.has_meta("shine"):
			child.scale = _enseigne.scale
			child.visible = t >= 1780 and t <= 2300

	# 7. Le logo monte jusqu'au titre de l'accueil, qui apparaît dessous.
	var mp := _bezier(0.5, 0.0, 0.2, 1.0, _progress(t, 2280, 560))
	_logo_rect(Rect2(_logo_from.position.lerp(_logo_to.position, mp), _logo_from.size.lerp(_logo_to.size, mp)))
	_backdrop.modulate.a = 1.0 - _bezier(0.42, 0.0, 1.0, 1.0, _progress(t, 2620, 380))
	_cards[0].visible = t < 1200
	_cards[1].visible = t < 1200


## Les deux calques du logo s'effacent quand il est en place.
func _fade_out(t: float) -> float:
	return 1.0 - _progress(t, 2840, 220)


# ---------------------------------------------------------------- Courbes

## Avancement (0 à 1) d'une animation qui commence à `delay` ms et dure `duration` ms.
static func _progress(t: float, delay: float, duration: float) -> float:
	return clampf((t - delay) / duration, 0.0, 1.0)


## Interpolation linéaire entre images clés [[décalage, valeur], …], comme en CSS.
static func _keys(p: float, frames: Array) -> float:
	for i in range(1, frames.size()):
		if p <= frames[i][0]:
			var a: Array = frames[i - 1]
			var b: Array = frames[i]
			return lerpf(a[1], b[1], (p - a[0]) / maxf(b[0] - a[0], 0.0001))
	return frames[-1][1]


static func _keys2(p: float, frames: Array) -> Vector2:
	for i in range(1, frames.size()):
		if p <= frames[i][0]:
			var a: Array = frames[i - 1]
			var b: Array = frames[i]
			return (a[1] as Vector2).lerp(b[1], (p - a[0]) / maxf(b[0] - a[0], 0.0001))
	return frames[-1][1]


## cubic-bezier(x1, y1, x2, y2) de CSS : valeur de la courbe à l'instant x.
static func _bezier(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
	if x <= 0.0 or x >= 1.0:
		return x
	var lo := 0.0
	var hi := 1.0
	var u := x
	for i in 24:
		u = (lo + hi) / 2.0
		var bx := 3.0 * (1.0 - u) * (1.0 - u) * u * x1 + 3.0 * (1.0 - u) * u * u * x2 + u * u * u
		if bx < x:
			lo = u
		else:
			hi = u
	return 3.0 * (1.0 - u) * (1.0 - u) * u * y1 + 3.0 * (1.0 - u) * u * u * y2 + u * u * u


# ---------------------------------------------------------------- Construction

func _layer(tex: Texture2D, origin: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta("origin", origin)
	_logo.add_child(r)
	return r


## Place le logo et ses calques ; les calques gardent leur point d'origine (transform-origin).
func _logo_rect(r: Rect2) -> void:
	_logo.position = r.position
	_logo.size = r.size
	for c in _logo.get_children():
		c.size = r.size
		c.pivot_offset = r.size * (c.get_meta("origin") as Vector2)


func _stretch(r: TextureRect, rect: Rect2) -> void:
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = rect.position
	r.size = rect.size


static func _radial(colors: Array, offsets: Array, radius: float, center := Vector2(0.5, 0.46)) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = center
	tex.fill_to = center + Vector2(radius, 0)
	tex.width = 256
	tex.height = 256
	return tex


## Bande verticale de lumière dorée, transparente sur les bords.
static func _band() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.86, 0.51, 0.0), Color(1.0, 0.9, 0.63, 0.55), Color(1.0, 0.86, 0.51, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	tex.width = 64
	tex.height = 4
	return tex


## Poussière d'or : 70 grains qui scintillent et dérivent vers le haut pendant 3,2 s.
class Dust extends Control:
	var t := 0.0
	var _k := 1.0
	var _grains: Array = []

	var _seed := 7  ## Même tirage que la maquette.

	func _init(k: float) -> void:
		_k = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 70:
			var s := 1.0 + _rnd() * 2.6
			var at := Vector2(_rnd() * 375.0, 120.0 + _rnd() * 580.0)
			var drift := Vector2((_rnd() - 0.5) * 30.0, -10.0 - _rnd() * 30.0)
			_grains.append([s, at, drift, _rnd() * 300.0])

	func _rnd() -> float:
		_seed = (_seed * 9301 + 49297) % 233280
		return _seed / 233280.0

	func _draw() -> void:
		for g in _grains:
			var p := Splash._progress(t, g[3], 3200.0)
			var a := Splash._keys(p, [[0.0, 0.0], [0.3, 0.9], [0.7, 0.2], [1.0, 0.8]])
			var at: Vector2 = ((g[1] as Vector2) + (g[2] as Vector2) * p) * _k
			var r: float = g[0] * 0.5 * _k
			draw_circle(at, r * 2.6, Color(1.0, 0.78, 0.35, 0.18 * a))
			draw_circle(at, r, Color(1.0, 0.84, 0.48, a))


## Les 18 étincelles du choc, qui partent en étoile.
class Sparks extends Control:
	var t := 0.0
	var _center := Vector2.ZERO
	var _k := 1.0
	var _rays: Array = []

	func _init(center: Vector2, k: float) -> void:
		_center = center
		_k = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var seed := 11
		for i in 18:
			seed = (seed * 9301 + 49297) % 233280
			var ang := (i / 18.0) * 360.0 + seed / 233280.0 * 12.0
			seed = (seed * 9301 + 49297) % 233280
			_rays.append([deg_to_rad(ang), 90.0 + seed / 233280.0 * 90.0])

	func _draw() -> void:
		if t < 800.0 or t > 1320.0:
			return
		var p := Splash._bezier(0.1, 0.7, 0.3, 1.0, Splash._progress(t, 800.0, 520.0))
		for r in _rays:
			var dir := Vector2(sin(r[0]), -cos(r[0]))
			var length := 14.0 * lerpf(1.0, 0.4, p) * _k
			var at: Vector2 = _center + dir * float(r[1]) * p * _k
			draw_line(at - dir * length / 2, at + dir * length / 2, Color(1.0, 0.85, 0.45, 1.0 - p), 4.0 * _k, true)
