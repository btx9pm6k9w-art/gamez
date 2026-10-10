shader_type spatial;
// Flame licks: additive HDR fire whose temperature drops over the particle's
// life (white-yellow core to deep red), broken up by scrolling noise so no two
// sprites look alike. Bright enough for the glow pass to bloom.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled;

#include "res://shaders/vfx/billboard.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float intensity = 7.0;
uniform float soft_distance = 0.8;
uniform float cooling = 1.25;

varying float v_life;
varying float v_seed;

void vertex() {
	MODELVIEW_MATRIX = billboard_modelview(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, INSTANCE_CUSTOM.x);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_life = INSTANCE_CUSTOM.y;
	v_seed = fract(float(INSTANCE_ID) * 0.7548776);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	vec2 scroll = vec2(v_seed * 5.1, v_seed * 2.7 + TIME * 0.6);
	float n = texture(noise_tex, UV * 0.7 + scroll).r * 0.6 + texture(noise_tex, UV * 1.6 - scroll * 1.3).r * 0.4;
	float core = 1.0 - smoothstep(0.0, 1.0, r + (n - 0.5) * 0.8);
	float heat = clamp(core * (0.7 + n * 0.6) - v_life * cooling + 0.35, 0.0, 1.0);
	float a = smoothstep(0.02, 0.3, core * (1.0 - v_life * 0.8)) * COLOR.a;
	a *= soft_fade(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX, soft_distance);
	ALBEDO = fire_ramp(heat) * COLOR.rgb * intensity * (0.35 + heat);
	ALPHA = clamp(a, 0.0, 1.0);
}
