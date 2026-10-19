class_name CalcTopic
extends Node3D
## Base class for calculus visualizations. Main forwards input through these
## hooks so the same scene works with keyboard/mouse and XR controllers.

@export var topic_title := "Topic"


## Continuous 2D input in [-1, 1]: arrow keys (desktop) or right thumbstick (XR).
func handle_axis(_axis: Vector2, _delta: float) -> void:
	pass


## Scroll steps: mouse wheel (desktop) or left thumbstick (XR, fractional steps).
func handle_scroll(_steps: float) -> void:
	pass


## Space bar (desktop) or A/X button (XR).
func handle_action() -> void:
	pass


## Short controls hint shown in the HUD.
func get_hint() -> String:
	return ""


## Optional 2D controls (e.g. sliders) shown in the desktop HUD.
func create_hud_controls() -> Control:
	return null


## For topics that plot a user-typed function: {"label", "variables", "text",
## "presets"}. Empty when the topic has no function to edit.
func get_function_spec() -> Dictionary:
	return {}


## Plots a new function. Returns an error message, or "" on success.
func set_function(_source: String) -> String:
	return "This topic has no editable function"


## Snapshot of the topic's state, used by the automated self-test.
func get_debug_state() -> Dictionary:
	return {}
