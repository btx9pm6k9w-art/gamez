shader_type spatial;
// Screen-space refraction for heat haze above fires and the expanding
// shockwave ring of big blasts. Reads the opaque scene behind it and bends it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/vfx/billboard.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_normal : filter_linear_mipmap, repeat_enable;
instance uniform float progress = 0.0;
instance uniform float strength = 1.0;
instance uniform float ring = 0.0;

void vertex() {
	MODELVIEW_MATRIX = billboard_modelview(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, 0.0);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	vec2 offset;
	if (ring > 0.5) {
		float band = 1.0 - smoothstep(0.0, 0.16, abs(r - progress));
		offset = c / max(r, 0.001) * band * (1.0 - progress) * 0.045;
	} else {
		vec2 n = texture(noise_normal, UV * 1.4 + vec2(0.0, TIME * 0.7)).rg - 0.5;
		offset = n * (1.0 - smoothstep(0.15, 1.0, r)) * (1.0 - progress) * 0.022;
	}
	offset *= strength * clamp(40.0 / -VERTEX.z, 0.25, 1.5);
	ALBEDO = textureLod(screen_tex, SCREEN_UV + vec2(offset.x, -offset.y), 0.0).rgb;
	ALPHA = 1.0 - smoothstep(0.92, 1.0, r);
}
