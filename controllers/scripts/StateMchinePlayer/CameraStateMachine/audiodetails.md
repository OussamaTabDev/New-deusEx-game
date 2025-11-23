# PlayerAudioComponent Integration Guide

## 1. Setup in Scene Tree

Add the `PlayerAudioComponent` as a child of your Player node:

```
Player (CharacterBody3D)
├── CameraController
├── FootstepPlayer
├── PlayerAudioComponent  ← Add this
└── ... (other nodes)
```

## 2. Modify Player.gd

Remove the audio code and add a reference to the component:

```gdscript
class_name Player extends CharacterBody3D

# Add this export
@export var audio_component: PlayerAudioComponent

# REMOVE these (now handled by AudioComponent):
# - All @export audio variables (jump_sound, slide_sound, volumes, etc.)
# - footstep_player variable
# - footstep_surface_detector variable
# - LandingPitch, LandingVolume variables
# - The entire _audio_process() function

func _ready():
    # Auto-find audio component if not set
    if not audio_component:
        audio_component = get_node_or_null("PlayerAudioComponent")
```

## 3. Modify CameraController.gd

Add reference and call the audio component during head bob:

```gdscript
class_name CameraController extends Node3D

# Add this export in the Core References section
@export var audio_component: PlayerAudioComponent

# In _update_camera(), modify the head bob section:
func _update_camera(delta: float):
    # ... (existing code)
    
    # Head bob WITH audio sync
    if enable_head_bob:
        var bob_speed_scale = float(player.is_on_floor() and not is_climbing())
        t_bob += delta * player.velocity.length() * bob_speed_scale
        total_offset += _calculate_headbob(t_bob)
        
        # NEW: Sync footsteps with head bob
        if audio_component:
            var state_name = player.state_machine.get_current_state_name() if player.state_machine else ""
            audio_component.process_footstep_sync(t_bob, BOB_FREQ, BOB_AMP, state_name)
    
    # ... (rest of existing code)
```

## 4. Update Your States

Now you can use the **automatic state audio handler** or call sounds individually:

### **Option A: Automatic (Recommended)**

In your base State class or each state:

```gdscript
# In any state script
func enter(previous_state: State) -> void:
    if player.audio_component:
        player.audio_component.handle_state_audio(name, true)
    # ... rest of enter logic

func exit(new_state: State) -> void:
    if player.audio_component:
        player.audio_component.handle_state_audio(name, false)
    # ... rest of exit logic
```

This automatically handles:
- ✅ Jump sounds on JumpingState
- ✅ Slide sounds (start/stop) on SlidingState
- ✅ Dash sounds on DashState
- ✅ Climb sounds (looping) on ClimbState/LadderClimbState
- ✅ Wall run sounds (looping) on WallRunState
- ✅ Swimming sounds (looping) on all swim states
- ✅ Water splash on entering/exiting water

### **Option B: Manual Control**

If you need more control, call specific methods:

```gdscript
# Jump State
func enter(previous_state: State) -> void:
    player.audio_component.play_jump_sound()

# Slide State
func enter(previous_state: State) -> void:
    player.audio_component.play_slide_sound()

func exit(new_state: State) -> void:
    player.audio_component.stop_slide_sound()

# Dash State
func enter(previous_state: State) -> void:
    player.audio_component.play_dash_sound()

# Climb/Ladder State
func enter(previous_state: State) -> void:
    player.audio_component.play_climb_sound()

func exit(new_state: State) -> void:
    player.audio_component.stop_climb_sound()

# Wall Run State
func enter(previous_state: State) -> void:
    player.audio_component.play_wallrun_sound()

func exit(new_state: State) -> void:
    player.audio_component.stop_wallrun_sound()

# Swimming States
func enter(previous_state: State) -> void:
    player.audio_component.play_swim_sound()
    player.audio_component.play_water_splash(true)  # Entering water

func exit(new_state: State) -> void:
    player.audio_component.stop_swim_sound()
    player.audio_component.play_water_splash(false)  # Exiting water
```

## 5. Configure in Editor

1. **Select PlayerAudioComponent node**
2. **Set references**:
   - Player → Your Player node
   - Footstep Player → Your FootstepPlayer node
   - Footstep Surface Detector → Your detector node
   - Jump/Slide/Landing Audio Players → (auto-created if not set)

3. **Assign audio streams**:
   - Jump Sound
   - Slide Sound
   - Dash Sound
   - Climb Sound (looping - like grunt/effort sounds)
   - Wall Run Sound (looping - sliding/friction sound)
   - Swim Sound (looping - water movement)
   - Water Splash Enter (one-shot)
   - Water Splash Exit (one-shot)

4. **Tune settings**:
   - Volume levels (walk, sprint, crouch)
   - Landing thresholds
   - Footstep speed threshold
   - Phase trigger tolerance (lower = more precise, higher = more forgiving)

5. **Set Player reference in CameraController**:
   - Audio Component → Your PlayerAudioComponent node

## 6. Benefits of This Design

✅ **Separation of Concerns**: Audio logic isolated from player/camera
✅ **Automatic Footsteps**: Syncs perfectly with head bob
✅ **Easy to Maintain**: All audio code in one place
✅ **Reusable**: Can be added to any character
✅ **Automatic Landing**: Detects falls and plays appropriate sounds
✅ **Dynamic Volume/Pitch**: Landing sounds adjust to impact force
✅ **Backwards Compatible**: Keeps `_audio_process()` for manual calls

## 7. Alternative: Simple Footstep Sync

If the phase-based method feels too sensitive, use the simpler version:

```gdscript
# In CameraController._update_camera()
audio_component.process_footstep_sync_simple(t_bob, BOB_FREQ, BOB_AMP, state_name)
```

This triggers once per bob cycle instead of twice (left/right).

## 8. Debugging

If footsteps aren't playing:

1. Check `footstep_speed_threshold` - Player must move faster than this
2. Verify Player is on floor (`is_on_floor()`)
3. Check `phase_trigger_tolerance` - Try increasing to 0.2 or 0.3
4. Ensure FootstepPlayer has `_play_interaction()` method
5. Print debug info in `play_footstep()` to verify it's being called

## 9. Fine-Tuning

- **Footsteps too frequent?** Decrease `BOB_FREQ` in CameraController
- **Footsteps not aligned?** Adjust `phase_trigger_tolerance` (0.05 - 0.3)
- **Footsteps cut off?** Check FootstepPlayer's audio settings
- **Landing too sensitive?** Adjust `landing_threshold` (more negative = less sensitive)