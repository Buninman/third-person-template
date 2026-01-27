extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_impulse := 8.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -30.0

@onready var _camera_pivot = $CameraPivot
@onready var _camera = %Camera3D
@onready var _skin = %SophiaSkin


# Убирает курсор мыши при нажатии ЛКМ и появляет на ЕСК
func _input(event):
	if event.is_action_pressed("ui_accept"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Функция которая берет управление мышью только когда мышь находится в окне игры
func _unhandled_input(event):
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

# Функция физики
func _physics_process(delta):
	# Вращение камеры вокруг персонажа путем вращения Пивота
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6, PI / 3) #Ограничение вращения камеры по вертикали
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO #Останавливает движение камеры
	
	# Передвижение персонажа учитывая его поворот
	var raw_input := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward")
	var forward = _camera.global_basis.z
	var right = _camera.global_basis.x
	
	var move_direction = forward * raw_input.y + right * raw_input.x
	move_direction.y = 0
	move_direction = move_direction.normalized()
	
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta
	
	# Proveriaem prigaet li igrok
	var is_starting_jump := Input.is_action_just_pressed("jump") and is_on_floor()
	if is_starting_jump:
		velocity.y += jump_impulse #Dobavliaem Impulse k vertikalnoy skorosti
	
	move_and_slide()
	
	# Сохраняем последнее направление игрока
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	# Поворачиваем игрока
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	# Animaciya
	if is_starting_jump:
		_skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		_skin.fall()
	elif is_on_floor():
		var ground_speed := velocity.length() #Esli peremennaya bolshe 0 to personaj dvijetsa
		if ground_speed > 0.2:
			_skin.move()
		else:
			_skin.idle()
	
	# Vistrel
	if Input.is_action_pressed("shoot") and %Timer.is_stopped():
		_shoot_bullet()
			
func _shoot_bullet():
	const BULLET_3D = preload("uid://eapswnocn2j7")
	var new_bullet = BULLET_3D.instantiate()
	%Marker3D.add_child(new_bullet)
	new_bullet.global_transform = %Marker3D.global_transform
	
	%Timer.start()
