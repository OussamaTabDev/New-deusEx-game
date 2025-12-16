class_name CameraRecoilComponent
extends Node3D

# ============================================================
# SETTINGS
# ============================================================
@export_category("Recoil Settings")
@export var recoil_snappiness: float = 20.0  # How fast it snaps UP
@export var recoil_return_speed: float = 10.0 # How fast it returns to CENTER

@export_category("Shake Settings")
@export var noise_shake_speed: float = 30.0
@export var noise_shake_strength: float = 60.0
@export var shake_decay_rate: float = 5.0

# ============================================================
# INTERNAL STATE
# ============================================================
# Recoil Vectors
var _target_recoil_rot: Vector3 = Vector3.ZERO # The peak recoil position
var _current_recoil_rot: Vector3 = Vector3.ZERO # Where the camera actually is

# Screen Shake (Noise based)
var _shake_power: float = 0.0
var _noise: FastNoiseLite
var _noise_i: float = 0.0
var _current_shake_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
    # Setup simple noise for realistic shake
    _noise = FastNoiseLite.new()
    _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    _noise.frequency = 0.5

func _process(delta: float) -> void:
    # 1. HANDLE RECOIL (The "Kick")
    # Lerp target back to zero (The gun weight pulling it down)
    _target_recoil_rot = lerp(_target_recoil_rot, Vector3.ZERO, recoil_return_speed * delta)
    
    # Lerp current to target (The snap)
    _current_recoil_rot.x = lerp(_current_recoil_rot.x, _target_recoil_rot.x, recoil_snappiness * delta)
    _current_recoil_rot.y = lerp(_current_recoil_rot.y, _target_recoil_rot.y, recoil_snappiness * delta)
    _current_recoil_rot.z = lerp(_current_recoil_rot.z, _target_recoil_rot.z, recoil_snappiness * delta)

    # 2. HANDLE SHAKE (The "Rumble")
    if _shake_power > 0:
        _shake_power = lerp(_shake_power, 0.0, shake_decay_rate * delta)
        _noise_i += delta * noise_shake_speed
        
        # Calculate noise offsets
        var x = _noise.get_noise_2d(_noise_i, 1.0) * _shake_power
        var y = _noise.get_noise_2d(1.0, _noise_i) * _shake_power
        var z = _noise.get_noise_2d(_noise_i, _noise_i) * _shake_power # Roll shake
        
        _current_shake_offset = Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))
    else:
        _current_shake_offset = Vector3.ZERO

    # 3. APPLY TO SELF
    # We apply this to our own rotation. 
    # Since CameraOffset is our CHILD, it will inherit this rotation.
    rotation = _current_recoil_rot + _current_shake_offset

# ============================================================
# PUBLIC API
# ============================================================
## Call this function when the weapon shoots
## recoil_vec: x=pitch (up), y=yaw (side), z=roll (tilt)
func apply_recoil(recoil_vec: Vector3, shake_amount: float = 0.0) -> void:
    # Add to the target, creating a "spike" in rotation
    _target_recoil_rot += Vector3(
        deg_to_rad(recoil_vec.x), 
        deg_to_rad(recoil_vec.y), 
        deg_to_rad(recoil_vec.z)
    )
    
    # Add trauma/shake
    _shake_power = clamp(_shake_power + shake_amount, 0.0, 1.0)