class_name Card3D
extends Node3D
## Une carte posée à plat sur la table. Dos vers le haut = face cachée.
## Le recto affiche la difficulté, la catégorie et le nombre de propositions.

signal tapped(card: Card3D)

const SIZE := Vector2(1.1, 1.54)
const THICKNESS := 0.03
const PIXEL := 0.0025

var in_play: CardInPlay
var owner_index := -1
var face_up := false

var _count_label: Label3D
var _title_label: Label3D
var _category_label: Label3D
var _tween: Tween
var _pivot := Node3D.new()  ## Porte les maillages : retournement et soulèvement.


func _init() -> void:
	add_child(_pivot)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x, THICKNESS, SIZE.y)
	body.mesh = box
	body.material_override = _material(UiTheme.GOLD.darkened(0.2))
	_pivot.add_child(body)

	# Dos (face +Y).
	var back := MeshInstance3D.new()
	back.mesh = _plane(SIZE * 0.92)
	back.material_override = _material(UiTheme.WINE)
	back.position.y = THICKNESS / 2 + 0.001
	_pivot.add_child(back)
	var emblem := _label("P", 180, UiTheme.GOLD)
	emblem.basis = Basis.from_euler(Vector3(-PI / 2, 0, 0))
	emblem.position.y = THICKNESS / 2 + 0.003
	_pivot.add_child(emblem)

	# Recto (face -Y, visible une fois retournée autour de Z).
	var front := MeshInstance3D.new()
	front.mesh = _plane(SIZE * 0.94)
	front.material_override = _material(UiTheme.PARCHMENT)
	front.rotation.z = PI
	front.position.y = -(THICKNESS / 2 + 0.001)
	_pivot.add_child(front)
	var front_basis := Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
	_title_label = _label("", 70, UiTheme.WINE)
	_category_label = _label("", 54, UiTheme.INK)
	_count_label = _label("", 54, UiTheme.INK)
	var rows := [[_title_label, -0.45], [_category_label, 0.0], [_count_label, 0.45]]
	for row in rows:
		var l: Label3D = row[0]
		l.basis = front_basis
		l.position = Vector3(0, -(THICKNESS / 2 + 0.003), row[1])
		_pivot.add_child(l)

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE.x, 0.2, SIZE.y)
	shape.shape = bs
	area.add_child(shape)
	area.input_event.connect(_on_input_event)
	_pivot.add_child(area)


func setup(card: CardInPlay, who: int) -> void:
	in_play = card
	owner_index = who
	refresh()


func refresh() -> void:
	_title_label.text = in_play.data.difficulty_label()
	_category_label.text = in_play.data.category_label()
	_count_label.text = "%d propositions" % in_play.option_count()


func set_face_up(up: bool, animated: bool = true) -> void:
	if up == face_up:
		return
	face_up = up
	var target := PI if up else 0.0
	if not animated:
		_pivot.rotation.z = target
		return
	var t := create_tween()
	t.tween_property(_pivot, "rotation:z", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lift := create_tween()
	lift.tween_property(_pivot, "position:y", 0.6, 0.2).set_ease(Tween.EASE_OUT)
	lift.tween_property(_pivot, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN)


func move_to(target: Vector3, duration: float = 0.4) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Destruction : la carte s'envole en tournant et disparaît dans des étincelles.
func destroy() -> void:
	if _tween:
		_tween.kill()
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 48
	sparks.lifetime = 0.9
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3(0, -3, 0)
	var dot := SphereMesh.new()
	dot.radius = 0.03
	dot.height = 0.06
	sparks.mesh = dot
	sparks.material_override = _material(UiTheme.GOLD, true)
	get_parent().add_child(sparks)
	sparks.global_position = global_position + Vector3.UP * 0.3
	sparks.emitting = true
	get_tree().create_timer(1.5).timeout.connect(sparks.queue_free)

	var t := create_tween().set_parallel()
	t.tween_property(self, "position:y", position.y + 2.5, 0.8).set_ease(Tween.EASE_IN)
	t.tween_property(self, "rotation:y", rotation.y + TAU, 0.8)
	t.tween_property(self, "scale", Vector3.ONE * 0.05, 0.8).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)


func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)


static func _plane(s: Vector2) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = s
	return p


static func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _label(text: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = PIXEL
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.width = SIZE.x * 0.9 / PIXEL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
