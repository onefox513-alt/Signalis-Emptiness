extends Node3D

signal ScoreUpdated(score: int)
signal GameOver(score: int)
signal StartGame()

@export var ObstacleScene: Array[PackedScene] = []
@export var PowerupsScene: Array[PackedScene] = []
@export var MinSpawnTime: float = 1.0
@export var MaxSpawnTime: float = 2.0
@export var SpawnDistance: float = -20.0
@export var PickupSpawnChance: float = 0.35

@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var pause_menu: CanvasLayer = $PauseMenu

var is_paused: bool = false
var score: int = 0
var is_game_over: bool = false
var is_transitioning: bool = false
var linePosition: Array = [-2.0, 0.0, 2.0]
var speedMultiplier: float = 1.0
var fence_count: int = 0

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.process_mode = CanvasLayer.PROCESS_MODE_ALWAYS
	
	add_to_group("game_manager")
	
	_connect_player_signals()
	_connect_ui_signals()
	_connect_timers()

func _connect_player_signals() -> void:
	var player = get_node_or_null("Player")
	if not player:
		printerr("Player node not found!")
		return
	
	if player.has_signal("AddScore"):
		if not player.is_connected("AddScore", _on_player_add_score):
			player.connect("AddScore", _on_player_add_score)
	
	if player.has_signal("PlayerDied"):
		if not player.is_connected("PlayerDied", _on_player_died):
			player.connect("PlayerDied", _on_player_died)

func _connect_ui_signals() -> void:
	var ui = get_node_or_null("UIManager")
	if ui and ui.has_signal("StartGame"):
		if not ui.is_connected("StartGame", _on_ui_manager_start_game):
			ui.connect("StartGame", _on_ui_manager_start_game)

func _connect_timers() -> void:
	var spawn_timer = get_node_or_null("SpawnTimer")
	if spawn_timer:
		if not spawn_timer.is_connected("timeout", _on_spawn_timer_timeout):
			spawn_timer.connect("timeout", _on_spawn_timer_timeout)
	
	var score_timer = get_node_or_null("ScoreTimer")
	if score_timer:
		if not score_timer.is_connected("timeout", _on_score_timer_timeout):
			score_timer.connect("timeout", _on_score_timer_timeout)

func _safe_timer_start(timer_name: String) -> void:
	var timer = get_node_or_null(timer_name)
	if timer:
		timer.stop()
		timer.paused = false
		timer.start()

func _safe_timer_stop(timer_name: String) -> void:
	var timer = get_node_or_null(timer_name)
	if timer:
		timer.stop()

func _reset_spawn_timer() -> void:
	var spawn_timer = get_node_or_null("SpawnTimer")
	if not spawn_timer:
		return
	const BASE_DENSITY_Z: float = 2.8  
	var target_spawn_time = BASE_DENSITY_Z / max(0.5, speedMultiplier)
	target_spawn_time = clamp(target_spawn_time, 0.45, 3.0)
	spawn_timer.wait_time = randf_range(target_spawn_time * 0.9, target_spawn_time * 1.1)

func _update_fence_count() -> void:
	fence_count = 0
	for child in $ObstacleContainer.get_children():
		if child is Obstacle and child.position.z > SpawnDistance - 8.0:
			if child.CurrentObstacleType == Obstacle.ObstacleType.STANDART:
				fence_count += 1

func _on_spawn_timer_timeout() -> void:
	if is_game_over or is_transitioning or is_paused:
		return
	
	if ObstacleScene.size() == 0:
		printerr("No obstacle scenes available!")
		return
	
	_update_fence_count()
	var force_simple_obstacle = fence_count >= 2
	
	if not force_simple_obstacle and PowerupsScene.size() > 0 and randf() < PickupSpawnChance:
		var coinScene: PackedScene = PowerupsScene[randi() % PowerupsScene.size()]
		var preview = coinScene.instantiate()
		if preview is Pickupable and preview.CurrentPickupType == Pickupable.PickupType.COIN:
			preview.queue_free()
			spawn_coin_formation(coinScene)
		else:
			preview.position = Vector3(linePosition[randi() % 3], 0, SpawnDistance)
			preview.Speed *= speedMultiplier
			if preview.has_signal("Collected"):
				preview.connect("Collected", _on_pickup_collected)
			$ObstacleContainer.add_child(preview)
		_reset_spawn_timer()
		_safe_timer_start("SpawnTimer")
		return
	
	var obstacleScene: PackedScene
	if force_simple_obstacle:
		var simple_obstacles = []
		for scene in ObstacleScene:
			var temp_preview = scene.instantiate()
			if temp_preview.CurrentObstacleType == Obstacle.ObstacleType.LOW or temp_preview.CurrentObstacleType == Obstacle.ObstacleType.HIGH:
				simple_obstacles.append(scene)
			temp_preview.queue_free()
		
		if simple_obstacles.size() > 0:
			obstacleScene = simple_obstacles[randi() % simple_obstacles.size()]
		else:
			obstacleScene = ObstacleScene[randi() % ObstacleScene.size()]
	else:
		obstacleScene = ObstacleScene[randi() % ObstacleScene.size()]
	
	var obstacle = obstacleScene.instantiate()
	match obstacle.CurrentObstacleType:
		Obstacle.ObstacleType.LOW, Obstacle.ObstacleType.HIGH:
			obstacle.position = Vector3(0, 0, SpawnDistance)
			obstacle.Speed *= speedMultiplier
			$ObstacleContainer.add_child(obstacle)
		Obstacle.ObstacleType.STANDART:
			var openLine = randi() % 3
			for i in range(3):
				if i != openLine:
					var copy = obstacleScene.instantiate()
					copy.position = Vector3(linePosition[i], 0, SpawnDistance)
					copy.Speed *= speedMultiplier
					$ObstacleContainer.add_child(copy)
			obstacle.queue_free()
		_:
			obstacle.position = Vector3(0, 0, SpawnDistance)
			obstacle.Speed *= speedMultiplier
			$ObstacleContainer.add_child(obstacle)
	
	_reset_spawn_timer()
	_safe_timer_start("SpawnTimer")

func _create_coin_at_position(coin_scene: PackedScene, pos: Vector3) -> void:
	var coin = coin_scene.instantiate()
	if coin.has_signal("Collected"):
		coin.connect("Collected", _on_pickup_collected)
	coin.position = pos
	coin.Speed *= speedMultiplier
	$ObstacleContainer.add_child(coin)

func spawn_coin_formation(coinScene: PackedScene) -> void:
	var formation_type = randi() % 6
	var z_step: float = 1.6 * max(1.0, speedMultiplier * 0.7)
	var count: int = 3 + randi() % 5
	var start_line = randi() % 3
	var direction = 1 if randf() > 0.5 else -1
	
	match formation_type:
		0:  # Прямая линия
			for i in range(count):
				_create_coin_at_position(coinScene, Vector3(linePosition[start_line], 0, SpawnDistance + i * z_step))
		1:  # Треугольник
			var base_z = SpawnDistance
			for i in range(3):
				_create_coin_at_position(coinScene, Vector3(linePosition[i], 0, base_z + randf_range(-0.5, 0.5)))
			for i in range(1, 3):
				_create_coin_at_position(coinScene, Vector3(linePosition[1], 0, base_z + i * z_step))
		2:  # Зигзаг
			var z = SpawnDistance
			var cur_line = start_line
			for i in range(count):
				_create_coin_at_position(coinScene, Vector3(linePosition[cur_line], 0, z + i * (z_step * 0.9)))
				cur_line = (cur_line + (1 if i % 2 == 0 else -1) + 3) % 3
		3:  # Змейка
			var cur = start_line
			for i in range(count):
				_create_coin_at_position(coinScene, Vector3(linePosition[cur], 0, SpawnDistance + i * z_step))
				cur = (cur + direction + 3) % 3
		4:  # Пирамида
			var base_z = SpawnDistance
			var mid = int(count / 2.0)
			for i in range(count):
				var offset = i
				_create_coin_at_position(coinScene, Vector3(linePosition[1], 0, base_z + offset * z_step))
				if i < mid:
					_create_coin_at_position(coinScene, Vector3(linePosition[0], 0, base_z + (offset + 0.5) * z_step))
					_create_coin_at_position(coinScene, Vector3(linePosition[2], 0, base_z + (offset + 0.5) * z_step))
		5:  # Синусоида
			for i in range(count):
				var idx = int((sin(float(i) * 0.9 + randf() * 0.5) * 1.1) + 1)
				idx = clamp(idx, 0, 2)
				_create_coin_at_position(coinScene, Vector3(linePosition[idx], 0, SpawnDistance + i * (z_step * 0.9)))

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or is_transitioning:
		return
	
	if event.is_action_pressed("escape"):
		if not is_game_over:
			toggle_pause()

func _on_score_timer_timeout() -> void:
	if is_game_over or is_transitioning or is_paused:
		return
	score += 1
	speedMultiplier = min(speedMultiplier + 0.005, 3.0)
	ScoreUpdated.emit(score)

func _on_player_add_score(p_amount: int) -> void:
	if is_game_over or is_transitioning or is_paused:
		return
	score += int(p_amount * max(1.0, speedMultiplier))
	var speed_boost = 0.015 * (1.0 / max(1.0, speedMultiplier * 0.5))
	speedMultiplier = min(speedMultiplier + speed_boost, 3.0)
	_reset_spawn_timer()  
	ScoreUpdated.emit(score)

func _on_player_died() -> void:
	# Критическая защита: предотвращение двойного вызова смерти
	if is_game_over or is_transitioning:
		return
	
	is_transitioning = true 
	_fade_out_music(0.6)
	await get_tree().create_timer(0.6).timeout
	game_over()

func _on_ui_manager_start_game() -> void:
	# Сброс состояния паузы при новой игре
	if is_paused:
		toggle_pause()
	
	is_game_over = false
	is_transitioning = false
	
	# Безопасная очистка только игровых объектов
	for child in $ObstacleContainer.get_children():
		if child is Obstacle or child is Pickupable:
			if child.has_method("stop_motion"):
				child.stop_motion()
			child.queue_free()
	
	score = 0
	speedMultiplier = 1.0
	ScoreUpdated.emit(score)
	
	if background_music and not background_music.playing:
		background_music.play()
	
	_reset_spawn_timer()
	_safe_timer_start("SpawnTimer")
	_safe_timer_start("ScoreTimer")
	StartGame.emit()

func game_over() -> void:
	# Критическая защита: предотвращение двойного вызова
	if is_game_over:
		return
	
	is_game_over = true
	
	# Остановка всех таймеров
	_safe_timer_stop("SpawnTimer")
	_safe_timer_stop("ScoreTimer")
	
	# Остановка всех объектов
	for child in $ObstacleContainer.get_children():
		if child is Obstacle or child is Pickupable:
			if child.has_method("stop_motion"):
				child.stop_motion()
			else:
				child.set_physics_process(false)
				child.set_process(false)
	
	# Теперь передаем очки в сигнал
	GameOver.emit(score)  # Исправлено: передаем score
	is_transitioning = false 

func _fade_out_music(duration: float) -> void:
	if not background_music or not background_music.playing:
		return
	
	var start_vol = background_music.volume_db
	var elapsed = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t = clamp(elapsed / duration, 0.0, 1.0)
		background_music.volume_db = lerp(start_vol, -80.0, t)
		await get_tree().process_frame

	background_music.stop()
	background_music.volume_db = -8.0

func toggle_pause() -> void:
	is_paused = not is_paused
	
	# Используем Engine.time_scale для полной остановки игры
	Engine.time_scale = 0.0 if is_paused else 1.0
	
	# Отображение меню паузы
	if pause_menu:
		pause_menu.visible = is_paused

func _on_continue_button_down() -> void:
	if is_paused:
		toggle_pause()

func _on_exit_button_down() -> void:
	# Восстановление нормального времени перед выходом
	Engine.time_scale = 1.0
	
	if background_music:
		background_music.stop()
	
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_pickup_collected(amount: int) -> void:
	if is_game_over or is_transitioning or is_paused:
		return
	score += int(amount * max(1.0, speedMultiplier))
	var speed_boost = 0.015 * (1.0 / max(1.0, speedMultiplier * 0.5))
	speedMultiplier = min(speedMultiplier + speed_boost, 3.0)
	_reset_spawn_timer()
	ScoreUpdated.emit(score)
