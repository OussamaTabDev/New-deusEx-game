shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

group_uniforms textures;

uniform sampler2D albedo_texture;

group_uniforms hologram;

uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 core_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float fresnel_strength : hint_range(0.0, 5) = 0.8;
uniform vec3 fresnel_colour : source_color = vec3(1.0, 1.0, 1.0);

group_uniforms scan_lines;

uniform bool enable_scan_lines = true;
uniform float scan_speed : hint_range(-5.0, 5.0, 0.1) = 1.0;
uniform vec4 scan_colour : source_color = vec4(0.0, 1.0, 0.0, 1.0);

uniform float line_density: hint_range(1, 200, 1) = 100;

varying vec4 screen_pos;

vec4 holo_effect(vec3 normal, vec3 view, vec2 uv) {
  float fresnel_factor = pow(1.0 - dot(normal, view), 2.0) * fresnel_strength;
  vec3 fresnel = fresnel_colour * fresnel_factor;

  vec4 base_texture = texture(albedo_texture, uv);
  vec3 holo_base_colour = base_texture.rgb * core_colour.rgb;

  vec4 final_colour = vec4(holo_base_colour, core_colour.a);
  final_colour.rgb += fresnel;

  float final_alpha = core_colour.a * opacity;
  final_colour.a = clamp(final_alpha, 0.0, 1.0);
  return final_colour;
}

vec4 scan_effect(float time, vec3 normal, vec3 view) {
    vec3 ndc = screen_pos.xyz / screen_pos.w;
    vec2 screen_uv = (ndc.xy + 1.0) * 0.5;

    float time_offset = time * scan_speed;
    float scan_pattern = fract(screen_uv.y * line_density - time_offset);

    float scan_line = 1.0 - smoothstep(0.0, 0.5, min(scan_pattern, 1.0 - scan_pattern));

    vec4 final_colour = scan_colour;
    final_colour.a = scan_line * scan_colour.a;
    return final_colour;
}

void vertex() {
    screen_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
    vec4 final_colour = holo_effect(NORMAL, VIEW, UV);
    if(enable_scan_lines) {
      final_colour = mix(final_colour, scan_effect(TIME, NORMAL, VIEW), 0.5);
    }

    EMISSION = final_colour.rgb;
    ALBEDO = final_colour.rgb;
    ALPHA = final_colour.a;
}
