shader_type canvas_item;
// Cinematic finishing pass over the 3D image: light sharpening (counters TAA
// softness on Retina screens), lens chromatic fringe at the edges, vignette
// very fine film grain, and a warm exposure punch when a big blast goes off.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float sharpen = 0.0; // the MetalFX / FSR upscaler already sharpens
uniform float chroma = 0.0; // optional cinematic extras, off for a clean image
uniform float vignette = 0.0; // the pass only shows during blast flashes, so a vignette would pop
uniform float grain = 0.0;
uniform float flash = 0.0; // 0..1 brief exposure punch from big blasts

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 fringe = d * r2 * (chroma + flash * 2.5) * 0.02;
	vec3 c = texture(screen_tex, uv).rgb;
	// The lens fringe and the sharpening cost six more full-screen samples at
	// Retina size, so each only runs when it is switched on (or during a flash).
	if (chroma + flash > 0.001) {
		c.r = texture(screen_tex, uv + fringe).r;
		c.b = texture(screen_tex, uv - fringe).b;
	}
	if (sharpen > 0.001) {
		vec3 blur = (texture(screen_tex, uv + vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb
			+ texture(screen_tex, uv - vec2(0.0, px.y)).rgb) * 0.25;
		c = max(c + (c - blur) * sharpen, vec3(0.0));
	}
	c += c * flash * vec3(0.55, 0.38, 0.2) + vec3(0.06, 0.035, 0.015) * flash;
	c *= 1.0 - vignette * smoothstep(0.08, 0.5, r2);
	float n = fract(sin(dot(uv * vec2(1920.0, 1080.0) + fract(TIME) * 97.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain * (1.0 - clamp(dot(c, vec3(0.33)), 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
