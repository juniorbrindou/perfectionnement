class_name Card3D
extends Node3D
## Une carte posée à plat sur la table. Dos vers le haut = face cachée.
## Dos : étoffe tissée du tabernacle. Recto : fin lin, bandeau de la couleur de la
## difficulté, catégorie, et une perle par proposition restante.

signal tapped(card: Card3D)

const SIZE := Vector2(1.1, 1.54)
const THICKNESS := 0.03
const PIXEL := 0.0025
const MAX_PIPS := 4

var in_play: CardInPlay
var owner_index := -1
var face_up := false

var _pivot := Node3D.new()  ## Porte les maillages : retournement et soulèvement.
var _band_mat := StandardMaterial3D.new()
var _band_label: Label3D
var _category_label: Label3D
var _pips: Array[MeshInstance3D] = []
var _pip_mat := StandardMaterial3D.new()
var _tween: Tween


func _init() -> void:
	add_child(_pivot)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x, THICKNESS, SIZE.y)
	body.mesh = box
	body.material_override = _material(UiTheme.LIN.darkened(0.25))
	_pivot.add_child(body)

	# Dos (face +Y) : étoffe tissée.
	var back := MeshInstance3D.new()
	back.mesh = _plane(SIZE * 0.97)
	var back_mat := _material(Color.WHITE)
	back_mat.albedo_texture = UiTheme.weave_texture("dos", 110, 154, true, 9)
	back_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	back.material_override = back_mat
	back.position.y = THICKNESS / 2 + 0.001
	_pivot.add_child(back)

	# Recto (face -Y, visible une fois retournée autour de Z).
	var front_y := -(THICKNESS / 2 + 0.001)
	var front := MeshInstance3D.new()
	front.mesh = _plane(SIZE * 0.97)
	front.material_override = _material(UiTheme.LIN)
	front.rotation.z = PI
	front.position.y = front_y
	_pivot.add_child(front)

	var band := MeshInstance3D.new()
	band.mesh = _plane(Vector2(SIZE.x * 0.97, 0.36))
	band.material_override = _band_mat
	_band_mat.roughness = 0.9
	band.rotation.z = PI
	band.position = Vector3(0, front_y - 0.001, -SIZE.y / 2 + 0.2)
	_pivot.add_child(band)

	var face_basis := Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
	_band_label = _label(UiTheme.UI_BOLD, 64, UiTheme.LIN)
	_band_label.basis = face_basis
	_band_label.position = Vector3(0, front_y - 0.003, -SIZE.y / 2 + 0.2)
	_pivot.add_child(_band_label)
	_category_label = _label(UiTheme.SCRIPTURE_BOLD, 78, UiTheme.INK)
	_category_label.basis = face_basis
	_category_label.position = Vector3(0, front_y - 0.003, 0.05)
	_pivot.add_child(_category_label)

	# Perles : une par proposition restante (4, 3 ou 2).
	_pip_mat.roughness = 0.4
	_pip_mat.metallic = 0.3
	for i in MAX_PIPS:
		var pip := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.065
		disc.bottom_radius = 0.065
		disc.height = 0.01
		pip.mesh = disc
		pip.material_override = _pip_mat
		pip.position = Vector3((i - (MAX_PIPS - 1) / 2.0) * 0.2, front_y - 0.004, SIZE.y / 2 - 0.24)
		_pivot.add_child(pip)
		_pips.append(pip)

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
	var color := UiTheme.difficulty_color(card.data.difficulty)
	_band_mat.albedo_color = color
	_pip_mat.albedo_color = color
	_band_label.text = card.data.difficulty_label()
	refresh()


func refresh() -> void:
	_category_label.text = in_play.data.category_label()
	var n := in_play.option_count()
	for i in MAX_PIPS:
		_pips[i].visible = i < n
		_pips[i].position.x = (i - (n - 1) / 2.0) * 0.2


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


## Destruction : la carte s'élève en tournant et se dissout en étincelles d'or.
func destroy() -> void:
	if _tween:
		_tween.kill()
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 56
	sparks.lifetime = 1.0
	sparks.explosiveness = 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3(0, -2.5, 0)
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	sparks.mesh = dot
	sparks.material_override = _material(UiTheme.OR, true)
	get_parent().add_child(sparks)
	sparks.global_position = global_position + Vector3.UP * 0.3
	sparks.emitting = true
	get_tree().create_timer(1.6).timeout.connect(sparks.queue_free)

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
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _label(font: Font, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = font_size
	l.pixel_size = PIXEL
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.shaded = false
	l.width = SIZE.x * 0.88 / PIXEL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
