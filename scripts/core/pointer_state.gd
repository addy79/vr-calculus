class_name PointerState
extends RefCounted
## Tracks hover/press/drag for one pointer (mouse or XR controller ray).

var hovered: Node
var held: Node
var collider: Node
var has_hit := false
var hit_position := Vector3.ZERO
var ray_origin := Vector3.ZERO
var ray_dir := Vector3.FORWARD


## Casts the ray, updates hover state and forwards drags to the held target.
func update(world: World3D, origin: Vector3, dir: Vector3) -> void:
	ray_origin = origin
	ray_dir = dir
	var hit := Interact.raycast(world, origin, dir)
	has_hit = not hit.is_empty()
	collider = hit.collider as Node if has_hit else null
	hit_position = hit.position if has_hit else origin + dir * Interact.RAY_LENGTH
	var target := Interact.find_target(collider)
	if held and not is_instance_valid(held):
		held = null
	if held:
		if held.has_method("pointer_dragged"):
			held.pointer_dragged(origin, dir)
		target = held
	_set_hovered(target)


func press() -> void:
	if hovered and is_instance_valid(hovered):
		held = hovered
		held.pointer_pressed(collider, hit_position, ray_origin, ray_dir)


func release() -> void:
	if held and is_instance_valid(held) and held.has_method("pointer_released"):
		held.pointer_released()
	held = null


func is_hovering() -> bool:
	return hovered != null and is_instance_valid(hovered)


func _set_hovered(target: Node) -> void:
	if target == hovered:
		return
	if hovered and is_instance_valid(hovered) and hovered.has_method("pointer_hover"):
		hovered.pointer_hover(false)
	hovered = target
	if hovered and hovered.has_method("pointer_hover"):
		hovered.pointer_hover(true)
