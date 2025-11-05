@tool
extends RayCast3D

# Adjust these in the Inspector
@export var scan_amplitude: float = 2.0  # How far up/down to scan (in Y)
@export var scan_speed: float = 2.0       # Speed of the scanning motion
var current_position_y: float = 0.0
func _ready():
    current_position_y = position.y
# Called every physics frame
func _physics_process(delta: float) -> void:
    # Use a sine wave to smoothly oscillate between -amplitude and +amplitude
    var offset_y = sin(Time.get_ticks_msec() * 0.001 * scan_speed) * (scan_amplitude) 
    
    # Point the raycast straight down the local -Y or +Y? 
    # By default, RayCast3D points in -Z. But you want vertical (Y) scan.
    # So we override cast_to to be along local Y axis with dynamic length.
    
    # If you want it to point downward when offset is negative:
    position = Vector3(0, offset_y +current_position_y  , 0)  
    
    # Optional: force update (not usually needed in _physics_process)
    force_raycast_update()