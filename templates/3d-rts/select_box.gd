extends Control

var box_visible = false
var mouse_position = Vector2()
var start_position = Vector2()
var box_size = Vector2(0, 0)

const box_colour = Color(0, 1, 0)
const line_width = 2

func _draw():
	var rx = start_position.x - mouse_position.x
	var ry = start_position.y - mouse_position.y
	var drawable = abs(rx) > 8 or abs(ry) > 8
	if box_visible and drawable:
		var sp = start_position
		var mp = mouse_position
		draw_line(sp, Vector2(mp.x, sp.y), box_colour, line_width)
		draw_line(sp, Vector2(sp.x, mp.y), box_colour, line_width)
		draw_line(mp, Vector2(mp.x, sp.y), box_colour, line_width)
		draw_line(mp, Vector2(sp.x, mp.y), box_colour, line_width)
		box_size = Vector2(abs(sp.x - mp.x), abs(sp.y - mp.y))
	else: box_size = Vector2(0, 0)

func _process(_delta):
	mouse_position = get_viewport().get_mouse_position()
	if Input.is_action_pressed("primary_action"):
		if not box_visible:
			start_position = mouse_position
			box_visible = true
	else: box_visible = false
	queue_redraw()
