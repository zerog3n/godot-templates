extends Node3D

@export var enabled := true
@export var delay_secs := float(1.0)
@export var spawn_limit := int(250)
@export var resource = preload("res://unit.tscn")
@export var target: NodePath = '' # set in the inspector once
@onready var target_node = get_node(target)

var next_spawn_time = 0
var spawned = 0

func _ready(): pass

func _process(_delta):
	if spawned >= spawn_limit:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
		
	var now = Time.get_ticks_msec()
	if now > next_spawn_time:
		next_spawn_time = now + delay_secs * 1000
		spawn()

func spawn():
	var e = resource.instantiate()
	e.position = self.global_position
	get_tree().get_root().add_child(e)
	e.move_to(target_node.global_position)
	spawned += 1
