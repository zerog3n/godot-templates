extends Node3D
class_name World

var registered_units = []
var collisions = []

var next_time = 0

func _ready():
	pass

func units():
	return registered_units

func register_unit(unit):
	registered_units.append(unit)

func find_collisions():
	collisions = []
	for a in registered_units:
		if not "bbox" in a: continue
		var aa = a.bbox()
		for b in registered_units:
			if not "bbox" in b: continue
			if a == b: continue
			if a in collisions: continue
			if b in collisions: continue
			var bb = b.bbox()
			if aa.intersects(bb):
				collisions.append(a)
				collisions.append(b)
	
	if collisions.size(): print('bbox collisions: ', collisions.size())
	return collisions
