shader_type canvas_item;
// Sprite isométrico con color de equipo: `mask_tex` (R8, mismo reparto que el atlas) vale 1 en las partes que se tiñen.
// El color del equipo llega por `modulate` (COLOR); un sprite sin máscara y con modulate blanco se dibuja tal cual.
// El atlas se hornea con las partes de equipo en gris 0.75, de ahí el 1/0.75.
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(mask_tex, UV).r;
	vec3 tint = mix(vec3(1.0), COLOR.rgb * 1.3333, m);
	// la modulación de los sprites sin equipo (blanca) no cambia nada; el alfa sí se aplica (fantasmas, construcción)
	COLOR = vec4(c.rgb * tint, c.a * COLOR.a);
}
