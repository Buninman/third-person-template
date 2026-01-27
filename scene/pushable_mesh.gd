extends RigidBody3D

## Сила толчка от игрока
@export var push_force : float = 15.0
	
func _on_area_3d_body_entered(body: Node3D):
	if body is CharacterBody3D:
		print('push')
		# Вычисляем направление от игрока к кубу
		var direction = global_position - body.global_position
		direction = direction.normalized()
		
		# Применяем силу
		apply_impulse(direction * push_force)
