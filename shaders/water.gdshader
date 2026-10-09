shader_type spatial;
// Gulf water. Opaque on purpose so screen-space reflections and SDFGI pick it
// up. Shallow colour and shore foam come from the terrain height texture.
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.48, 0.50);
uniform vec3 foam_color : source_color = vec3(0.92, 0.94, 0.92);
uniform sampler2D wave_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_height : filter_linear;
uniform float map_size = 192.0;
uniform float water_level = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Gentle swell.
	float swell = sin(world_pos.x * 0.15 + TIME * 0.8) * 0.06 + sin(world_pos.z * 0.22 + TIME * 1.1) * 0.04;
	VERTEX.y += swell;
}

void fragment() {
	vec2 uv = world_pos.xz;
	vec2 map_uv = uv / map_size;
	float ground = texture(terrain_height, clamp(map_uv, vec2(0.0), vec2(1.0))).r;
	// Outside the map there is no heightmap, so the sea is deep. Blend into
	// that over the last 12 m instead of switching at the edge, which drew a
	// straight seam across the water west of the pier.
	float edge = min(min(uv.x, map_size - uv.x), min(uv.y, map_size - uv.y));
	float depth = mix(6.0, max(water_level - ground, 0.0), smoothstep(0.0, 12.0, edge));

	float shallow = 1.0 - smoothstep(0.0, 4.0, depth);
	ALBEDO = mix(deep_color, shallow_color, shallow);

	float n = texture(foam_noise, uv * 0.15 + vec2(TIME * 0.02, 0.0)).r;
	float shore = 1.0 - smoothstep(0.0, 0.6 + n * 0.5, depth);
	float wave_band = smoothstep(0.55, 0.9, sin(depth * 5.0 - TIME * 1.6 + n * 4.0) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, 1.6, depth));
	float foam = clamp(shore + wave_band * 0.5, 0.0, 1.0) * smoothstep(0.35, 0.65, n + shore * 0.4);
	ALBEDO = mix(ALBEDO, foam_color, foam);

	vec3 na = texture(wave_normal_a, uv * 0.045 + vec2(TIME * 0.012, TIME * 0.006)).rgb;
	vec3 nb = texture(wave_normal_b, uv * 0.11 - vec2(TIME * 0.009, -TIME * 0.014)).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.5));
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = mix(0.04, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
