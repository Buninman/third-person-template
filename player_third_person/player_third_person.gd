extends CharacterBody3D

@export_group("Speeds")
## Скорость вращения камеры
@export var look_speed : float = 1.0
## Базовая скорость передвижения
@export var base_speed : float = 7.0
## Скорость в режиме спринта
@export var sprint_speed : float = 10.0
## Сили прыжка
@export var jump_impulse : float = 10.0
## Скорость разворота можели персонажа на новое направление?
@export var rotation_speed : float = 12.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = ""

@export_group("Camera")
## Дистанция от камеры до модели игрока
@export var spring_length : float = 5.0
## Чувствительность мыши
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export var slide_threshold_angle : float = 45.0  # угол, после которого начинается скольжение
@export var slide_speed : float = 10.0  # скорость скольжения

var can_sprint : bool = false
var mouse_captured : bool = false
var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -30.0
var move_speed := base_speed
@onready var spring_arm_3d = $CameraPivot/SpringArm3D
@onready var _camera_pivot = $CameraPivot
@onready var _camera = %Camera3D
@onready var _skin = %SophiaSkin

enum STATES {IDLE, MOVE, JUMP, SLIDE}
var playerState : STATES = STATES.IDLE

func _ready():
	# Если в поле Инпут указана клавиша для Спринта, он начинает работать
	spring_arm_3d.spring_length = spring_length
	if input_sprint:
		can_sprint = true
	# Захватываем курсор мыши при запуске игры
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func _unhandled_input(event):
	# Выход из режима захвата мыши по нажатию Esc и наоборот
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true

	# Обработка вращения камеры мышью
	var is_camera_motion := (
		event is InputEventMouseMotion and mouse_captured
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

# Функция физики
func _physics_process(delta):
	cameraRotation(delta)
	move()
	jump()
	
	# Передвижение персонажа учитывая его поворот
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var forward = _camera.global_basis.z
	var right = _camera.global_basis.x

	var move_direction = forward * input_dir.y + right * input_dir.x
	move_direction.y = 0
	move_direction = move_direction.normalized()
	# Сохраняем последнее направление игрока
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	
	var y_velocity := velocity.y
	velocity.y = 0.0

	# Поворачиваем модель игрока
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	velocity = velocity.move_toward(move_direction * move_speed, 1)
	velocity.y = y_velocity + _gravity * delta
		
	move_and_slide()

func move():
	if is_on_floor():
		var ground_speed := velocity.length() #Если velocity.length больше нуля, значит персонаж движется
		if ground_speed > 0.5:
			#_skin.move()
			if playerState != STATES.MOVE:
				playerState = STATES.MOVE
				print('move')
		else:
			#_skin.idle()
			if playerState != STATES.IDLE:
				playerState = STATES.IDLE
				print('idle')
		
	if playerState == STATES.MOVE:
		_skin.move()
		# Меняем скорость если нажат спринт
		if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
		else:
			move_speed = base_speed
	if playerState == STATES.IDLE:
		_skin.idle()

func jump():
	if Input.is_action_just_pressed(input_jump) and is_on_floor():
		if playerState != STATES.JUMP:
			playerState = STATES.JUMP
			print('jump')
		velocity.y += jump_impulse #Добавляем значения импульса к вертикальной скорости игрока
		
	if playerState == STATES.JUMP:
		if velocity.y < 0:
			_skin.fall()
		else: _skin.jump()

func cameraRotation(delta):
	# Вращение камеры вокруг персонажа путем вращения Пивота
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6, PI / 3) #Ограничение вращения камеры по вертикалии
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO #Останавливает движение камеры
