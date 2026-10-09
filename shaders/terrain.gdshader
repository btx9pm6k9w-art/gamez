shader_type spatial;
// Desert-coast terrain: sand, dry scrub, rock on slopes, wet sand at the
// shoreline, white salt-crust sabkha on the low coastal flats, orange dune
// sand with wind ripples (vertex green), pebbly wadi gravel (vertex blue) and
// scorch marks painted into vertex red by explosions.
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 sand_light : source_color = vec3(0.80, 0.68, 0.50);
uniform vec3 sand_dark : source_color = vec3(0.62, 0.50, 0.36);
uniform vec3 scrub_color : source_color = vec3(0.40, 0.40, 0.24);
uniform vec3 rock_color : source_color = vec3(0.46, 0.40, 0.35);
uniform vec3 wet_color : source_color = vec3(0.42, 0.35, 0.27);
uniform vec3 scorch_color : source_color = vec3(0.045, 0.04, 0.035);
uniform vec3 dune_color : source_color = vec3(0.86, 0.6, 0.38);
uniform vec3 gravel_color : source_color = vec3(0.55, 0.52, 0.47);
uniform vec3 salt_color : source_color = vec3(0.86, 0.84, 0.78);
uniform sampler2D detail_noise : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float water_level = 0.0;
uniform bool use_vertex_scorch = true;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Triplanar sample so cliffs do not stretch.
vec4 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * scale) * w.x + texture(tex, p.xz * scale) * w.y + texture(tex, p.xy * scale) * w.z;
}

void fragment() {
	float n_large = texture(detail_noise, world_pos.xz * 0.018).r;
	float n_mid = triplanar(detail_noise, world_pos, world_normal, 0.09).r;
	float n_fine = triplanar(detail_noise, world_pos, world_normal, 0.6).r;
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);

	vec3 col = mix(sand_dark, sand_light, clamp(n_large * 0.6 + n_mid * 0.5, 0.0, 1.0));
	// Wind ripples in the sand.
	col *= 0.94 + 0.06 * sin(world_pos.x * 1.7 + world_pos.z * 0.6 + n_mid * 6.0);

	float scrub = smoothstep(0.58, 0.72, n_large + n_fine * 0.15)
		* (1.0 - smoothstep(0.08, 0.2, slope))
		* smoothstep(water_level + 1.2, water_level + 2.5, world_pos.y);
	col = mix(col, scrub_color * (0.7 + 0.5 * n_fine), scrub * 0.75);

	// Sabkha: cracked salt crust on flat ground just above the tide line.
	float salt = smoothstep(water_level + 0.5, water_level + 0.8, world_pos.y) * (1.0 - smoothstep(water_level + 1.3, water_level + 1.9, world_pos.y))
		* (1.0 - smoothstep(0.03, 0.08, slope)) * smoothstep(0.35, 0.55, n_large + n_fine * 0.2);
	float cracks = smoothstep(0.46, 0.5, abs(fract(n_mid * 9.0) - 0.5));
	col = mix(col, salt_color * (0.92 + 0.08 * n_fine) * (1.0 - cracks * 0.25), salt * 0.85);

	float dune = use_vertex_scorch ? clamp(COLOR.g, 0.0, 1.0) : 0.0;
	vec3 dune_col = dune_color * (0.85 + 0.25 * n_mid);
	// Fine ripples across the wind and darker shaded lee faces.
	dune_col *= 0.9 + 0.1 * sin(world_pos.x * 2.6 + world_pos.z * 1.1 + n_fine * 4.0);
	col = mix(col, dune_col, dune);

	float gravel = use_vertex_scorch ? clamp(COLOR.b, 0.0, 1.0) : 0.0;
	vec3 pebbles = gravel_color * (0.6 + 0.8 * smoothstep(0.35, 0.75, n_fine)) * (0.8 + 0.4 * n_mid);
	col = mix(col, pebbles, gravel * 0.9);

	float rock = smoothstep(0.16, 0.32, slope + (n_mid - 0.5) * 0.18) * (1.0 - dune * 0.9);
	vec3 rock_col = rock_color * (0.7 + 0.6 * n_fine);
	col = mix(col, rock_col, rock);

	float wet = 1.0 - smoothstep(water_level + 0.05, water_level + 1.0, world_pos.y);
	col = mix(col, wet_color, wet * 0.85);

	float scorch = use_vertex_scorch ? clamp(COLOR.r, 0.0, 1.0) : 0.0;
	col = mix(col, scorch_color * (0.6 + 0.8 * n_fine), scorch * 0.92);

	ALBEDO = col;
	ROUGHNESS = mix(mix(mix(0.93, 0.78, rock), 0.7, salt), 0.32, wet);
	SPECULAR = 0.45;
	vec3 nm = triplanar(detail_normal, world_pos, world_normal, 0.25).rgb;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = mix(0.5, 1.6, rock) + scorch * 0.6 + gravel * 1.2 - dune * 0.3;
	AO = mix(1.0, 0.7, scorch);
	AO_LIGHT_AFFECT = 0.3;
}
