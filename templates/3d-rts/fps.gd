extends Label

@onready var spawner1 = get_node("/root/World/Spawner1")
@onready var spawner2 = get_node("/root/World/Spawner2")
@onready var spawner3 = get_node("/root/World/Spawner3")
@onready var spawner4 = get_node("/root/World/Spawner4")

func _ready(): pass

func _process(_delta):
	var fps = Engine.get_frames_per_second()
	var spawn_count = ''
	if spawner1 and spawner2:
		var total = 0
		total += spawner1.spawned
		total += spawner2.spawned
		total += spawner3.spawned
		total += spawner4.spawned
		spawn_count = '  UNITS: ' + str(total)
	text = "FPS: " + str(fps) + spawn_count
