extends Node3D

var Game = preload("res://Library/Util/Game.gd").new()

func _ready():
	var refresh_rate = DisplayServer.screen_get_refresh_rate()
	
	if refresh_rate < 0:
		refresh_rate = 60.0

	Engine.max_fps = refresh_rate
	Engine.physics_ticks_per_second = refresh_rate
	
	Game.log('refresh rate is: ' + str(refresh_rate))
