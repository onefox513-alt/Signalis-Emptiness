extends Area3D

class_name Pickupable
signal Collected(amount: int)

enum PickupType { COIN, POWERUP, BOOST }
@export var CurrentPickupType = PickupType.COIN
@export var Score: int = 10
@export var Speed: float = 10.0

var _move_dir: int = -1
var rotation_angle: float = 0.0
var tesseract_mesh: MeshInstance3D = null
var is_collected: bool = false

func _ready() -> void:
	_move_dir = int(sign(0.0 - global_transform.origin.z))
	_create_tesseract_visual()
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))

func _create_tesseract_visual() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	tesseract_mesh = MeshInstance3D.new()
	tesseract_mesh.name = "TesseractVisual"
	add_child(tesseract_mesh)
	var mesh = ArrayMesh.new()
	var outer = 0.3 
	var inner = 0.17 
	var v_outer: PackedVector3Array = []
	for x in [-outer, outer]:
		for y in [-outer, outer]:
			for z in [-outer, outer]:
				v_outer.append(Vector3(x, y, z))
	var v_inner: PackedVector3Array = []
	for x in [-inner, inner]:
		for y in [-inner, inner]:
			for z in [-inner, inner]:
				v_inner.append(Vector3(x, y, z))
	var positions: PackedVector3Array = []
	var colors: PackedColorArray = []
	var outer_color = Color(0.0, 0.603, 0.933, 1.0)    
	var inner_color = Color(0.749, 0.207, 0.0, 1.0)    
	var connect_color = Color(0.679, 0.693, 0.693, 1.0)  
	_add_cube_edges(positions, colors, v_outer, outer_color)
	_add_cube_edges(positions, colors, v_inner, inner_color)
	for i in range(8):
		positions.append(v_outer[i])
		colors.append(connect_color)
		positions.append(v_inner[i])
		colors.append(connect_color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	tesseract_mesh.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 1.0)
	mat.emission_energy_multiplier = 1.2
	tesseract_mesh.material_override = mat
	tesseract_mesh.position = Vector3(0, 1.2, 0)

func _add_cube_edges(positions: PackedVector3Array, colors: PackedColorArray, vertices: PackedVector3Array, color: Color) -> void:
	var edges := PackedInt32Array([0,1, 1,3, 3,2, 2,0, 4,5, 5,7, 7,6, 6,4, 0,4, 1,5, 2,6, 3,7])
	for i in range(0, edges.size(), 2):
		positions.append(vertices[edges[i]])
		colors.append(color)
		positions.append(vertices[edges[i + 1]])
		colors.append(color)

func _physics_process(delta: float) -> void:
	translate(Vector3(0, 0, _move_dir * Speed * delta))
	if abs(global_transform.origin.z) > 300.0:
		queue_free()

func _process(delta: float) -> void:
	if not tesseract_mesh:
		return
	
	rotation_angle += delta * 1.5
	
	var basis := Basis()
	basis = basis.rotated(Vector3.UP, rotation_angle * 0.7)
	basis = basis.rotated(Vector3.RIGHT, rotation_angle * 0.5)
	tesseract_mesh.transform.basis = basis

func _on_area_entered(area: Area3D) -> void:
	if is_collected or is_queued_for_deletion():
		return

	if area.name == "Player" or (area.has_signal("AddScore") if area else false):
		is_collected = true
		emit_signal("Collected", Score)
		if $CollisionShape3D:
			$CollisionShape3D.disabled = true
		call_deferred("queue_free")

func stop_motion() -> void:
	Speed = 0.0
	set_physics_process(false)
