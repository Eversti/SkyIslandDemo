extends Node3D

@export var target_position := Vector3.ZERO
@export var radius := 15.0
@export var min_radius := 4.0
@export var max_radius := 40.0
@export var zoom_speed := 1.0
@export var rotate_speed := 0.01

var angle_x := 0.0  # vertical
var angle_y := 0.0  # horizontal

@onready var camera = $Camera3D

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		angle_y -= event.relative.x * rotate_speed
		angle_x = clamp(angle_x - event.relative.y * rotate_speed, -PI * 0.45, PI * 0.45)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			radius = max(min_radius, radius - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			radius = min(max_radius, radius + zoom_speed)

func _process(delta):
	camera.size = radius  # Radius acts like "zoom level" here
	var x = radius * cos(angle_x) * sin(angle_y)
	var y = radius * sin(angle_x)
	var z = radius * cos(angle_x) * cos(angle_y)

	var camera_position = target_position + Vector3(x, y, z)
	camera.global_transform.origin = camera_position
	camera.look_at(target_position)
