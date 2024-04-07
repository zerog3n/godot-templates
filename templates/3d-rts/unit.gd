extends Node3D

@onready var control = $Control

func _ready():
	set_process(false)
	set_physics_process(false)

