shader_type spatial;
render_mode unshaded; // Gives it that flat, cartoony look. Remove for lighting.

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest; // Nearest filter is key for pixel art
uniform float voxel_size = 64.0; // How many "pixels" wide the water is
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

void fragment() {
	// 1. Scale the UVs
	vec2 scaled_uv = UV * uv_scale;
	
	// 2. Add the offset (movement)
	vec2 moving_uv = scaled_uv + uv_offset;
	
	// 3. The Magic: Snap the UVs to a grid
	// We multiply by size, round to nearest integer, then divide back
	vec2 pixelated_uv = floor(moving_uv * voxel_size) / voxel_size;
	
	vec4 tex_color = texture(texture_albedo, pixelated_uv);
	
	// Mix texture with color, keeping alpha
	ALBEDO = tex_color.rgb * albedo.rgb;
	ALPHA = albedo.a * tex_color.a;
}