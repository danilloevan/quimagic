shader_type canvas_item;
render_mode unshaded;

// Perfil procedural da praia (gerado por BeachRenderer):
//   R = distância assinada à linha d'água em pixels (+ = terra/areia/grama, - = mar)
//   G = largura da faixa de areia em pixels
uniform sampler2D profile : filter_linear, repeat_disable;
uniform vec2 profile_size = vec2(385.0, 281.0);
uniform float sdf_step = 4.0;
uniform vec2 area_origin = vec2(512.0, 416.0);
uniform vec2 area_size = vec2(1536.0, 1120.0);
uniform float seed = 0.0;

// Paleta pixel-art alinhada com terrain_atlas.png e PathTilesetBuilder
uniform vec4 col_grass_lip : source_color = vec4(0.416, 0.729, 0.114, 1.0);
uniform vec4 col_grass_bright : source_color = vec4(0.529, 0.800, 0.180, 1.0);
uniform vec4 col_grass_dark : source_color = vec4(0.275, 0.545, 0.075, 1.0);
uniform vec4 col_grass_shadow : source_color = vec4(0.160, 0.330, 0.040, 0.38);

uniform vec4 col_sand_light : source_color = vec4(1.000, 0.953, 0.745, 1.0);
uniform vec4 col_sand_base : source_color = vec4(0.996, 0.918, 0.647, 1.0);
uniform vec4 col_sand_warm : source_color = vec4(0.945, 0.835, 0.525, 1.0);
uniform vec4 col_sand_wet : source_color = vec4(0.835, 0.690, 0.396, 1.0);
uniform vec4 col_sand_wet_deep : source_color = vec4(0.753, 0.596, 0.322, 1.0);
uniform vec4 col_sand_rim : source_color = vec4(0.714, 0.557, 0.302, 1.0);

uniform vec4 col_shell_light : source_color = vec4(0.996, 0.965, 0.910, 1.0);
uniform vec4 col_shell_coral : source_color = vec4(0.941, 0.620, 0.549, 1.0);
uniform vec4 col_pebble : source_color = vec4(0.765, 0.624, 0.388, 1.0);

uniform vec4 col_foam_bright : source_color = vec4(0.980, 0.996, 1.000, 1.0);
uniform vec4 col_foam_soft : source_color = vec4(0.765, 0.961, 1.000, 1.0);
uniform vec4 col_water_seabed : source_color = vec4(0.569, 0.867, 0.855, 1.0);
uniform vec4 col_water_crystal : source_color = vec4(0.478, 0.890, 0.969, 1.0);
uniform vec4 col_water_shallow : source_color = vec4(0.341, 0.769, 0.945, 1.0);
uniform vec4 col_water_mid : source_color = vec4(0.235, 0.659, 0.878, 1.0);
uniform vec4 col_water_deep : source_color = vec4(0.157, 0.510, 0.769, 1.0);
uniform vec4 col_water_abyss : source_color = vec4(0.122, 0.400, 0.651, 1.0);

// Hash polinomial sem sin() para evitar descontinuidades de precisão na GPU
float hash1(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx + vec3(seed, seed * 1.37, seed * 0.71)) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx + vec3(seed, seed * 1.37, seed * 0.71)) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
	return 0.65 * vnoise(p) + 0.35 * vnoise(p * 2.13 + vec2(17.3, 9.1));
}

// Dithering ordenado 4x4 (Bayer) para transições suaves com estética pixel art
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int b_lo = (((x & 1) ^ (y & 1)) << 1) | (y & 1);
	int xh = (x >> 1) & 1;
	int yh = (y >> 1) & 1;
	int b_hi = ((xh ^ yh) << 1) | yh;
	return (float(b_lo * 4 + b_hi) + 0.5) / 16.0;
}

// Cáusticas leves estilo celular (distância ao ponto mais próximo)
float caustic_val(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 4.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.18 + 0.64 * hash2(n + g);
			vec2 r = g + o - f;
			md = min(md, dot(r, r));
		}
	}
	return sqrt(md);
}

vec4 compute_beach_color(vec2 uv) {
	// Quantização exata ao grid de pixels do mundo (1:1 com tiles e props)
	vec2 p = floor(uv * area_size) + 0.5;
	vec2 wp = area_origin + p;
	vec2 q_uv = (p / sdf_step + 0.5) / profile_size;

	vec2 prof = texture(profile, q_uv).rg;
	float shore_base = prof.r;
	float sand_width = prof.g;

	float dith = bayer4(p) - 0.5;

	// Micro-ondulação estática da linha da praia e da borda da grama
	float shore_jitter = (fbm2(wp * 0.045) - 0.5) * 9.0 + (vnoise(wp * 0.14) - 0.5) * 3.0;
	float shore_dist = shore_base + shore_jitter;

	float grass_jitter = (fbm2(wp * 0.055 + vec2(31.7, 12.4)) - 0.5) * 18.0
		+ (vnoise(wp * 0.22) - 0.5) * 6.0;
	float dist_to_grass = (sand_width + grass_jitter) - shore_dist;

	// Fora da praia (grama pura do GroundLayer)
	if (dist_to_grass < -4.0) {
		return vec4(0.0);
	}

	// =========================================================================
	// 1. TRANSIÇÃO ORGÂNICA GRAMA <-> AREIA
	// =========================================================================
	if (dist_to_grass < 7.0) {
		// Tufinhos de grama saindo sobre a areia
		float blade = vnoise(wp * vec2(0.38, 0.26) + vec2(5.2, 8.8));
		float tuft_reach = dist_to_grass - blade * 4.5;

		if (tuft_reach < -1.2) {
			return vec4(0.0);
		}
		if (tuft_reach < 0.4) {
			return (dith > 0.05 || blade > 0.55) ? col_grass_lip : vec4(0.0);
		}
		if (tuft_reach < 1.8) {
			return (blade > 0.62) ? col_grass_bright : col_grass_dark;
		}
		if (tuft_reach < 3.4) {
			return vec4(col_grass_shadow.rgb, col_grass_shadow.a);
		}
		// Faixa fina de transição terra/areia na raiz da grama
		return (dith > 0.1) ? col_sand_rim : col_sand_warm;
	}

	// =========================================================================
	// 2. DINÂMICA DAS ONDAS NA PRAIA (SWASH INDO E VINDO)
	// =========================================================================
	// Desvio de fase ao longo da enseada para as ondas não baterem todas juntas
	float coast_phase = fbm2(wp * 0.0085) * 2.2 + sin(wp.x * 0.007 - wp.y * 0.006) * 0.55;
	float wave_ang = TIME * 1.40 + coast_phase * 2.1;
	// Onda assimétrica: avança rápido pela areia, recua suavemente
	float swash_norm = 0.5 + 0.5 * sin(wave_ang + 0.35 * sin(wave_ang));
	float receding = -cos(wave_ang); // > 0 quando a onda está recuando
	float swash_reach = swash_norm * 13.0;

	// Profundidade relativa à borda animada da água (+ = água, <= 0 = terra)
	float water_depth = swash_reach - shore_dist;

	// =========================================================================
	// 3. AREIA DA PRAIA (SECA, DUNAS, CONCHINHAS E AREIA MOLHADA)
	// =========================================================================
	if (water_depth <= 0.0) {
		float dry_dist = -water_depth; // distância acima da linha d'água instantânea
		float wet_limit = 18.0 + (fbm2(wp * 0.06 + vec2(9.1, 3.4)) - 0.5) * 7.0;

		// Areia molhada pela maré e pelo recuo da onda
		if (shore_dist < wet_limit) {
			// Brilho fino na borda recém-molhada quando a onda recua
			if (dry_dist < 2.5 && receding > 0.1) {
				return (dith > -0.1) ? col_sand_wet_deep : col_sand_wet;
			}
			float wet_t = clamp((shore_dist - swash_reach) / max(wet_limit - swash_reach, 1.0), 0.0, 1.0);
			if (wet_t < 0.38 + dith * 0.28) {
				return col_sand_wet_deep;
			}
			if (wet_t < 0.85 + dith * 0.32) {
				return col_sand_wet;
			}
			return (dith > 0.15) ? col_sand_warm : col_sand_wet;
		}

		// Pequenos tufos isolados de vegetação perto da borda da grama
		if (dist_to_grass < 18.0) {
			vec2 cell = floor(wp / 10.0);
			vec2 cf = wp - cell * 10.0;
			float ch = hash1(cell * 1.37);
			if (ch > 0.82 && dist_to_grass < 14.0) {
				vec2 center = vec2(3.0, 3.0) + floor(hash2(cell) * 4.0);
				if (abs(cf.x - center.x) <= 1.2 && abs(cf.y - center.y) <= 0.6) {
					return (cf.y < center.y) ? col_grass_bright : col_grass_dark;
				}
			}
		}

		// Ondulações sutis de vento na areia seca
		float ripple = sin(wp.x * 0.075 + wp.y * 0.055 + fbm2(wp * 0.03) * 4.0);
		float grain = hash1(wp);
		float tone = ripple * 0.45 + (fbm2(wp * 0.04) - 0.5) * 0.75 + dith * 0.42;

		// Conchinhas e pedrinhas esparsas na areia seca (longe da água)
		if (shore_dist > wet_limit + 12.0 && dist_to_grass > 11.0) {
			vec2 scell = floor(wp / 18.0);
			float sh = hash1(scell + vec2(41.2, 19.7));
			if (sh > 0.86) {
				vec2 sc = scell * 18.0 + vec2(4.0) + floor(hash2(scell) * 10.0);
				vec2 dsc = wp - sc;
				if (sh > 0.955) {
					// Pequena estrela/concha coral (cruz 3x3)
					if (abs(dsc.x) + abs(dsc.y) <= 1.5) {
						return (length(dsc) < 0.7) ? col_shell_light : col_shell_coral;
					}
				} else if (sh > 0.905) {
					// Conchinha clara (2x2)
					if (dsc.x >= 0.0 && dsc.x < 2.0 && dsc.y >= 0.0 && dsc.y < 2.0) {
						return (dsc.y < 1.0) ? col_shell_light : col_pebble;
					}
				} else {
					// Pedrinha de praia (2x1)
					if (dsc.x >= 0.0 && dsc.x < 2.0 && abs(dsc.y) < 0.6) {
						return col_pebble;
					}
				}
			}
		}

		if (tone > 0.42 || grain > 0.965) {
			return col_sand_light;
		}
		if (tone < -0.32 || grain < 0.035) {
			return col_sand_warm;
		}
		return col_sand_base;
	}

	// =========================================================================
	// 4. ÁGUA DO MAR ANIMADA, ESPUMA DE ONDAS, CÁUSTICAS E BRILHOS
	// =========================================================================
	// Ondulação direcional suave em alto mar + ondulação costeira perto da praia
	float open_swell = sin(dot(wp, vec2(-0.74, -0.67)) * 0.046 + TIME * 1.10 + fbm2(wp * 0.011) * 2.4);
	float coast_swell = sin(water_depth * 0.095 + TIME * 1.40 + coast_phase * 2.1);
	float swell = mix(open_swell, coast_swell, 1.0 - smoothstep(70.0, 160.0, water_depth));
	float eff_depth = water_depth + swell * 5.0 + (fbm2(wp * 0.035 - vec2(TIME * 0.18)) - 0.5) * 10.0;

	// Cor base da água por faixa de profundidade com dithering 4x4
	vec4 water_col;
	float depth_dith = eff_depth + dith * 10.0;
	if (depth_dith < 12.0) {
		water_col = col_water_seabed;
	} else if (depth_dith < 36.0) {
		water_col = col_water_crystal;
	} else if (depth_dith < 92.0) {
		water_col = col_water_shallow;
	} else if (depth_dith < 185.0) {
		water_col = col_water_mid;
	} else if (depth_dith < 300.0) {
		water_col = col_water_deep;
	} else {
		water_col = col_water_abyss;
	}

	// Ondas sutis de mar aberto (sem anéis concêntricos no fundo)
	if (water_depth > 130.0) {
		float deep_band = open_swell + (fbm2(wp * 0.025 + vec2(TIME * 0.12, -TIME * 0.08)) - 0.5) * 0.6;
		if (deep_band > 0.78 + dith * 0.22) {
			water_col = mix(water_col, col_water_shallow, 0.35);
		} else if (deep_band < -0.78 - dith * 0.22) {
			water_col = mix(water_col, col_water_abyss, 0.45);
		}
	}

	// Cáusticas animadas na água rasa e média
	if (water_depth > 4.0 && water_depth < 165.0) {
		vec2 c1 = wp * 0.048 + vec2(TIME * 0.30, TIME * 0.18);
		vec2 c2 = wp * 0.052 + vec2(-TIME * 0.22, TIME * 0.34);
		float caust = min(caustic_val(c1), caustic_val(c2));
		float caust_mask = smoothstep(0.55, 0.72, caust) * (1.0 - smoothstep(105.0, 165.0, water_depth));
		if (caust_mask > 0.32 + dith * 0.25) {
			water_col = mix(water_col, col_water_crystal, 0.55);
			if (caust_mask > 0.58 && water_depth < 75.0) {
				water_col = col_foam_soft;
			}
		}
	}

	// Cristas de ondas quebrando apenas na zona costeira rasa (0..135px da areia)
	float surf_fade = 1.0 - smoothstep(75.0, 138.0, water_depth);
	if (water_depth > 14.0 && surf_fade > 0.02) {
		float wave_travel = water_depth * 0.105 + TIME * 1.40 + coast_phase * 2.1;
		float crest_wave = sin(wave_travel);
		float crest_break = fbm2(wp * 0.032 + vec2(TIME * 0.15, -TIME * 0.12));
		if (crest_wave < -0.78 && crest_break > 0.32 && surf_fade > 0.35) {
			water_col = mix(water_col, col_water_mid, 0.45);
		}
		float crest_thresh = mix(0.92, 0.84, surf_fade);
		if (crest_wave > crest_thresh && crest_break > 0.44) {
			if (water_depth < 64.0 && crest_wave > 0.92 && crest_break > 0.52) {
				water_col = col_foam_bright;
			} else {
				water_col = col_foam_soft;
			}
		}
	}

	// Espuma principal da arrebentação na beira da areia
	float foam_noise = fbm2(wp * 0.11 - vec2(TIME * 0.25, TIME * 0.25));
	float foam_thickness = 2.6 + foam_noise * 3.8 + max(receding, 0.0) * 1.5;
	if (water_depth < foam_thickness) {
		if (water_depth < 1.8 || foam_noise > 0.45) {
			return col_foam_bright;
		}
		return col_foam_soft;
	}

	// Renda de bolhas de espuma atrás da linha da onda (especialmente ao recuar)
	if (water_depth < foam_thickness + 8.5) {
		float lace = vnoise(wp * 0.24 + vec2(TIME * 0.35, -TIME * 0.28));
		float lace_cutoff = mix(0.68, 0.56, clamp(receding * 0.5 + 0.5, 0.0, 1.0));
		if (lace > lace_cutoff + dith * 0.15) {
			return col_foam_soft;
		}
	}

	// Reflexos cintilantes do sol na superfície do mar
	vec2 glint_cell = floor((wp + vec2(TIME * 8.0, TIME * 4.0)) / 6.0);
	float gh = hash1(glint_cell);
	if (gh > 0.965 && water_depth > 20.0) {
		float pulse = sin(TIME * 3.6 + gh * 40.0);
		vec2 gf = (wp + vec2(TIME * 8.0, TIME * 4.0)) - glint_cell * 6.0;
		if (pulse > 0.65 && abs(gf.x - 3.0) < 1.2 && abs(gf.y - 3.0) < 0.7) {
			return (pulse > 0.88) ? col_foam_bright : col_foam_soft;
		}
	}

	return water_col;
}

void fragment() {
	COLOR = compute_beach_color(UV);
}
