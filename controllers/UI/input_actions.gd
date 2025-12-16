extends Node




func get_action_key(action_name: String) -> String:
    if InputMap.has_action(action_name):
        var events = InputMap.action_get_events(action_name)
        for e in events:
            if e is InputEventKey:
                return OS.get_keycode_string(e.physical_keycode) # readable key like "E", "F", etc.
    return "F" # default key if action not found

func get_action_key_number(action_name: String) -> int:
    if InputMap.has_action(action_name):
        var events = InputMap.action_get_events(action_name)
        for e in events:
            if e is InputEventKey:
                return e.physical_keycode
    return KEY_F # default keycode if action not found