extends CharacterBody3D

signal AddScore(score: int)
signal PlayerDied()

@export var Speed: float = 5.0
@export var JumpVelocity: float = 4.5
@export var StartY: float = 1.0
@export var LaneWidth: float = 2.0
@export var SlidingDuration: float = 0.4

@export var LaneResponsiveness: float = 6.0
@export var MaxLaneSpeed: float = 20.0
@export var LaneSmoothing: float = 10.0

@export var DebugDeathArea: bool = false
@export var HeadContactThreshold: float = 0.08

@onready var death_sound: AudioStreamPlayer3D = $AudioDeath

enum Line { LEFT = -1, CENTER = 0, RIGHT = 1 }
enum State { RUNNING, JUMPING, SLIDING, DEAD }

var currentState: State = State.RUNNING
var targetLine: int = Line.CENTER
var currentSlidingDuration: float = 0.0
var _horizontal_velocity: float = 0.0
var _pending_end_slide: bool = false

var _death_area: Area3D = null
var _head_area: Area3D = null

var _standing_half: float = 0.0
var _crouched_half: float = 0.0
var _is_dying: bool = false
var _game_manager: Node = null

const POWERUP_CLASS_NAME = "Pickupable"

func _on_death_area_body_entered(_body: Node3D) -> void:
	pass

func _connect_game_manager_signals() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	if not _game_manager:
		printerr("GameManager not found in group 'game_manager'!")
		return
	
	if _game_manager.has_signal("StartGame"):
		if not _game_manager.is_connected("StartGame", _on_game_manager_start_game):
			_game_manager.connect("StartGame", _on_game_manager_start_game)
	
	if _game_manager.has_signal("GameOver"):
		if not _game_manager.is_connected("GameOver", _on_game_manager_game_over):
			_game_manager.connect("GameOver", _on_game_manager_game_over)

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_INHERIT
	
	position.y = StartY
	velocity = Vector3.ZERO

	_enable_crouched_collision(false)
	_enable_standing_collision(true)

	_standing_half = _get_collision_half_height(get_node_or_null("StandingCollision"))
	_crouched_half = _get_collision_half_height(get_node_or_null("CrouchedCollision"))

	var powerup_collider = get_node_or_null("PowerupCollider")
	if powerup_collider and not powerup_collider.is_connected("area_entered", _on_powerup_collider_area_entered):
		powerup_collider.connect("area_entered", _on_powerup_collider_area_entered)

	_death_area = get_node_or_null("DeathArea")
	if _death_area:
		_death_area.monitoring = true
		_death_area.monitorable = true

	_head_area = get_node_or_null("HeadDeathArea")
	if _head_area:
		_head_area.monitoring = true
		_head_area.monitorable = true

	_connect_game_manager_signals()

func _exit_tree() -> void:
	if _game_manager:
		if _game_manager.is_connected("StartGame", _on_game_manager_start_game):
			_game_manager.disconnect("StartGame", _on_game_manager_start_game)
		if _game_manager.is_connected("GameOver", _on_game_manager_game_over):
			_game_manager.disconnect("GameOver", _on_game_manager_game_over)

func _physics_process(delta: float) -> void:
	# Разрешаем движение при смерти даже во время паузы
	if currentState == State.DEAD:
		move_and_slide()
		return
	
	# Для других состояний проверяем паузу
	if Engine.time_scale <= 0.0:
		return
	
	if currentState == State.DEAD:
		move_and_slide()
		return

	# Таймаут для выхода из скольжения (предотвращает застревание)
	if _pending_end_slide and currentSlidingDuration < -0.5:
		_finalize_stand(max(0.0, _standing_half - _crouched_half))

	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	_handle_inputs()
	_update_horizontal_velocity(delta)

	move_and_slide()
	_post_physics_state_fix()

	if _pending_end_slide:
		_try_finalize_end_slide()

	_check_death_area_overlaps()

	if DebugDeathArea:
		_debug_death_area()

func _handle_inputs() -> void:
	# Проверка паузы
	if Engine.time_scale <= 0.0:
		return
	
	if Input.is_action_just_pressed("left") and targetLine > Line.LEFT:
		targetLine -= 1
	if Input.is_action_just_pressed("right") and targetLine < Line.RIGHT:
		targetLine += 1

	if Input.is_action_just_pressed("down") and currentState != State.SLIDING:
		_start_slide()

	if Input.is_action_just_pressed("jump") and is_on_floor() and currentState == State.RUNNING and not _pending_end_slide:
		velocity.y = JumpVelocity
		currentState = State.JUMPING

	if currentState == State.SLIDING:
		currentSlidingDuration -= get_physics_process_delta_time()
		if currentSlidingDuration <= 0.0:
			_end_slide_deferred()

func _start_slide() -> void:
	currentState = State.SLIDING
	currentSlidingDuration = SlidingDuration
	velocity.y = 0.0
	
	# Персонаж должен опускаться при скольжении
	var delta = max(0.0, _standing_half - _crouched_half)
	if delta > 0.0:
		position.y -= delta
	
	_enable_standing_collision(false)
	_enable_crouched_collision(true)
	
	if has_node("Model"):
		$Model.position.y = -0.7

func _end_slide_deferred() -> void:
	_pending_end_slide = true

func _try_finalize_end_slide() -> void:
	var delta = max(0.0, _standing_half - _crouched_half)
	if delta <= 0.0:
		_finalize_stand(delta)
		return
	if _can_stand_now(delta):
		_finalize_stand(delta)
		return

func _finalize_stand(delta: float) -> void:
	_pending_end_slide = false
	_enable_standing_collision(true)
	_enable_crouched_collision(false)
	
	if has_node("Model"):
		$Model.position.y = 0.0
	
	# Персонаж должен подниматься при выходе из скольжения
	if delta > 0.0:
		position.y += delta
	
	if is_on_floor():
		currentState = State.RUNNING
	else:
		currentState = State.JUMPING
	
	if velocity.y > 0.0:
		velocity.y = 0.0

func _can_stand_now(delta: float) -> bool:
	if delta <= 0.0:
		return true
	
	var local_start_y = _crouched_half + 0.01
	var from_global = global_transform.origin + Vector3(0, local_start_y, 0)
	var to_pos = from_global + Vector3(0, delta + 0.05, 0)
	
	var world = get_world_3d()
	if not world or not world.direct_space_state:
		return true
	
	var space = world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_global, to_pos)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false  # Только тела, не области
	
	var result = space.intersect_ray(query)
	return result.is_empty()

func _get_collision_half_height(shape_node: CollisionShape3D) -> float:
	if not shape_node or not shape_node.shape:
		return 0.5
	var s = shape_node.shape
	if s is BoxShape3D:
		return abs(s.extents.y)
	if s is CapsuleShape3D:
		return abs((s.height * 0.5) + s.radius)
	return 0.5

func _enable_standing_collision(enabled: bool) -> void:
	var node = get_node_or_null("StandingCollision")
	if node and node is CollisionShape3D:
		node.disabled = not enabled
	
	var death_shape = get_node_or_null("DeathArea/StandingDeath")
	if death_shape and death_shape is CollisionShape3D:
		death_shape.disabled = not enabled

func _enable_crouched_collision(enabled: bool) -> void:
	var node = get_node_or_null("CrouchedCollision")
	if node and node is CollisionShape3D:
		node.disabled = not enabled
	
	var death_shape = get_node_or_null("DeathArea/CrouchedDeath")
	if death_shape and death_shape is CollisionShape3D:
		death_shape.disabled = not enabled

func _update_horizontal_velocity(delta: float) -> void:
	var targetX = float(targetLine) * LaneWidth
	var distance = targetX - position.x
	var desired_vel = clamp(distance * LaneResponsiveness, -MaxLaneSpeed, MaxLaneSpeed)
	var smoothing_t = clamp(LaneSmoothing * delta, 0.0, 1.0)
	_horizontal_velocity = lerp(_horizontal_velocity, desired_vel, smoothing_t)
	velocity.x = _horizontal_velocity
	if abs(distance) < 0.01 and abs(_horizontal_velocity) < 0.05:
		position.x = targetX
		_horizontal_velocity = 0.0
		velocity.x = 0.0

func _post_physics_state_fix() -> void:
	if is_on_floor() and currentState == State.JUMPING:
		currentState = State.RUNNING

func _is_collision_lethal(obstacle: Obstacle) -> bool:
	match obstacle.CurrentObstacleType:
		Obstacle.ObstacleType.STANDART:
			return true
		Obstacle.ObstacleType.LOW:
			return currentState != State.JUMPING
		Obstacle.ObstacleType.HIGH:
			return currentState != State.SLIDING
		_:
			return true

func _on_powerup_collider_area_entered(area: Area3D) -> void:
	if area.get_class() == POWERUP_CLASS_NAME or area is Pickupable:
		AddScore.emit(area.Score)
		area.queue_free()

func _find_obstacle_from_node(node: Node) -> Obstacle:
	var cur: Node = node
	var steps := 0
	while cur and steps < 8:
		if cur is Obstacle:
			return cur as Obstacle
		var node_owner = cur.get_owner()
		if node_owner and node_owner is Obstacle:
			return node_owner as Obstacle
		cur = cur.get_parent()
		steps += 1
	return null

func _find_first_collision_shape(node: Node) -> CollisionShape3D:
	if not node:
		return null
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
		var found = _find_first_collision_shape(child)
		if found:
			return found
	return null

func _get_obstacle_top_y(obstacle: Node) -> float:
	var shape_node = _find_first_collision_shape(obstacle)
	if shape_node and shape_node.shape:
		var s = shape_node.shape
		var gpos_y = shape_node.global_transform.origin.y
		if s is BoxShape3D:
			return gpos_y + abs(s.extents.y)
		if s is CapsuleShape3D:
			return gpos_y + abs((s.height * 0.5) + s.radius)
		return shape_node.global_transform.origin.y
	return obstacle.global_transform.origin.y

func _player_head_y() -> float:
	if currentState == State.SLIDING:
		return global_transform.origin.y + _crouched_half
	return global_transform.origin.y + _standing_half

func _check_death_area_overlaps() -> void:
	# Критическая защита: предотвращение двойной смерти
	if _is_dying or currentState == State.DEAD or Engine.time_scale <= 0.0:
		return
	
	if not _death_area:
		return
	
	# Проверка основной области смерти
	var bodies = _death_area.get_overlapping_bodies()
	var areas = _death_area.get_overlapping_areas()
	
	for body in bodies:
		var obstacle = _find_obstacle_from_node(body)
		if obstacle and _is_collision_lethal(obstacle):
			_on_collision_with_obstacle()
			return
	
	for area in areas:
		var obstacle = _find_obstacle_from_node(area)
		if obstacle and _is_collision_lethal(obstacle):
			_on_collision_with_obstacle()
			return
	
	# Проверка головы (только для HIGH препятствий)
	if _head_area:
		var head_bodies = _head_area.get_overlapping_bodies()
		var head_areas = _head_area.get_overlapping_areas()
		
		for body in head_bodies:
			var obstacle = _find_obstacle_from_node(body)
			if obstacle and obstacle.CurrentObstacleType == Obstacle.ObstacleType.HIGH:
				_on_collision_with_obstacle()
				return
		
		for area in head_areas:
			var obstacle = _find_obstacle_from_node(area)
			if obstacle and obstacle.CurrentObstacleType == Obstacle.ObstacleType.HIGH:
				_on_collision_with_obstacle()
				return

func _on_collision_with_obstacle() -> void:
	if _is_dying or currentState == State.DEAD:
		return
	
	_is_dying = true
	
	if death_sound and not death_sound.playing:  
		death_sound.play()
	
	currentState = State.DEAD
	velocity = Vector3.ZERO
	PlayerDied.emit()

func on_kill_by_obstacle(obstacle_node: Node) -> void:
	if currentState == State.DEAD or _is_dying:
		return
	
	var obstacle = null
	if obstacle_node is Obstacle:
		obstacle = obstacle_node as Obstacle
	else:
		obstacle = _find_obstacle_from_node(obstacle_node)
	
	if obstacle and _is_collision_lethal(obstacle):
		_on_collision_with_obstacle()

func _debug_death_area() -> void:
	if not _death_area:
		printerr("DeathArea отсутствует")
		return
	
	var bodies = _death_area.get_overlapping_bodies()
	if bodies.size() > 0:
		print("-- DeathArea overlapping bodies:", bodies.size())
		for b in bodies:
			var ob = _find_obstacle_from_node(b)
			print("  body:", b.name, "class:", b.get_class(), "found_obstacle:", ob)
	
	var areas = _death_area.get_overlapping_areas()
	if areas.size() > 0:
		print("-- DeathArea overlapping areas:", areas.size())
		for a in areas:
			var ob = _find_obstacle_from_node(a)
			print("  area:", a.name, "class:", a.get_class(), "owner:", a.get_owner(), "found_obstacle:", ob)

func _on_game_manager_game_over(score: int) -> void:
	currentState = State.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)

func _on_game_manager_start_game() -> void:
	_is_dying = false
	_pending_end_slide = false
	currentState = State.RUNNING
	set_physics_process(true)

	position = Vector3(0, StartY, 0)
	velocity = Vector3.ZERO
	_horizontal_velocity = 0.0
	targetLine = Line.CENTER
	currentSlidingDuration = SlidingDuration

	_enable_crouched_collision(false)
	_enable_standing_collision(true)
	
	if has_node("Model"):
		$Model.position.y = 0.0
