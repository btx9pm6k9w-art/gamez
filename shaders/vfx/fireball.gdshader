shader_type spatial;
// Volumetric-looking fireball on a displaced sphere. 3D noise boils the
// surface, the core burns white-hot and the rim cools to orange; as progress
// runs 0 -> 1 the fire cools into black soot and the ball tears apart.
// Uses alpha scissor so it stays in the opaque pass (correct depth, SSAO,
// no sorting problems with the smoke around it).
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/vfx/billboard.gdshaderinc"

instance uniform float progress = 0.0;
instance uniform float seed = 0.0;
uniform float displacement = 0.45;
uniform float emission_power = 14.0;

varying vec3 v_pos;
varying float v_noise;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	vec3 boil = vec3(seed * 17.0, -TIME * 0.9 - progress * 2.5, seed * 5.0);
	float n = fbm(VERTEX * 2.4 + boil);
	VERTEX += NORMAL * (n - 0.45) * displacement * (1.0 + progress);
	v_pos = VERTEX * 3.2 + boil * 1.3;
	v_noise = n;
}

void fragment() {
	float n = fbm(v_pos) * 0.6 + v_noise * 0.4;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float heat = clamp(facing * 0.8 + n * 0.7 - progress * 1.35, 0.0, 1.0);
	ALBEDO = mix(vec3(0.035, 0.03, 0.028), vec3(0.18, 0.16, 0.15), n);
	ROUGHNESS = 1.0;
	EMISSION = fire_ramp(heat) * heat * heat * emission_power;
	ALPHA = n * 0.9 + 0.62 - progress * 1.05;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
