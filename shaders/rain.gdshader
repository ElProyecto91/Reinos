shader_type canvas_item;
// Lluvia ligera en pantalla: dos capas de trazos que caen en diagonal. Sólo se dibuja si llueve.

uniform float amount = 0.0;
uniform float tm = 0.0;      // reloj de animación (lo escribe el juego sólo cuando corre)

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float streaks(vec2 uv, float t, float scale, float speed, float slant) {
	vec2 p = uv * scale;
	p.x += p.y * slant;
	p.y += t * speed;
	vec2 id = floor(p);
	vec2 f = fract(p);
	float h = hash(id);
	float on = step(1.0 - 0.30 * amount, h);
	float x = abs(f.x - fract(h * 7.0));
	float line = smoothstep(0.06, 0.0, x);
	float len = smoothstep(0.0, 0.25, f.y) * smoothstep(1.0, 0.55, f.y);
	return on * line * len;
}

void fragment() {
	vec2 uv = vec2(SCREEN_UV.x * (SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x), SCREEN_UV.y);
	float s = clamp(streaks(uv, tm, 34.0, 2.6, 0.22) * 0.9 + streaks(uv, tm, 61.0, 3.6, 0.22) * 0.6, 0.0, 1.0);
	vec3 rgb = mix(vec3(0.05, 0.10, 0.20), vec3(0.86, 0.91, 1.0), s);
	COLOR = vec4(rgb, mix(0.10, 0.55, s) * amount);
}
