shader_type canvas_item;
render_mode blend_disabled;
// VARIANTE ISOMÉTRICA de terrain.gdshader (misma lógica; sólo cambia cómo se obtienen las coordenadas de casilla y la dirección de la luz).
// Terreno del mundo dibujado por la GPU a partir de datos de 1 píxel por casilla:
//   data.r  distancia con signo a la costa en casillas (+ tierra, - agua) codificada como s/16 + 0.5
//   data.g  temperatura (0 frío .. 1 calor)    data.b densidad de bosque    data.a roca (montaña)
// El ruido se muestrea de dos texturas sin costura (nz1: manchas grandes, nz2: detalle fino).
// Coste: unas 10 lecturas de textura por píxel; sin sombras ni bucles.

uniform sampler2D data : filter_linear, repeat_disable;
uniform sampler2D nz1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D nz2 : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(192.0, 192.0);
uniform float tile_px = 32.0;
uniform float anim = 1.0;   // 0 = agua quieta (ahorro), 1 = olas y destellos
uniform float tm = 0.0;     // reloj de animación: lo escribe el juego sólo cuando corre (TIME obligaría a dibujar siempre, incluso en pausa)
uniform vec2 iso = vec2(32.0, 16.0);   // medio rombo de casilla en píxeles (ancho/2, alto/2): proyección isométrica 2:1
uniform sampler2D road : filter_linear, repeat_disable;   // 1 píxel por casilla: 1 = camino empedrado
uniform float use_road = 0.0;
uniform float full = 1.0;   // 0 = perfil Ahorro: sin relieve ni sombras de montaña (4 lecturas menos)

varying vec2 wp;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	// VERTEX está en píxeles de pantalla isométrica; se deshace la proyección para obtener coordenadas de casilla
	wp = vec2((VERTEX.x / iso.x + VERTEX.y / iso.y) * 0.5, (VERTEX.y / iso.y - VERTEX.x / iso.x) * 0.5) * tile_px;
}

void fragment() {
	vec2 q = wp / tile_px;                       // coordenadas en casillas
	vec2 uv = q / map_size;
	vec4 d = texture(data, uv);
	float s = (d.r - 0.5) * 16.0;                // + tierra, - agua
	float heat = d.g;
	float forest = d.b;
	float rockh = d.a;

	vec3 a = texture(nz1, q * 0.0125).rgb;       // manchas de ~15 casillas
	vec3 b = texture(nz1, q * 0.05).rgb;         // manchas de ~4 casillas
	vec3 c = texture(nz2, q * 0.2).rgb;          // grano de ~12 px
	vec3 f = texture(nz2, q * 0.9).rgb;          // grano fino

	float t = tm * anim;
	float coast = s + (b.r - 0.5) * 0.70 + (c.g - 0.5) * 0.30;
	vec3 col;

	if (coast < 0.0) {
		// ---------------------------------------------------------------- agua
		float depth = clamp(-coast / 7.0, 0.0, 1.0);
		vec3 shallow = vec3(0.30, 0.72, 0.78);
		vec3 mid = vec3(0.10, 0.43, 0.63);
		vec3 deep = vec3(0.04, 0.17, 0.38);
		col = mix(shallow, mid, smoothstep(0.0, 0.28, depth));
		col = mix(col, deep, smoothstep(0.22, 0.95, depth));
		// fondo arenoso visible en la orilla
		col = mix(col, vec3(0.58, 0.80, 0.72), (1.0 - smoothstep(0.0, 1.5, -coast)) * 0.45);
		// olas: dos capas de ruido que se desplazan en sentidos distintos
		float r1 = texture(nz2, q * 0.17 + vec2(t * 0.010, t * 0.006)).g;
		float r2 = texture(nz2, q * 0.26 + vec2(-t * 0.008, t * 0.011) + 0.37).b;
		col *= 0.86 + 0.28 * (r1 * 0.55 + r2 * 0.45);
		col *= 0.94 + 0.12 * a.b;
		// destellos del sol
		float sp = smoothstep(0.64, 0.78, (r1 + r2) * 0.5);
		col += vec3(0.85, 0.93, 1.0) * sp * 0.16 * (1.0 - depth * 0.5);
		// espuma: línea en la orilla y ondas que se acercan a ella
		float line = smoothstep(-0.34, -0.03, coast);
		float wave = 0.5 + 0.5 * sin(coast * 6.8 - t * 1.5 + b.r * 7.0);
		float band = smoothstep(-1.1, -0.1, coast);
		float foam = clamp(line * 0.9 + band * 0.22 * wave, 0.0, 1.0) * (0.75 + 0.25 * c.r);
		col = mix(col, vec3(0.94, 0.98, 1.0), foam);
	} else {
		// ---------------------------------------------------------------- tierra
		vec3 grass = mix(vec3(0.30, 0.55, 0.17), vec3(0.45, 0.66, 0.21), smoothstep(0.35, 0.65, b.r));
		grass = mix(grass, vec3(0.64, 0.64, 0.27), smoothstep(0.52, 0.78, a.g) * 0.60);   // hierba seca
		grass *= 0.90 + 0.20 * c.r;
		// trazos de hierba: dos capas de ruido estiradas en direcciones distintas, claras y oscuras
		vec3 g1 = texture(nz2, q * vec2(2.6, 1.1) + 0.17).rgb;
		vec3 g2 = texture(nz2, q * vec2(1.2, 3.0) + 0.53).rgb;
		float tuft = smoothstep(0.44, 0.80, g1.g) - smoothstep(0.46, 0.82, g2.b);
		grass *= 1.0 + 0.20 * tuft;
		grass = mix(grass, grass * vec3(1.12, 1.15, 0.78), smoothstep(0.58, 0.88, g1.r) * 0.35);
		grass = mix(grass, vec3(0.46, 0.36, 0.22), smoothstep(0.70, 0.80, a.b + c.b * 0.10) * 0.55);  // tierra
		float hn = heat + (a.g - 0.5) * 0.10 + (f.r - 0.5) * 0.012;   // el ruido fino evita bandas
		float snow_f = 1.0 - smoothstep(0.20, 0.34, hn);
		float desert_f = smoothstep(0.66, 0.78, hn);
		// suelo de bosque más oscuro y musgoso (no en nieve ni desierto)
		grass = mix(grass, vec3(0.12, 0.28, 0.13), forest * 0.80 * (0.8 + 0.4 * b.g));
		vec3 desert = mix(vec3(0.87, 0.74, 0.47), vec3(0.78, 0.62, 0.38), b.r);
		desert *= 0.94 + 0.12 * c.g;
		desert *= 0.93 + 0.10 * (0.5 + 0.5 * sin(q.x * 0.55 + q.y * 0.30 + a.r * 9.0));   // dunas
		vec3 snow = vec3(0.87, 0.92, 0.98) * (0.93 + 0.07 * c.r);
		snow = mix(snow, vec3(0.76, 0.84, 0.93), smoothstep(0.60, 0.85, b.g) * 0.5);
		vec3 land = mix(grass, desert, desert_f);
		land = mix(land, snow, snow_f);
		// playa
		float sandw = 1.0 - smoothstep(0.9, 2.1, coast + (b.g - 0.5) * 1.0);
		vec3 sandc = mix(vec3(0.90, 0.84, 0.60), vec3(0.74, 0.79, 0.84), snow_f);
		sandc = mix(sandc, vec3(0.89, 0.76, 0.50), desert_f * 0.6);
		sandc *= 0.95 + 0.08 * c.g;
		land = mix(land, sandc, sandw);
		land *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.55, coast));   // arena mojada
		// relieve suave: luz desde el noroeste sobre el propio ruido
		vec2 L = vec2(-1.0, 0.0) * 0.16;   // la luz viene de arriba a la izquierda de la pantalla = -x en casillas
		float h0 = a.r * 0.55 + b.r * 0.45;
		if (full > 0.5) {
			float h1 = texture(nz1, (q + L) * 0.0125).r * 0.55 + texture(nz1, (q + L) * 0.05).r * 0.45;
			land *= 1.0 + (h0 - h1) * 4.5 * (1.0 - sandw * 0.6);
		}
		// montañas
		float rh = rockh + (b.g - 0.5) * 0.45 + (c.r - 0.5) * 0.18;
		float rock = smoothstep(0.40, 0.52, rh);
		if (full > 0.5) {
			float occl = smoothstep(0.45, 0.80, texture(data, (q + vec2(-1.3, 0.0)) / map_size).a);
			land *= 1.0 - 0.30 * occl * (1.0 - rock);                   // sombra proyectada al sureste
		}
		if (rock > 0.0) {
			// relieve de montaña: altura = crestas grandes + crestas medias + grano, iluminada desde el noroeste.
			// La luz sale de la diferencia de altura entre dos puntos cercanos (pendiente), así que las laderas al noroeste
			// salen claras y las del sureste oscuras; sólo las cumbres más altas llevan nieve.
			float r1 = 1.0 - abs(2.0 * texture(nz1, q * 0.02).g - 1.0);
			float r2 = 1.0 - abs(2.0 * b.b - 1.0);
			float hm = r1 * 0.55 + r2 * 0.30 + a.r * 0.10 + (c.r - 0.5) * 0.05;
			float hm1 = hm;
			if (full > 0.5) {
				vec2 Lr = L * 1.6;
				hm1 = (1.0 - abs(2.0 * texture(nz1, (q + Lr) * 0.02).g - 1.0)) * 0.55 + (1.0 - abs(2.0 * texture(nz1, (q + Lr) * 0.05).b - 1.0)) * 0.30 + texture(nz1, (q + Lr) * 0.0125).r * 0.10 + (texture(nz2, (q + Lr) * 0.2).r - 0.5) * 0.05;
			}
			float lit = clamp(1.0 + (hm - hm1) * 3.4, 0.58, 1.42);
			float alt = smoothstep(0.20, 0.90, hm);
			vec3 rc = mix(vec3(0.34, 0.30, 0.27), vec3(0.72, 0.66, 0.58), alt);   // roca parda, más clara en las cumbres
			rc = mix(rc, vec3(0.47, 0.45, 0.43), smoothstep(0.35, 0.75, a.g) * 0.35); // vetas de otra roca
			rc *= 0.92 + 0.16 * c.g;
			rc *= lit;
			float cap = smoothstep(0.72, 0.90, hm + (f.g - 0.5) * 0.06);
			float snowy = max(cap * 0.90, snow_f * 0.60);
			rc = mix(rc, vec3(0.94, 0.96, 1.0) * clamp(lit, 0.80, 1.10) * (0.94 + 0.06 * c.r), snowy);
			rc *= 1.0 - 0.38 * (1.0 - smoothstep(0.52, 0.74, rh));       // pie de la montaña, más oscuro
			land = mix(land, rc, rock);
		}
		if (use_road > 0.5) {
			// camino empedrado: máscara de 1 píxel por casilla, borde roto por el ruido; adoquines en hileras desfasadas
			float rd = texture(road, uv).r;
			float em = rd + (b.g - 0.5) * 0.55 + (c.r - 0.5) * 0.40 + (f.g - 0.5) * 0.15;
			float rm = smoothstep(0.40, 0.50, em) * smoothstep(0.0, 0.5, coast);
			vec2 cp = q * 3.4;
			float row = floor(cp.y);
			vec2 cq = vec2(cp.x + 0.5 * mod(row, 2.0), cp.y);
			vec2 id = floor(cq);
			vec2 fc = fract(cq) - 0.5;
			float hs = hash21(id);
			float gap = smoothstep(0.36, 0.47, max(abs(fc.x) * 1.05, abs(fc.y) * 1.30));
			vec3 cob = mix(vec3(0.60, 0.56, 0.50), vec3(0.78, 0.72, 0.62), hs);
			cob *= 0.90 + 0.18 * c.g;
			cob = mix(cob, cob * 0.42, gap);
			cob = mix(cob, land * 0.80, (1.0 - smoothstep(0.50, 0.70, em)) * 0.65);   // el borde se funde con la hierba
			land = mix(land, cob, rm);
		}
		col = land;
	}
	col *= 0.96 + 0.08 * f.r;
	COLOR = vec4(col, 1.0);
}
