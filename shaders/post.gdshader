shader_type canvas_item;
// Full-screen post-process. One shader, many presets (see autoload/post.gd).
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel = 0.0;        // block size in screen px (0 = off)
uniform float curvature = 0.0;    // CRT barrel distortion
uniform float scanline = 0.0;     // 0..1 scanline darkness
uniform float mask = 0.0;         // 0..1 RGB phosphor mask
uniform float chroma = 0.0;       // chromatic aberration, in px
uniform float vignette = 0.0;     // 0..1
uniform float grain = 0.0;        // film grain amount
uniform float levels = 0.0;       // colour steps per channel (0 = off)
uniform float dither = 0.0;       // ordered dither strength (with levels)
uniform float bloom = 0.0;        // cheap soft glow from neighbours

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	bool outside = false;
	if (curvature > 0.0) {
		vec2 cc = uv - 0.5;
		uv += cc * dot(cc, cc) * curvature * 2.0;
		outside = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	}
	vec2 puv = uv;
	if (pixel > 0.0) {
		vec2 grid = res / pixel;
		puv = (floor(uv * grid) + 0.5) / grid;
	}
	vec2 off = vec2(chroma / res.x, 0.0);
	vec3 col = vec3(
		texture(screen_tex, puv + off).r,
		texture(screen_tex, puv).g,
		texture(screen_tex, puv - off).b);
	if (bloom > 0.0) {
		vec2 s = 3.0 / res;
		vec3 b = texture(screen_tex, puv + vec2(s.x, 0.0)).rgb + texture(screen_tex, puv - vec2(s.x, 0.0)).rgb
			+ texture(screen_tex, puv + vec2(0.0, s.y)).rgb + texture(screen_tex, puv - vec2(0.0, s.y)).rgb;
		col += max(b * 0.25 - 0.6, 0.0) * bloom;
	}
	if (levels > 0.0) {
		float d = (bayer4(floor(FRAGCOORD.xy / max(pixel, 1.0))) - 0.5) * dither / levels;
		col = floor(clamp(col + d, 0.0, 1.0) * levels + 0.5) / levels + max(col - 1.0, 0.0);
	}
	if (scanline > 0.0) {
		float s = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159 * 0.66);
		col *= 1.0 - scanline * (1.0 - s);
	}
	if (mask > 0.0) {
		int i = int(mod(FRAGCOORD.x, 3.0));
		vec3 m = vec3(i == 0 ? 1.0 : 1.0 - mask, i == 1 ? 1.0 : 1.0 - mask, i == 2 ? 1.0 : 1.0 - mask);
		col *= m;
	}
	if (grain > 0.0) {
		col += (hash(FRAGCOORD.xy) - 0.5) * grain;
	}
	if (vignette > 0.0) {
		vec2 v = SCREEN_UV - 0.5;
		col *= 1.0 - vignette * smoothstep(0.25, 0.85, length(v * vec2(1.0, 1.1)) * 1.4);
	}
	COLOR = vec4(outside ? vec3(0.0) : col, 1.0);
}
