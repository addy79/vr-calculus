class_name Interact
extends RefCounted
## Pointer interaction protocol shared by the desktop mouse and XR controllers.
## An interactable node (or an ancestor of the collider that was hit) implements:
##   pointer_pressed(collider: Node, hit_position: Vector3, ray_origin: Vector3, ray_dir: Vector3)
##   pointer_dragged(ray_origin: Vector3, ray_dir: Vector3)       (optional)
##   pointer_released()                                            (optional)
##   pointer_hover(hovering: bool)                                 (optional)

const RAY_LENGTH := 100.0


## Walks up from the collider to the nearest node that accepts pointer presses.
static func find_target(collider: Object) -> Node:
	var node := collider as Node
	while node:
		if node.has_method("pointer_pressed"):
			return node
		node = node.get_parent()
	return null


static func raycast(world: World3D, origin: Vector3, dir: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * RAY_LENGTH)
	query.collide_with_areas = true
	return world.direct_space_state.intersect_ray(query)
