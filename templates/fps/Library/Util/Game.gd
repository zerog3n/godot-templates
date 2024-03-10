extends Node

func _ready(): pass
func _process(delta): pass

func time():
	return int(Time.get_unix_time_from_system() * 1000)
	
func log(str: String):
	print(time(), ': ', str)

func start():
	self.log('game initialised')
