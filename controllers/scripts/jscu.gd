extends CharacterBody3D

@export var WALK_SPEED = 5.0
@export var SPRINT_SPEED = 8.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY : float = 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)
@export var CAMERA_CONTROLLER : Camera3D

var _mouse_input : bool = false
var _rotation_input : float
var _tilt_input : float
var _mouse_rotation : Vector3
var _player_rotation : Vector3
var _camera_rotation : Vector3
var SPEED = WALK_SPEED

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _unhandled_input(event: InputEvent) -> void:

    _mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
    if _mouse_input:
        _rotation_input = -event.relative.x * MOUSE_SENSITIVITY
        _tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _input(event):

    if event.is_action_pressed("exit"):
        get_tree().quit()

func _update_camera(delta):

    # Rotates camera using euler rotation
    _mouse_rotation.x += _tilt_input * delta
    _mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
    _mouse_rotation.y += _rotation_input * delta

    _player_rotation = Vector3(0.0,_mouse_rotation.y,0.0)
    _camera_rotation = Vector3(_mouse_rotation.x,0.0,0.0)

    CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
    global_transform.basis = Basis.from_euler(_player_rotation)

    CAMERA_CONTROLLER.rotation.z = 0.0

    # Head bob
    t_bob += delta * velocity.length() * float(is_on_floor())
    CAMERA_CONTROLLER.transform.origin = _headbob(t_bob)

    # FOV
    var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
    var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
    CAMERA_CONTROLLER.fov = lerp(CAMERA_CONTROLLER.fov, target_fov, delta * 8.0)

    _rotation_input = 0.0
    _tilt_input = 0.0

func _update_speed(delta):
    if Input.is_action_pressed("sprint"):
        SPEED = lerp(SPEED, SPRINT_SPEED, 3.0 * delta)
    else:
        SPEED = lerp(SPEED, WALK_SPEED, 2.5 * delta)

func _ready():

    # Get mouse input
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):

    # Update camera movement based on mouse movement
    _update_camera(delta)
    _update_speed(delta)
    # Add the gravity.
    if not is_on_floor():
        velocity.y -= gravity * delta

    # Handle Jump.
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Get the input direction and handle the movement/deceleration.
    # As good practice, you should replace UI actions with custom gameplay actions.
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

    if direction:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)
        velocity.z = move_toward(velocity.z, 0, SPEED)

    move_and_slide()

func _headbob(time) -> Vector3:
    var pos = Vector3.ZERO
    pos.y = sin(time * BOB_FREQ) * BOB_AMP
    pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
    return pos
