shader_type spatial;
// Billowing smoke and dust puffs. Each puff is lit like a soft ball by the sun
// and GI, its edge is eaten away by two layers of drifting noise as it ages,
// it fades into the ground instead of clipping, and explosion smoke glows from
// the fire inside during the first part of its life.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/vfx/billboard.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float soft_distance = 1.5;
uniform float erosion = 0.55;
uniform float detail_scale = 0.6;
uniform float emission_strength = 0.0;
uniform vec3 emission_color : source_color = vec3(1.0, 0.42, 0.12);
uniform float emission_fade = 0.22;

varying float v_life;
varying float v_seed;

void vertex() {
	MODELVIEW_MATRIX = billboard_modelview(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, INSTANCE_CUSTOM.x);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_life = INSTANCE_CUSTOM.y;
	v_seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	vec2 drift = vec2(v_seed * 7.3, v_seed * 3.1) + vec2(TIME * 0.02, -TIME * 0.035);
	float n1 = texture(noise_tex, UV * detail_scale + drift).r;
	float n2 = texture(noise_tex, UV * detail_scale * 2.3 - drift * 1.7).r;
	float n = n1 * 0.65 + n2 * 0.35;
	float shape = 1.0 - smoothstep(0.3, 1.0, r + (n - 0.5) * 0.7);
	float cut = v_life * erosion;
	float density = smoothstep(cut, cut + 0.3, shape * (0.5 + n * 0.7));

	vec3 ball = vec3(c.x, -c.y, sqrt(max(1.0 - r * r, 0.05)));
	NORMAL = normalize(ball + vec3(n1 - 0.5, n2 - 0.5, 0.0) * 0.8);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	float glow = emission_strength * (1.0 - smoothstep(0.0, emission_fade, v_life));
	EMISSION = emission_color * glow * (0.3 + n) * (1.0 - r);
	ALPHA = clamp(density * COLOR.a * soft_fade(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX, soft_distance), 0.0, 1.0);
}
