class_name Grabbable
extends StaticBody3D
## An object that can be grabbed and carried along the pointer ray
## (left-click on desktop, trigger in XR). Keeps its distance from the pointer.

signal moved(global_pos: Vector3)

## Optional limits in the parent's local space (used when non-empty).
var bounds := AABB()
var grabbed := false

var _distance := 0.0
var _offset := Vector3.ZERO
var _material: StandardMaterial3D


func _init(radius: float = 0.12, color: Color = Color.WHITE) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.roughness = 0.3
	sphere.material = _material
	mesh.mesh = sphere
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius * 1.3
	shape.shape = sphere_shape
	add_child(shape)


func pointer_hover(hovering: bool) -> void:
	_material.emission_enabled = hovering or grabbed
	_material.emission = Color(0.4, 0.8, 1.0)


func pointer_pressed(_collider: Node, hit_position: Vector3, ray_origin: Vector3, _ray_dir: Vector3) -> void:
	grabbed = true
	_distance = ray_origin.distance_to(hit_position)
	_offset = global_position - hit_position


func pointer_dragged(ray_origin: Vector3, ray_dir: Vector3) -> void:
	if not grabbed:
		return
	var target := ray_origin + ray_dir * _distance + _offset
	var parent := get_parent() as Node3D
	var local := parent.to_local(target)
	if bounds.has_volume():
		local = local.clamp(bounds.position, bounds.end)
	position = local
	moved.emit(global_position)


func pointer_released() -> void:
	grabbed = false
