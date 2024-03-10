extends Node

func _ready(): pass
func _process(delta): pass

func input(action: StringName):
	Input.action_press(action)
	var a = InputEventAction.new()
	a.action = action
	a.pressed = true
	Input.parse_input_event(a)
	return action
