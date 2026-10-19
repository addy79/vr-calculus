class_name InputSetup
extends RefCounted
## Registers the keyboard actions in code. Keys use physical positions, so WASD
## stays in the same place on AZERTY/QWERTZ layouts.

const KEY_ACTIONS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_up": [KEY_E],
	"move_down": [KEY_Q],
	"sprint": [KEY_SHIFT],
	"topic_left": [KEY_LEFT],
	"topic_right": [KEY_RIGHT],
	"topic_up": [KEY_UP],
	"topic_down": [KEY_DOWN],
	"toggle_xr": [KEY_F1],
	"toggle_help": [KEY_H],
	"screenshot": [KEY_F12],
	"topic_1": [KEY_1, KEY_KP_1],
	"topic_2": [KEY_2, KEY_KP_2],
	"topic_3": [KEY_3, KEY_KP_3],
	"topic_4": [KEY_4, KEY_KP_4],
	"topic_action": [KEY_SPACE],
}


static func register() -> void:
	for action: String in KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in KEY_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


## Label of the key printed on the user's keyboard for an action's first event.
static func key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	var key := events[0] as InputEventKey
	var keycode := DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
	if keycode == KEY_NONE:
		keycode = key.physical_keycode
	return OS.get_keycode_string(keycode)
