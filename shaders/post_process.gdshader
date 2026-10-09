shader_type canvas_item;
// Cinematic finishing pass over the 3D image: light sharpening (counters TAA
// softness on Retina screens), lens chromatic fringe at the edges, vignette
// and very fine film grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float sharpen = 0.3;
uniform float chroma = 0.5;
uniform float vignette = 0.32;
uniform float grain = 0.018;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 fringe = d * r2 * chroma * 0.02;
	vec3 c;
	c.r = texture(screen_tex, uv + fringe).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - fringe).b;
	vec3 blur = (texture(screen_tex, uv + vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb
		+ texture(screen_tex, uv - vec2(0.0, px.y)).rgb) * 0.25;
	c = max(c + (c - blur) * sharpen, vec3(0.0));
	c *= 1.0 - vignette * smoothstep(0.08, 0.5, r2);
	float n = fract(sin(dot(uv * vec2(1920.0, 1080.0) + fract(TIME) * 97.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain * (1.0 - clamp(dot(c, vec3(0.33)), 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
