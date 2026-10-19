class_name Arrow3D
extends Node3D
## A vector arrow (cylinder shaft + cone head) starting at this node's origin.

var shaft_radius: float
var head_radius: float
var head_length: float
var material := StandardMaterial3D.new()

var _shaft := MeshInstance3D.new()
var _head := MeshInstance3D.new()


func _init(color: Color = Color.WHITE, radius: float = 0.03) -> void:
	shaft_radius = radius
	head_radius = radius * 2.4
	head_length = radius * 5.0
	material.roughness = 0.4
	set_color(color)
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = shaft_radius
	shaft_mesh.bottom_radius = shaft_radius
	shaft_mesh.height = 1.0
	shaft_mesh.radial_segments = 12
	shaft_mesh.rings = 1
	shaft_mesh.material = material
	_shaft.mesh = shaft_mesh
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = head_radius
	head_mesh.height = head_length
	head_mesh.radial_segments = 12
	head_mesh.rings = 1
	head_mesh.material = material
	_head.mesh = head_mesh
	add_child(_shaft)
	add_child(_head)


## Points the arrow along `v`, with length |v|. Hidden for (near) zero vectors.
func set_vector(v: Vector3) -> void:
	var length := v.length()
	visible = length > 1e-4
	if not visible:
		return
	basis = MathUtil.basis_from_y(v)
	var head := minf(head_length, length * 0.5)
	var shaft := length - head
	_shaft.scale = Vector3(1.0, shaft, 1.0)
	_shaft.position = Vector3(0.0, shaft * 0.5, 0.0)
	_head.scale = Vector3(1.0, head / head_length, 1.0)
	_head.position = Vector3(0.0, shaft + head * 0.5, 0.0)


func set_color(color: Color) -> void:
	material.albedo_color = color


func set_highlight(on: bool) -> void:
	material.emission_enabled = on
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 0.8
