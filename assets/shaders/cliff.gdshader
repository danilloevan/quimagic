shader_type canvas_item;
render_mode unshaded;

// Perfil da falésia por coluna de pixel (gerado em CliffRenderer):
//   linha 0: R = base (com rochas arredondadas), G = topo/borda, B = t da rocha da base (-1..1), A = largura da rocha da base (px)
//   linha 1: R = base suave (sem rochas), G = t da rocha da borda (-1..1), B = largura da rocha da borda (px)
uniform sampler2D profile : filter_nearest, repeat_disable;
uniform vec2 area_size = vec2(2048.0, 512.0);
uniform float seed = 0.0;
uniform float shadow_px = 6.0;

uniform vec4 col_outline : source_color = vec4(0.204, 0.122, 0.067, 1.0);
uniform vec4 col_dark : source_color = vec4(0.353, 0.216, 0.110, 1.0);
uniform vec4 col_mid_dark : source_color = vec4(0.478, 0.298, 0.149, 1.0);
uniform vec4 col_mid : source_color = vec4(0.604, 0.400, 0.204, 1.0);
uniform vec4 col_light : source_color = vec4(0.725, 0.510, 0.275, 1.0);
uniform vec4 col_highlight : source_color = vec4(0.847, 0.651, 0.388, 1.0);
uniform vec4 col_shadow : source_color = vec4(0.06, 0.14, 0.02, 0.40);

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))) + seed) * 43758.5453);
}

// Dithering ordenado 4x4 (Bayer) para transições de tom com cara de pixel art
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int b_lo = (((x & 1) ^ (y & 1)) << 1) | (y & 1);
	int xh = (x >> 1) & 1;
	int yh = (y >> 1) & 1;
	int b_hi = ((xh ^ yh) << 1) | yh;
	return (float(b_lo * 4 + b_hi) + 0.5) / 16.0;
}

// Voronoi com distância real à borda da célula (técnica de Inigo Quilez).
// Retorna: xy = pixel - centro da rocha (unid. de célula), z = distância à borda, w = hash da rocha
vec4 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.2 + 0.6 * hash2(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = 0.2 + 0.6 * hash2(n + g);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec4(-mr, md, hash1(n + mg));
}

vec4 rock_color(float s) {
	if (s < 0.22) return col_dark;
	if (s < 0.42) return col_mid_dark;
	if (s < 0.64) return col_mid;
	if (s < 0.84) return col_light;
	return col_highlight;
}

// Sombreamento de uma rocha abaulada: luz vindo de cima/esquerda, bordas mais escuras
float boulder_shade(vec2 v, float edge01, float h) {
	vec2 L = normalize(vec2(-0.55, -0.85));
	float lit = clamp(dot(v / 0.5, L), -1.0, 1.0);
	float rim = smoothstep(0.0, 1.0, edge01);
	float s = 0.52 + 0.30 * lit * rim;
	s *= mix(0.55, 1.0, rim);
	s += (h - 0.5) * 0.14;
	return s;
}

vec4 compute_cliff_color(vec2 uv) {
	vec2 p = floor(uv * area_size) + 0.5;
	int ix = clamp(int(p.x), 0, int(area_size.x) - 1);
	vec4 a = texelFetch(profile, ivec2(ix, 0), 0);
	vec4 b = texelFetch(profile, ivec2(ix, 1), 0);
	float bottom = a.r;
	float top = a.g;
	float bt = a.b;
	float bw = max(a.a, 1.0);
	float base_smooth = b.r;
	float tt = b.g;
	float tw = max(b.b, 1.0);
	float y = p.y;
	float dith = (bayer4(p) - 0.5) * 0.10;

	// --- Sombra projetada sobre a grama ---
	if (y > bottom) {
		float d = y - bottom;
		if (d < 2.0) {
			return col_shadow;
		} else if (d < shadow_px) {
			return vec4(col_shadow.rgb, col_shadow.a * 0.5);
		} else {
			return vec4(0.0);
		}
	}
	// Contorno inferior
	if (y > bottom - 1.0) {
		return col_outline;
	}

	// --- Rochas arredondadas da base (silhueta recortada) ---
	float bh = clamp(bw * 0.6, 9.0, 18.0);
	float cap = sqrt(max(1.0 - bt * bt, 0.0));
	float boul_top = bottom - bh * (0.45 + 0.55 * cap);
	if (y >= boul_top && y > top + 4.0) {
		float edge_px = (1.0 - abs(bt)) * bw * 0.5;
		if (edge_px < 1.0 || y < boul_top + 1.0) {
			return col_outline;
		}
		float v = (y - boul_top) / max(bottom - boul_top, 1.0);
		vec2 vv = vec2(bt, v * 2.0 - 1.0) * 0.5;
		float e = min(edge_px, min(y - boul_top, bottom - y)) / 5.0;
		float h = hash1(vec2(floor(p.x - (bt + 1.0) * 0.5 * bw + 0.5), 3.0));
		float s = boulder_shade(vv, e, h) - 0.06;
		return rock_color(s + dith);
	}

	// --- Paredão rochoso (face voltada para o sul) ---
	if (y >= top) {
		float depth = y - top;
		if (depth < 1.0) {
			return col_dark;
		}
		// Rachaduras entre as rochas da borda descem um pouco pela face
		float top_edge_px = (1.0 - abs(tt)) * tw * 0.5;
		if (top_edge_px < 1.0 && depth < 5.0) {
			return col_outline;
		}
		float ly = y - base_smooth;
		vec2 scale = vec2(22.0, 15.0);
		vec4 vor = voronoi(vec2(p.x, ly) / scale + vec2(13.7, 41.3));
		float edge_px_face = vor.z * 17.0;
		if (edge_px_face < 1.0) {
			return col_outline;
		}
		float s = boulder_shade(vor.xy, edge_px_face / 5.0, vor.w);
		float t = depth / max(bottom - top, 1.0);
		s -= t * 0.20;
		if (depth < 3.0) s += 0.12;
		return rock_color(s + dith);
	}

	// --- Planalto do topo da montanha ---
	float above = top - y;
	if (above < 1.0) {
		return col_highlight;
	}
	if (above < 2.0) {
		return col_light;
	}
	vec4 vt = voronoi(p / vec2(16.0, 12.0) + vec2(7.1, 2.9));
	float edge_px_top = vt.z * 14.0;
	if (edge_px_top < 1.0) {
		return col_mid_dark;
	}
	float s_top = 0.58 + 0.16 * clamp(dot(vt.xy / 0.5, normalize(vec2(-0.55, -0.85))), -1.0, 1.0) * smoothstep(0.0, 1.0, edge_px_top / 4.0);
	s_top += (vt.w - 0.5) * 0.14;
	s_top -= (1.0 - smoothstep(0.0, 1.0, edge_px_top / 3.0)) * 0.12;
	return rock_color(s_top + dith);
}

void fragment() {
	COLOR = compute_cliff_color(UV);
}
