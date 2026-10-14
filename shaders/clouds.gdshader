shader_type canvas_item;
// Sombras de nubes que se desplazan despacio sobre todo el mundo (suelo, árboles, unidades).
// Dos lecturas de ruido y nada más. `cover` sube con el cielo cubierto.

uniform sampler2D nz1 : filter_linear_mipmap, repeat_enable;
uniform float tile_px = 32.0;
uniform float cover = 0.0;

varying vec2 wp;

void vertex() {
	wp = VERTEX;
}

void fragment() {
	vec2 q = wp / tile_px;
	float t = TIME;
	float c1 = texture(nz1, q * 0.010 + vec2(t * 0.0022, t * 0.0011)).r;
	float c2 = texture(nz1, q * 0.023 + vec2(-t * 0.0016, t * 0.0019) + 0.5).g;
	float c = c1 * 0.6 + c2 * 0.4;
	float a = smoothstep(0.56 - cover * 0.22, 0.80 - cover * 0.18, c);
	COLOR = vec4(0.0, 0.02, 0.07, a * (0.20 + 0.16 * cover));
}
