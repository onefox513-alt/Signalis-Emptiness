extends StaticBody3D

class_name Obstacle

enum ObstacleType { STANDART, LOW, HIGH, CREST }
@export var CurrentObstacleType: ObstacleType = ObstacleType.STANDART
@export var Speed: float = 10.0

var _move_dir: int = -1

func _ready() -> void:
	_move_dir = int(sign(0.0 - global_transform.origin.z))
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	translate(Vector3(0, 0, _move_dir * Speed * delta))
	if abs(global_transform.origin.z) > 300.0:
		queue_free()

func stop_motion() -> void:
	Speed = 0.0
	set_physics_process(false)
