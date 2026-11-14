shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.3) = 0.09;
uniform vec4 edge_color : source_color = vec4(0.38, 0.90, 1.0, 1.0);
uniform float noise_scale : hint_range(1.0, 64.0) = 20.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a <= 0.001 || dissolve_amount <= 0.0) {
		COLOR = tex;
	} else {
		float n = value_noise(UV * noise_scale) * 0.72 + value_noise(UV * noise_scale * 2.3) * 0.28;
		// Leve viés de dissolução de fora/baixo para dar sensação de solvatação na água
		float threshold = clamp(n * 0.82 + (1.0 - UV.y) * 0.18, 0.0, 1.0);
		float cutoff = dissolve_amount * (1.0 + edge_width);

		if (threshold < cutoff - edge_width) {
			COLOR = vec4(tex.rgb, 0.0);
		} else if (threshold < cutoff) {
			float edge_t = 1.0 - (threshold - (cutoff - edge_width)) / max(edge_width, 0.0001);
			vec3 glow = mix(edge_color.rgb, vec3(0.92, 0.99, 1.0), edge_t * 0.65);
			COLOR = vec4(glow, tex.a);
		} else {
			COLOR = tex;
		}
	}
}
