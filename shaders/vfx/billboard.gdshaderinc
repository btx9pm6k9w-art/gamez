// Camera-facing particle quad that keeps the particle's spin (INSTANCE_CUSTOM.x)
// and scale. Same maths as BaseMaterial3D's BILLBOARD_PARTICLES mode.
mat4 billboard_modelview(mat4 model, mat4 view, mat4 inv_view, float spin) {
	mat4 world = mat4(normalize(inv_view[0]), normalize(inv_view[1]), normalize(inv_view[2]), model[3]);
	world = world * mat4(vec4(cos(spin), -sin(spin), 0.0, 0.0), vec4(sin(spin), cos(spin), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mat4 mv = view * world;
	return mv * mat4(vec4(length(model[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(model[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(model[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

// Hot-to-cold flame colour: white core, yellow, orange, deep red, black.
vec3 fire_ramp(float t) {
	vec3 c = mix(vec3(0.0), vec3(0.45, 0.04, 0.0), smoothstep(0.0, 0.2, t));
	c = mix(c, vec3(1.0, 0.3, 0.03), smoothstep(0.15, 0.45, t));
	c = mix(c, vec3(1.0, 0.68, 0.22), smoothstep(0.4, 0.75, t));
	return mix(c, vec3(1.0, 0.95, 0.82), smoothstep(0.75, 1.0, t));
}

// Fade a transparent surface where it meets opaque geometry ("soft particles").
float soft_fade(sampler2D depth_tex, vec2 screen_uv, mat4 inv_projection, vec3 vertex, float distance) {
	float depth = textureLod(depth_tex, screen_uv, 0.0).r;
	vec4 scene = inv_projection * vec4(screen_uv * 2.0 - 1.0, depth, 1.0);
	scene.xyz /= scene.w;
	return clamp((vertex.z - scene.z) / distance, 0.0, 1.0);
}
