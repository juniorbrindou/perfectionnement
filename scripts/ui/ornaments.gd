class_name Ornaments
extends RefCounted
## Ornements dorés dessinés, partagés par plusieurs écrans : laurier, étincelle, médaille.


## Laurier doré : une branche de chaque côté d'un centre (couronne), ou une seule.
## center : centre de la couronne en fraction de la taille ; radius : rayon en fraction de
## la hauteur ; sides : -1 pour la branche gauche, 1 pour la droite.
class Laurel extends Control:
	var center := Vector2(0.5, 0.54)
	var radius := 0.3
	var sides: Array = [-1.0, 1.0]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * center
		var r := size.y * radius
		for side: float in sides:
			var stem := PackedVector2Array()
			for k in 13:
				var a := deg_to_rad(110.0 + k * 11.0)
				stem.append(c + Vector2(-side * r * cos(a), r * 0.85 * sin(a)))
			draw_polyline(stem, Color("c98a24"), maxf(2.0, r * 0.035), true)
			for k in range(1, 12):
				var a := deg_to_rad(110.0 + k * 11.0)
				var p := c + Vector2(-side * r * cos(a), r * 0.85 * sin(a))
				var tangent := atan2(r * 0.85 * cos(a), side * r * sin(a))
				var length := r * (0.27 - k * 0.01)
				_leaf(p + Vector2(side * r * 0.08, 0), tangent - side * 0.6, length)
				_leaf(p - Vector2(side * r * 0.08, 0), tangent + side * 0.6, length)

	func _leaf(at: Vector2, angle: float, length: float) -> void:
		draw_set_transform(at, angle, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, length / 2, Color("c98a24"))
		draw_circle(Vector2(0, -length * 0.08), length * 0.42, Color("ffe08a"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Étincelle dorée à quatre branches, qui scintille.
class Sparkle extends Control:
	var _t := randf() * TAU

	func _init(side: float) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(side, side)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _process(delta: float) -> void:
		_t += delta * 4.0
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2 * (0.8 + 0.2 * sin(_t))
		var pts := PackedVector2Array()
		for k in 8:
			var rr := r if k % 2 == 0 else r * 0.28
			var a := k * PI / 4 - PI / 2
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color("fff3c4"))


## Médaille de podium : disque de métal (or, argent ou bronze) avec son chiffre, dans une
## couronne de laurier.
class Medal extends Control:
	const METALS := {
		1: [Color("fff0a8"), Color("e8a92a"), Color("8a5208")],
		2: [Color("ffffff"), Color("b9c2cf"), Color("5d6675")],
		3: [Color("ffd2a6"), Color("cd7f3c"), Color("6e3812")],
	}
	var place := 1

	func _init(p: int, side: float) -> void:
		place = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(side, side)
		var laurel := Laurel.new()
		laurel.set_anchors_preset(Control.PRESET_FULL_RECT)
		laurel.center = Vector2(0.5, 0.5)
		laurel.radius = 0.46
		add_child(laurel)

	func _draw() -> void:
		var m: Array = METALS.get(place, METALS[1])
		var c := size / 2
		var r := minf(size.x, size.y) * 0.32
		draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, m[2])
		draw_circle(c, r * 0.9, m[1])
		draw_circle(c - Vector2(0, r * 0.12), r * 0.72, m[0].lerp(m[1], 0.45))
		draw_arc(c, r * 0.8, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.55), maxf(1.5, r * 0.08), true)
		var font := UiTheme.TITLE_FONT
		var fs := int(r * 1.15)
		var t := str(place)
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(c.x - ts.x / 2, c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2)
		draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(fs * 0.12)), m[2])
		draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
