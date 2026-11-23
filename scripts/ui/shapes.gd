class_name Shapes
extends RefCounted
## Formes dessinées à la main (_draw) pour reproduire les maquettes validées.


static func _px(v: float) -> float:
	return v * UiTheme.SCALE


## Halo de lampe : disques concentriques de plus en plus clairs.
class Glow extends Control:
	var center := Vector2(0.5, 0.35)  ## En fraction de la taille.
	var color := Color(1.0, 0.69, 0.27, 0.35)
	var radius_ratio := 0.75

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * center
		var r_max := maxf(size.x, size.y) * radius_ratio
		var steps := 28
		for i in steps:
			var r := r_max * (1.0 - float(i) / steps)
			draw_circle(c, r, Color(color, color.a / steps * 1.6))


## Tourbillons : anneaux concentriques autour de deux centres.
class RingPattern extends Control:
	var centers := [Vector2(0.12, 0.18), Vector2(0.92, 0.64)]
	var colors := [Color(1, 1, 1, 0.14), Color(0, 0, 0, 0.08)]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var width := Shapes._px(5)
		var period := Shapes._px(16)
		var reach := size.length()
		for i in centers.size():
			var c: Vector2 = size * centers[i]
			var r := width
			while r < reach:
				draw_arc(c, r, 0, TAU, 64, colors[i], width, true)
				r += period


## Cadre de carte à coins coupés : liseré jaune, fond violet.
class NotchedFrame extends Control:
	var outer := UiTheme.YELLOW
	var inner := UiTheme.VIOLET

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _octagon(r: Rect2, n: float) -> PackedVector2Array:
		var a := r.position
		var b := r.end
		return PackedVector2Array([
			Vector2(a.x + n, a.y), Vector2(b.x - n, a.y), Vector2(b.x, a.y + n), Vector2(b.x, b.y - n),
			Vector2(b.x - n, b.y), Vector2(a.x + n, b.y), Vector2(a.x, b.y - n), Vector2(a.x, a.y + n)])

	func _draw() -> void:
		if size.x < Shapes._px(40) or size.y < Shapes._px(20):
			return
		var n := Shapes._px(22)
		var inset := Shapes._px(5)
		draw_colored_polygon(_octagon(Rect2(Vector2.ZERO, size), n), outer)
		draw_colored_polygon(_octagon(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2), n - inset * 0.6), inner)


## Bulle de dialogue crème avec sa queue et son étiquette (« Question »).
class SpeechBubble extends MarginContainer:
	var tag := "Question"
	var bg := UiTheme.CREAM
	var tail_x := 46.0

	func _init(tag_text: String = "Question") -> void:
		tag = tag_text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := 42.0 if not tag.is_empty() else 26.0
		add_theme_constant_override("margin_top", int(Shapes._px(top)))
		add_theme_constant_override("margin_bottom", int(Shapes._px(28)))
		add_theme_constant_override("margin_left", int(Shapes._px(16)))
		add_theme_constant_override("margin_right", int(Shapes._px(16)))
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < Shapes._px(40) or size.y < Shapes._px(20):
			return
		var top := Shapes._px(14)
		var bottom := size.y - Shapes._px(10)
		var body := Rect2(0, top, size.x, bottom - top)
		var shadow := UiTheme.box(Color(UiTheme.NIGHT, 0.35), int(Shapes._px(20)))
		shadow.draw(get_canvas_item(), Rect2(body.position + Vector2(0, Shapes._px(5)), body.size))
		UiTheme.box(bg, int(Shapes._px(20))).draw(get_canvas_item(), body)
		var tx := Shapes._px(tail_x)
		var t := Shapes._px(13)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx, bottom - 1), Vector2(tx + t * 2, bottom - 1), Vector2(tx + t, bottom + t)]), bg)
		if tag.is_empty():
			return
		var font := UiTheme.TITLE_FONT
		var fs := int(Shapes._px(17))
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pill := Rect2((size.x - tw) / 2 - Shapes._px(18), 0, tw + Shapes._px(36), Shapes._px(28))
		var ps := UiTheme.box(UiTheme.VIOLET, int(Shapes._px(14)))
		ps.border_color = UiTheme.YELLOW
		ps.set_border_width_all(int(Shapes._px(3)))
		ps.draw(get_canvas_item(), pill)
		var baseline := pill.position.y + (pill.size.y + font.get_ascent(fs) - font.get_descent(fs)) / 2
		draw_string(font, Vector2(pill.position.x + Shapes._px(18), baseline), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.YELLOW)


## Minuteur circulaire : anneau jaune qui se vide, secondes au centre.
class TimerRing extends Control:
	var value := 1.0
	var text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(Shapes._px(54), Shapes._px(54))

	func set_time(left: float, total: float) -> void:
		value = clampf(left / total, 0.0, 1.0)
		text = str(int(ceil(left)))
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var w := Shapes._px(6)
		draw_circle(c, r, UiTheme.NIGHT)
		draw_arc(c, r - w / 2, 0, TAU, 64, Color(1, 1, 1, 0.15), w, true)
		var urgent := value <= 0.27
		var col := UiTheme.FRAMBOISE.lightened(0.2) if urgent else UiTheme.YELLOW
		if value > 0:
			draw_arc(c, r - w / 2, -PI / 2, -PI / 2 + TAU * value, 64, col, w, true)
		var font := UiTheme.TITLE_FONT
		var fs := int(Shapes._px(22))
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(c.x - ts.x / 2, c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Petites icônes : difficultés (lait, manne, solide) et catégories.
class Icon extends Control:
	var kind := ""
	var color := UiTheme.CREAM

	func _init(k: String = "", c: Color = UiTheme.CREAM, side: float = 26) -> void:
		kind = k
		color = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(Shapes._px(side), Shapes._px(side))
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s < 4:
			return
		var o := (size - Vector2(s, s)) / 2
		var w := s * 0.1
		match kind:
			"lait":
				var c := o + Vector2(s * 0.5, s * 0.62)
				var r := s * 0.3
				draw_circle(c, r, color)
				draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.5, s * 0.05), c + Vector2(-r * 0.95, -r * 0.3), c + Vector2(r * 0.95, -r * 0.3)]), color)
			"manne":
				for p in [Vector2(0.3, 0.45), Vector2(0.55, 0.35), Vector2(0.75, 0.55), Vector2(0.45, 0.68)]:
					draw_circle(o + p * s, s * 0.16, color)
			"solide":
				var loaf := Rect2(o + Vector2(s * 0.08, s * 0.28), Vector2(s * 0.84, s * 0.5))
				UiTheme.box(color, int(s * 0.25)).draw(get_canvas_item(), loaf)
				for i in 3:
					var x := loaf.position.x + loaf.size.x * (0.3 + i * 0.2)
					draw_line(Vector2(x, loaf.position.y + s * 0.08), Vector2(x - s * 0.08, loaf.end.y - s * 0.08), UiTheme.GOLD.darkened(0.3), w * 0.8, true)
			"personnages":
				draw_arc(o + Vector2(s * 0.5, s * 0.33), s * 0.17, 0, TAU, 32, color, w, true)
				draw_arc(o + Vector2(s * 0.5, s * 0.95), s * 0.36, PI * 1.15, PI * 1.85, 32, color, w, true)
			"miracles":
				var pts := PackedVector2Array()
				for i in 11:
					var a := -PI / 2 + i * TAU / 10
					var r := s * (0.45 if i % 2 == 0 else 0.2)
					pts.append(o + Vector2(s / 2, s / 2) + Vector2(cos(a), sin(a)) * r)
				draw_polyline(pts, color, w, true)
			"paraboles":
				var base := o + Vector2(s * 0.5, s * 0.9)
				draw_line(base, o + Vector2(s * 0.5, s * 0.35), color, w, true)
				draw_arc(o + Vector2(s * 0.32, s * 0.4), s * 0.17, -PI * 0.1, PI * 0.9, 16, color, w, true)
				draw_arc(o + Vector2(s * 0.68, s * 0.3), s * 0.17, PI * 0.1, PI * 1.1, 16, color, w, true)
			"lieux_evenements":
				draw_polyline(PackedVector2Array([o + Vector2(s * 0.05, s * 0.85), o + Vector2(s * 0.4, s * 0.3), o + Vector2(s * 0.6, s * 0.6), o + Vector2(s * 0.75, s * 0.45), o + Vector2(s * 0.95, s * 0.85), o + Vector2(s * 0.05, s * 0.85)]), color, w, true)
				draw_circle(o + Vector2(s * 0.78, s * 0.2), s * 0.1, color)


## Carte miniature de la main : dos coloré, petite bulle. Touchable.
class MiniCard extends Control:
	signal pressed
	var color := UiTheme.TEAL
	var selected := false

	func _init(c: Color = UiTheme.TEAL) -> void:
		color = c
		custom_minimum_size = Vector2(Shapes._px(62), Shapes._px(92))
		pivot_offset = custom_minimum_size / 2
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_selected(on: bool) -> void:
		selected = on
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if selected:
			var halo := UiTheme.box(Color(UiTheme.YELLOW, 0.35), int(Shapes._px(16)))
			halo.draw(get_canvas_item(), r.grow(Shapes._px(8)))
		var s := UiTheme.box(color, int(Shapes._px(10)))
		s.border_color = UiTheme.CREAM if selected else UiTheme.YELLOW
		s.set_border_width_all(int(Shapes._px(3)))
		s.draw(get_canvas_item(), r)
		var bubble := Rect2(size.x * 0.18, size.y * 0.22, size.x * 0.64, size.y * 0.3)
		UiTheme.box(UiTheme.CREAM, int(Shapes._px(8))).draw(get_canvas_item(), bubble)
		var font := UiTheme.TITLE_FONT
		var fs := int(Shapes._px(16))
		var tw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(bubble.get_center().x - tw / 2, bubble.get_center().y + fs * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.VIOLET)


## Dos de carte : framboise et sarcelle, tourbillons, grande bulle « ? ».
class CardBackArt extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < Shapes._px(40) or size.y < Shapes._px(20):
			return
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.FRAMBOISE)
		draw_circle(size, size.length() * 0.42, UiTheme.TEAL)
		var w := Shapes._px(5)
		var r := w
		while r < size.length():
			draw_arc(size * Vector2(0.2, 0.15), r, 0, TAU, 64, Color(1, 1, 1, 0.12), w, true)
			r += Shapes._px(16)
		var bw := size.x * 0.5
		var bubble := Rect2((size.x - bw) / 2, size.y * 0.5 - bw * 0.4, bw, bw * 0.78)
		UiTheme.box(UiTheme.CREAM, int(bw * 0.24)).draw(get_canvas_item(), bubble)
		var tx := bubble.position.x + bw * 0.2
		draw_colored_polygon(PackedVector2Array([Vector2(tx, bubble.end.y - 1), Vector2(tx + bw * 0.2, bubble.end.y - 1), Vector2(tx + bw * 0.06, bubble.end.y + bw * 0.14)]), UiTheme.CREAM)
		var font := UiTheme.TITLE_FONT
		var fs := int(bw * 0.62)
		var tw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(bubble.get_center().x - tw / 2, bubble.get_center().y + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.VIOLET)


## Mur de pierre ocre pour l'accueil.
class StoneWall extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("b9793f"))
		var y := 0.0
		var row := 0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.24, 0.12, 0.04, 0.25), Shapes._px(2))
			var x := Shapes._px(35) if row % 2 == 0 else 0.0
			while x < size.x:
				draw_line(Vector2(x, y), Vector2(x, y + Shapes._px(46)), Color(0.24, 0.12, 0.04, 0.18), Shapes._px(2))
				x += Shapes._px(70)
			y += Shapes._px(46)
			row += 1


## Arche lumineuse : sert de masque à un halo (clip_children).
class Arch extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		resized.connect(queue_redraw)

	func _points(inset: float) -> PackedVector2Array:
		var r := size.x / 2 - inset
		var pts := PackedVector2Array()
		for i in 33:
			var a := PI + PI * i / 32.0
			pts.append(Vector2(size.x / 2, size.x / 2) + Vector2(cos(a), sin(a)) * r)
		pts.append(Vector2(size.x - inset, size.y))
		pts.append(Vector2(inset, size.y))
		return pts

	func _draw() -> void:
		if size.x < Shapes._px(40) or size.y < Shapes._px(20):
			return
		draw_colored_polygon(_points(0), Color("e39445"))
