shader_type canvas_item;
// Sprite isométrico con color de equipo y ventanas que brillan de noche. `mask_tex` (RG8, mismo reparto que el atlas):
// R vale 1 en las partes que se tiñen con el color del equipo, G en el cristal de las ventanas.
// El color del equipo llega por `modulate` (COLOR); un sprite sin máscara y con modulate blanco se dibuja tal cual.
// El atlas se hornea con las partes de equipo en gris 0.75, de ahí el 1/0.75.
// `glow` (0 día .. 1 noche) y `glow_col` (ya compensado por el tinte nocturno del lienzo) los pone el juego.
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform float glow = 0.0;
uniform vec3 glow_col = vec3(1.0, 0.78, 0.38);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 m = texture(mask_tex, UV).rg;
	vec3 tint = mix(vec3(1.0), COLOR.rgb * 1.3333, m.x);
	vec3 rgb = c.rgb * tint;
	rgb = mix(rgb, glow_col, m.y * glow);
	// la modulación de los sprites sin equipo (blanca) no cambia nada; el alfa sí se aplica (fantasmas, construcción)
	COLOR = vec4(rgb, c.a * COLOR.a);
}
