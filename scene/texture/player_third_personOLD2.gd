extends CharacterBody3D

## Если true, то направление движения и скорость в полете менять нельзя
@export var blockedFlyingControl = false

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
var move_speed := 0.0
@onready var spring_arm_3d = $CameraPivot/SpringArm3D
@onready var _camera_pivot = $CameraPivot
@onready var _camera = %Camera3D
@onready var _skin = %SophiaSkin

enum STATES {IDLE, RUN, JUMP, SLIDE}
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
	# Выход из режима захвата мыши по нажатию Esc
	if Input.is_key_pressed(KEY_ESCAPE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false

	# Обработка вращения камеры мышью
	var is_camera_motion := (
		event is InputEventMouseMotion and mouse_captured
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

# Функция физики
func _physics_process(delta):
	# Вращение камеры вокруг персонажа путем вращения Пивота
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6, PI / 3) #Ограничение вращения камеры по вертикалии
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO #Останавливает движение камеры
	
	# Передвижение персонажа учитывая его поворот
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var forward = _camera.global_basis.z
	var right = _camera.global_basis.x
	
	var move_direction = forward * input_dir.y + right * input_dir.x
	move_direction.y = 0
	move_direction = move_direction.normalized()
	
	# Меняем скорость если нажат спринт
	if can_sprint and Input.is_action_pressed(input_sprint):
		
			move_speed = sprint_speed
	else:
		move_speed = base_speed
	
	# Физика прыжка
	var y_velocity := velocity.y
	velocity.y = 0.0
	if blockedFlyingControl:
		if is_on_floor():
			velocity = velocity.move_toward(move_direction * move_speed, 1)
	else:
		velocity = velocity.move_toward(move_direction * move_speed, 1)
	velocity.y = y_velocity + _gravity * delta
	
	
	# Проверяем прыгает ли игрок
	var is_starting_jump := Input.is_action_just_pressed(input_jump) and is_on_floor()
	if is_starting_jump:
		velocity.y += jump_impulse #Добавляем значения импульса к вертикальной скорости игрока
	
	move_and_slide()
	
	# Сохраняем последнее направление игрока
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	# Поворачиваем модель игрока
	
	if blockedFlyingControl:
		if is_on_floor():
			var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
			_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	else:
		var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
		_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	# Анимация
	if is_starting_jump:
		_skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		if is_on_wall_only():
			print('wall')
			_skin.wall_slide()
		else:
			_skin.fall()
	elif is_on_floor():
		var ground_speed := velocity.length() #Если velocity.length больше нуля, значит персонаж движется
		if ground_speed > 0.2:
			_skin.move()
		else:
			_skin.idle()
		
		
			
	# После move_and_slide проверяем столкновения
	#for i in get_slide_collision_count():
		#var collision = get_slide_collision(i)
		#var collider = collision.get_collider()
		#
		## Если столкнулись с кубом
		#if collider is RigidBody3D:
			#push_rigid_body(collider, collision)
		#elif collider.has_method("push"):  # Если куб имеет метод push
			#var speed = 5
			#var speed = 5
			#collider.push(velocity.normalized() * speed * 0.5, mass)

#func push_rigid_body(body: RigidBody3D, collision: KinematicCollision3D):
	## Вычисляем направление толчка
	#var push_direction = -collision.get_normal()
	#
	## Вычисляем силу толчка на основе скорости игрока
	#var push_force = velocity.length() * 2.0
	#
	## Применяем силу к RigidBody
	#var force_point = collision.get_position() - body.global_position
	#body.apply_impulse(push_direction * push_force, force_point)
