shader_type canvas_item;

group_uniforms line_characteristics;

uniform float line_width: hint_range(0.001, 0.1) = 0.01;
uniform int segment_count: hint_range(0, 10, 1) = 5;
uniform float segment_length: hint_range(0.1, 1.0, 0.01) = 0.2;
uniform float tail_lag: hint_range(0.1, 1.0, 0.01) = 0.4;
uniform vec4 line_colour: source_color = vec4(1.0, 1.0, 0, 1.0);
uniform float head_size_multiplier: hint_range(0.0, 10.0, 0.1) = 5.0;
uniform vec4 head_colour: source_color = vec4(1.0, 1.0, 0, 1.0);

group_uniforms spawn_characteristics;

uniform int line_count: hint_range(0, 200, 1) = 10;
uniform float line_lifetime: hint_range(0.5, 10.0) = 5.0;
uniform float start_direction_degrees = 0;
uniform bool random_start_direction = true;

group_uniforms apply_conditions;

uniform bool only_on_colour = false;
uniform vec4 apply_colour: source_color;
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture;
uniform vec4 albedo_modulate: source_color = vec4(1.0);

float rand(int seed) {
    float fseed = float(seed);
    return fract(sin(dot(vec2(fseed, fseed * 0.66), vec2(12.9898, 78.233))) * 43758.5453);
}

float get_start(int seed) {
  if(!random_start_direction)
    return radians(start_direction_degrees);
  float rand_dir = floor(rand(seed) * 8.0);
  return rand_dir * radians(45);
}

float get_turn(int seed, float initial, float angle_size) {
  int rand_dir = int(floor(rand(seed) * 2.0));
  if(rand_dir == 0)
    return initial + angle_size;
  else
    return initial - angle_size;
}

float get_segment_intensity(
    vec2 start, vec2 end,
    vec2 segment_process_range, 
    float progress, 
    vec2 uv) {
  vec2 segment_vec = end - start;
  
  vec2 pixel_vec_segment = uv - start;
  float t = clamp(dot(pixel_vec_segment, segment_vec) / (segment_length * segment_length), 0.0, 1.0);
  vec2 closest_point = start + t * segment_vec;
  float distance_to_segment = distance(uv, closest_point);
  
  float point_progress = mix(segment_process_range.x, segment_process_range.y, t);
  
  if (point_progress <= min(progress, 1.0 - tail_lag) && point_progress >= progress - tail_lag) {      
      float intensity = 1.0 - smoothstep(0.0, line_width, distance_to_segment);
      float lit_progress = (point_progress - (progress - tail_lag)) / tail_lag;
      return intensity * lit_progress;
  }
  
  return 0.0;
}

float render_line(float time, vec2 uv, out float head_intensity) {
  float local_time = time / line_lifetime;
  int seed = int(floor(local_time));
  float progress = fract(local_time);
    
  float line_intensity = 0.0;
  
  vec2 last_point = vec2(rand(seed), rand(seed + 1));
  float last_angle = get_start(seed);
  vec2 last_dir = vec2(cos(last_angle), sin(last_angle));
  
  float last_progress = 0.0;
  
  for(int j = 0; j < segment_count; j++) {
    vec2 segment_bounds = vec2(last_progress, last_progress + (1.0-tail_lag)/float(segment_count));
    last_progress = segment_bounds.y;
    if(progress < segment_bounds.x)
      break;
      
    vec2 next_point = last_point + last_dir * segment_length;
    float next_angle = get_turn(seed + j, last_angle, radians(45));
    vec2 next_dir = vec2(cos(next_angle), sin(next_angle));
    
    line_intensity = max(line_intensity, get_segment_intensity(
        last_point, next_point, 
        segment_bounds,
        progress, 
        uv));
        
    if(progress >= segment_bounds.x && progress <= segment_bounds.y) {
      vec2 head_pos = last_point + last_dir * segment_length * (progress - segment_bounds.x) / (segment_bounds.y - segment_bounds.x);;
      float head_glow = 1.0 - smoothstep(0.0, line_width * head_size_multiplier, distance(uv, head_pos));
      head_intensity = head_glow;
    }
        
    last_point = next_point;
    last_angle = next_angle;
    last_dir = next_dir;
  }
  
  return line_intensity;
}

void fragment() {
    vec4 under_colour = COLOR;
    if(only_on_colour && under_colour != apply_colour)
    {
      COLOR = under_colour;
    }
    else
    {    
      if(use_albedo_texture)
      {
        under_colour = texture(albedo_texture, UV);
        under_colour *= albedo_modulate;
      }
      
      // correct for aspect ratio
      vec2 uv_dx = dFdx(UV);
      vec2 uv_dy = dFdy(UV);
      
      float stretch_x = length(uv_dx);
      float stretch_y = length(uv_dy);
      float aspect_ratio = stretch_x / stretch_y;
      
      vec2 centered = UV - vec2(0.5);
      centered.y *= aspect_ratio;
      vec2 uv = centered + vec2(0.5);
    
      // draw lines
      float line_intensity = 0.0;
      float head_intensity = 0.0;
      for(int i = 0; i < line_count; i++) {
        float offset = float(i) * 123.123;
        float current_head;
        float current_line = render_line(TIME + offset, uv, current_head);
        line_intensity = max(line_intensity, current_line);
        head_intensity = max(head_intensity, current_head);
      }
      
      if(head_intensity > 0.0)
        COLOR = mix(under_colour, head_colour, head_intensity * head_colour.a);
      else
        COLOR = mix(under_colour, line_colour, line_intensity * line_colour.a);
    }
}