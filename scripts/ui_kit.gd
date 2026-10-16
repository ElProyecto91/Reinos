class_name UiButton
extends Control
## Botón táctil dibujado por código: fondo, icono, texto, subtexto, insignia y barra de progreso.

signal pressed

var text: String = ""
var sub: String = ""
var icon: Texture2D = null
var icon_kind: String = ""        # "food", "wood", "gold", "pop"... (icono dibujado)
var enabled: bool = true          # solo aspecto: un botón apagado sigue siendo pulsable
var toggled: bool = false
var badge: String = ""
var progress: float = -1.0
var cost: Dictionary = {}         # {"food":50,...} se dibuja con iconos pequeños
var lack: Dictionary = {}         # recursos que faltan (se dibujan en rojo)
var accent: Color = Color(0.82, 0.64, 0.25)
var font_size: int = 22
var sub_size: int = 17
var action: Callable = Callable()
var _down := false

const BG := Color(0.13, 0.11, 0.09, 0.92)
const BG_DOWN := Color(0.30, 0.24, 0.15, 0.95)
const BG_ON := Color(0.28, 0.22, 0.10, 0.95)

static var _sb_cache: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

static func box(bg: Color, border: Color, radius: int = 9, bw: int = 2) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [bg.to_html(true), border.to_html(true), radius, bw]
	if _sb_cache.has(key):
		return _sb_cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	_sb_cache[key] = sb
	return sb

func set_content(t: String, s: String = "", ic: Texture2D = null, on: bool = true) -> void:
	if t != text or s != sub or ic != icon or on != enabled:
		text = t
		sub = s
		icon = ic
		enabled = on
		queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			_down = true
			queue_redraw()
		else:
			var inside := Rect2(Vector2.ZERO, size).grow(6.0).has_point(mb.position)
			var fire := _down and inside
			_down = false
			queue_redraw()
			if fire:
				pressed.emit()
				if action.is_valid():
					action.call()
		accept_event()

func _draw() -> void:
	var bg := BG_DOWN if _down else (BG_ON if toggled else BG)
	var border := accent if (toggled or _down) else Color(0.55, 0.43, 0.22, 0.95)
	if not enabled:
		border = Color(0.35, 0.3, 0.25, 0.9)
	draw_style_box(box(bg, border), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var fade := 1.0 if enabled else 0.45
	var tcol := Color(0.97, 0.93, 0.82, fade)
	var scol := Color(0.8, 0.74, 0.6, fade)
	var cy := size.y * 0.5
	var has_sub := sub != "" or not cost.is_empty()
	if icon != null or icon_kind != "":
		var isz := minf(size.y - 14.0, size.x - 14.0)
		var show_text := text != "" or has_sub
		if show_text and size.x > size.y * 1.35:
			# icono a la izquierda, texto a la derecha
			var ir := Rect2(8, (size.y - isz) * 0.5, isz, isz)
			_draw_icon(ir, fade)
			var tx := ir.end.x + 8.0
			var tw := size.x - tx - 6.0
			if has_sub:
				draw_string(font, Vector2(tx, cy - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, tw, _fit(font, text, tw, font_size), tcol)
				_draw_sub(font, tx, cy + sub_size + 1.0, tw, false, scol, fade)
			else:
				draw_string(font, Vector2(tx, cy + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, tw, _fit(font, text, tw, font_size), tcol)
		elif show_text:
			# icono arriba, texto abajo
			var ih := size.y - (sub_size + font_size + 8.0 if has_sub else font_size + 10.0)
			ih = clampf(ih, 20.0, size.x - 10.0)
			var ir := Rect2((size.x - ih) * 0.5, 4.0, ih, ih)
			_draw_icon(ir, fade)
			var y := ir.end.y + font_size - 2.0
			draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, _fit(font, text, size.x - 4.0, font_size - 3), tcol)
			if has_sub:
				_draw_sub(font, 0.0, y + sub_size, size.x, true, scol, fade)
		else:
			_draw_icon(Rect2((size.x - isz) * 0.5, (size.y - isz) * 0.5, isz, isz), fade)
	else:
		if has_sub:
			draw_string(font, Vector2(0, cy - 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, _fit(font, text, size.x - 4.0, font_size), tcol)
			_draw_sub(font, 0.0, cy + sub_size + 2.0, size.x, true, scol, fade)
		else:
			draw_string(font, Vector2(0, cy + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, _fit(font, text, size.x - 4.0, font_size), tcol)
	if badge != "":
		var bw := maxf(26.0, 12.0 + badge.length() * 11.0)
		var br := Rect2(size.x - bw - 3.0, 3.0, bw, 24.0)
		draw_style_box(box(Color(0.75, 0.2, 0.15, 0.95), Color(1, 1, 1, 0.8), 12, 1), br)
		draw_string(font, Vector2(br.position.x, br.position.y + 18.0), badge, HORIZONTAL_ALIGNMENT_CENTER, bw, 18, Color.WHITE)
	if progress >= 0.0:
		var pr := Rect2(5, size.y - 9, size.x - 10, 5)
		draw_rect(pr, Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * clampf(progress, 0.0, 1.0), pr.size.y)), Color(0.45, 0.8, 1.0), true)

## Tamaño de letra reducido hasta que el texto quepa en `w` píxeles (mínimo 11).
func _fit(font: Font, s: String, w: float, fs: int) -> int:
	var f := fs
	while f > 11 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > w:
		f -= 1
	return f

func _draw_sub(font: Font, x: float, y: float, w: float, center: bool, col: Color, fade: float) -> void:
	if cost.is_empty():
		draw_string(font, Vector2(x, y), sub, HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT, w, sub_size - (2 if center else 0), col)
		return
	var fs := 15
	var items: Array = []
	var total := 0.0
	for k in ["food", "wood", "gold", "stone"]:
		if cost.has(k) and int(cost[k]) > 0:
			var txt := str(int(cost[k]))
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			items.append([k, txt, tw])
			total += 14.0 + tw + 3.0
	var cx := x + (w - total) * 0.5 if center else x
	for it in items:
		UiButton.draw_symbol(self, it[0], Rect2(cx, y - 12.0, 13, 13), fade)
		var bad := lack.has(it[0])
		draw_string(font, Vector2(cx + 14.0, y), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.45, 0.4, fade) if bad else Color(0.95, 0.92, 0.8, fade))
		cx += 14.0 + float(it[2]) + 3.0

func _draw_icon(r: Rect2, fade: float) -> void:
	if icon != null:
		draw_texture_rect(icon, r, false, Color(1, 1, 1, fade))
	elif icon_kind != "":
		UiButton.draw_symbol(self, icon_kind, r, fade)

static func draw_symbol(c: CanvasItem, kind: String, r: Rect2, a: float = 1.0) -> void:
	## Iconos de recursos y símbolos dibujados con primitivas.
	var m := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match kind:
		"food":
			c.draw_circle(m + Vector2(0, s * 0.06), s * 0.36, Color(0.82, 0.15, 0.15, a))
			c.draw_circle(m + Vector2(-s * 0.1, -s * 0.04), s * 0.1, Color(1, 0.7, 0.7, a * 0.7))
			c.draw_line(m + Vector2(0, -s * 0.28), m + Vector2(s * 0.08, -s * 0.44), Color(0.35, 0.22, 0.1, a), maxf(2.0, s * 0.07))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.06, -s * 0.4), m + Vector2(s * 0.3, -s * 0.46), m + Vector2(s * 0.16, -s * 0.28)]), Color(0.3, 0.7, 0.25, a))
		"wood":
			for i in 3:
				var y := m.y - s * 0.22 + i * s * 0.2
				c.draw_rect(Rect2(m.x - s * 0.4, y, s * 0.8, s * 0.17), Color(0.5, 0.3, 0.14, a), true)
				c.draw_circle(Vector2(m.x + s * 0.4, y + s * 0.085), s * 0.085, Color(0.85, 0.65, 0.38, a))
		"gold":
			c.draw_circle(m, s * 0.4, Color(0.95, 0.75, 0.12, a))
			c.draw_circle(m, s * 0.4, Color(0.7, 0.5, 0.05, a * 0.0))
			c.draw_arc(m, s * 0.4, 0, TAU, 20, Color(0.65, 0.45, 0.05, a), maxf(2.0, s * 0.07))
			c.draw_circle(m + Vector2(-s * 0.1, -s * 0.1), s * 0.1, Color(1, 0.95, 0.6, a * 0.8))
		"stone":
			var sc := Color(0.62, 0.65, 0.70, a)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.42, s * 0.34), m + Vector2(-s * 0.34, -s * 0.06), m + Vector2(-s * 0.08, -s * 0.30), m + Vector2(s * 0.22, -s * 0.22), m + Vector2(s * 0.42, s * 0.08), m + Vector2(s * 0.38, s * 0.34)]), sc)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.34, -s * 0.06), m + Vector2(-s * 0.08, -s * 0.30), m + Vector2(s * 0.04, -s * 0.02), m + Vector2(-s * 0.20, s * 0.10)]), Color(0.82, 0.85, 0.90, a))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.04, -s * 0.02), m + Vector2(s * 0.22, -s * 0.22), m + Vector2(s * 0.42, s * 0.08), m + Vector2(s * 0.38, s * 0.34), m + Vector2(s * 0.10, s * 0.34)]), Color(0.46, 0.49, 0.55, a))
			c.draw_line(m + Vector2(-s * 0.2, s * 0.1), m + Vector2(-s * 0.1, s * 0.34), Color(0.2, 0.22, 0.26, a * 0.8), maxf(1.5, s * 0.05))
		"tech":
			# pergamino con un yunque: mejoras
			c.draw_rect(Rect2(m.x - s * 0.30, m.y - s * 0.36, s * 0.60, s * 0.72), Color(0.92, 0.84, 0.62, a), true)
			c.draw_rect(Rect2(m.x - s * 0.34, m.y - s * 0.40, s * 0.68, s * 0.10), Color(0.62, 0.42, 0.20, a), true)
			c.draw_rect(Rect2(m.x - s * 0.34, m.y + s * 0.30, s * 0.68, s * 0.10), Color(0.62, 0.42, 0.20, a), true)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -s * 0.22), m + Vector2(s * 0.17, -s * 0.0), m + Vector2(s * 0.06, -s * 0.0), m + Vector2(s * 0.06, s * 0.2), m + Vector2(-s * 0.06, s * 0.2), m + Vector2(-s * 0.06, -s * 0.0), m + Vector2(-s * 0.17, -s * 0.0)]), Color(0.25, 0.65, 0.30, a))
		"stance":
			# escudo
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.32, -s * 0.34), m + Vector2(s * 0.32, -s * 0.34), m + Vector2(s * 0.32, s * 0.06), m + Vector2(0, s * 0.42), m + Vector2(-s * 0.32, s * 0.06)]), Color(0.70, 0.74, 0.82, a))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.24, -s * 0.26), m + Vector2(s * 0.24, -s * 0.26), m + Vector2(s * 0.24, s * 0.03), m + Vector2(0, s * 0.32), m + Vector2(-s * 0.24, s * 0.03)]), Color(0.25, 0.40, 0.72, a))
			c.draw_line(m + Vector2(0, -s * 0.22), m + Vector2(0, s * 0.26), Color(0.95, 0.85, 0.40, a), maxf(2.0, s * 0.07))
			c.draw_line(m + Vector2(-s * 0.2, -s * 0.06), m + Vector2(s * 0.2, -s * 0.06), Color(0.95, 0.85, 0.40, a), maxf(2.0, s * 0.07))
		"formation":
			for row in 3:
				for col in 4:
					var px := m.x - s * 0.33 + col * s * 0.22
					var py := m.y - s * 0.28 + row * s * 0.28
					c.draw_circle(Vector2(px, py), s * 0.075, Color(0.45, 0.65, 0.95, a) if row == 0 else Color(0.95, 0.80, 0.35, a))
		"bell":
			var bg := Color(0.95, 0.78, 0.25, a)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.08, -s * 0.38), m + Vector2(s * 0.08, -s * 0.38), m + Vector2(s * 0.16, -s * 0.22), m + Vector2(s * 0.30, s * 0.18), m + Vector2(s * 0.40, s * 0.26), m + Vector2(-s * 0.40, s * 0.26), m + Vector2(-s * 0.30, s * 0.18), m + Vector2(-s * 0.16, -s * 0.22)]), bg)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.04, -s * 0.30), m + Vector2(s * 0.0, -s * 0.30), m + Vector2(s * 0.08, -s * 0.12), m + Vector2(s * 0.18, s * 0.2), m + Vector2(-s * 0.12, s * 0.2), m + Vector2(-s * 0.12, -s * 0.1)]), Color(1.0, 0.92, 0.55, a * 0.7))
			c.draw_circle(m + Vector2(0, s * 0.36), s * 0.08, Color(0.45, 0.30, 0.12, a))
			c.draw_arc(m + Vector2(s * 0.34, -s * 0.12), s * 0.14, -1.0, 1.0, 8, Color(1, 0.9, 0.5, a), maxf(2.0, s * 0.06))
			c.draw_arc(m + Vector2(-s * 0.34, -s * 0.12), s * 0.14, PI - 1.0, PI + 1.0, 8, Color(1, 0.9, 0.5, a), maxf(2.0, s * 0.06))
		"garrison":
			# torre con puerta y flecha hacia dentro
			c.draw_rect(Rect2(m.x - s * 0.26, m.y - s * 0.18, s * 0.52, s * 0.56), Color(0.70, 0.66, 0.60, a), true)
			for i in 3:
				c.draw_rect(Rect2(m.x - s * 0.26 + i * s * 0.2, m.y - s * 0.32, s * 0.12, s * 0.14), Color(0.70, 0.66, 0.60, a), true)
			c.draw_rect(Rect2(m.x - s * 0.08, m.y + s * 0.12, s * 0.16, s * 0.26), Color(0.30, 0.20, 0.10, a), true)
			c.draw_line(m + Vector2(-s * 0.46, s * 0.26), m + Vector2(-s * 0.18, s * 0.26), Color(0.4, 1, 0.5, a), maxf(2.5, s * 0.08))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.18, s * 0.16), m + Vector2(-s * 0.06, s * 0.26), m + Vector2(-s * 0.18, s * 0.36)]), Color(0.4, 1, 0.5, a))
		"exit":
			c.draw_rect(Rect2(m.x - s * 0.30, m.y - s * 0.34, s * 0.34, s * 0.68), Color(0.70, 0.66, 0.60, a), true)
			c.draw_line(m + Vector2(-s * 0.02, 0), m + Vector2(s * 0.36, 0), Color(1.0, 0.85, 0.4, a), maxf(2.5, s * 0.08))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.36, -s * 0.12), m + Vector2(s * 0.48, 0), m + Vector2(s * 0.36, s * 0.12)]), Color(1.0, 0.85, 0.4, a))
		"pop":
			c.draw_circle(m + Vector2(0, -s * 0.2), s * 0.17, Color(0.92, 0.78, 0.6, a))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.26, s * 0.38), m + Vector2(-s * 0.2, -s * 0.02), m + Vector2(s * 0.2, -s * 0.02), m + Vector2(s * 0.26, s * 0.38)]), Color(0.75, 0.75, 0.85, a))
		"idle":
			c.draw_circle(m + Vector2(0, -s * 0.2), s * 0.15, Color(0.92, 0.78, 0.6, a))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.22, s * 0.34), m + Vector2(-s * 0.17, -s * 0.04), m + Vector2(s * 0.17, -s * 0.04), m + Vector2(s * 0.22, s * 0.34)]), Color(0.45, 0.65, 0.95, a))
			c.draw_arc(m + Vector2(s * 0.22, -s * 0.3), s * 0.12, 0, TAU, 12, Color(1, 0.9, 0.3, a), 2.5)
		"army":
			c.draw_line(m + Vector2(-s * 0.3, s * 0.35), m + Vector2(s * 0.25, -s * 0.38), Color(0.85, 0.87, 0.9, a), maxf(3.0, s * 0.09))
			c.draw_line(m + Vector2(s * 0.3, s * 0.35), m + Vector2(-s * 0.25, -s * 0.38), Color(0.85, 0.87, 0.9, a), maxf(3.0, s * 0.09))
			c.draw_line(m + Vector2(-s * 0.33, s * 0.2), m + Vector2(-s * 0.1, s * 0.4), Color(0.6, 0.4, 0.15, a), maxf(3.0, s * 0.08))
			c.draw_line(m + Vector2(s * 0.33, s * 0.2), m + Vector2(s * 0.1, s * 0.4), Color(0.6, 0.4, 0.15, a), maxf(3.0, s * 0.08))
		"base":
			c.draw_rect(Rect2(m.x - s * 0.34, m.y - s * 0.05, s * 0.68, s * 0.4), Color(0.75, 0.7, 0.62, a), true)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.42, -s * 0.05), m + Vector2(0, -s * 0.4), m + Vector2(s * 0.42, -s * 0.05)]), Color(0.7, 0.3, 0.2, a))
			c.draw_rect(Rect2(m.x - s * 0.07, m.y + s * 0.12, s * 0.14, s * 0.23), Color(0.3, 0.2, 0.1, a), true)
		"select":
			var col := Color(0.4, 1, 0.5, a)
			var w := maxf(2.5, s * 0.07)
			var q := s * 0.32
			c.draw_rect(Rect2(m - Vector2(q, q), Vector2(q, q) * 2.0), Color(0.4, 1, 0.5, a * 0.15), true)
			c.draw_line(m + Vector2(-q, -q), m + Vector2(-q, -q * 0.3), col, w)
			c.draw_line(m + Vector2(-q, -q), m + Vector2(-q * 0.3, -q), col, w)
			c.draw_line(m + Vector2(q, -q), m + Vector2(q, -q * 0.3), col, w)
			c.draw_line(m + Vector2(q, -q), m + Vector2(q * 0.3, -q), col, w)
			c.draw_line(m + Vector2(-q, q), m + Vector2(-q, q * 0.3), col, w)
			c.draw_line(m + Vector2(-q, q), m + Vector2(-q * 0.3, q), col, w)
			c.draw_line(m + Vector2(q, q), m + Vector2(q, q * 0.3), col, w)
			c.draw_line(m + Vector2(q, q), m + Vector2(q * 0.3, q), col, w)
		"menu":
			for i in 3:
				c.draw_rect(Rect2(m.x - s * 0.3, m.y - s * 0.27 + i * s * 0.27, s * 0.6, s * 0.1), Color(0.95, 0.9, 0.8, a), true)
		"hammer":
			c.draw_line(m + Vector2(-s * 0.3, s * 0.35), m + Vector2(s * 0.12, -s * 0.12), Color(0.55, 0.36, 0.16, a), maxf(3.0, s * 0.1))
			c.draw_rect(Rect2(m.x - s * 0.02, m.y - s * 0.4, s * 0.42, s * 0.24), Color(0.7, 0.72, 0.78, a), true)
		"stop":
			c.draw_rect(Rect2(m - Vector2(s, s) * 0.28, Vector2(s, s) * 0.56), Color(0.85, 0.3, 0.25, a), true)
		"sword":
			c.draw_line(m + Vector2(-s * 0.32, s * 0.32), m + Vector2(s * 0.3, -s * 0.34), Color(0.88, 0.9, 0.95, a), maxf(3.0, s * 0.1))
			c.draw_line(m + Vector2(-s * 0.3, s * 0.05), m + Vector2(-s * 0.05, s * 0.3), Color(0.7, 0.5, 0.15, a), maxf(3.0, s * 0.09))
		"flag":
			c.draw_line(m + Vector2(-s * 0.2, s * 0.4), m + Vector2(-s * 0.2, -s * 0.4), Color(0.4, 0.28, 0.14, a), maxf(3.0, s * 0.08))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.2, -s * 0.4), m + Vector2(s * 0.35, -s * 0.2), m + Vector2(-s * 0.2, 0.0)]), Color(0.9, 0.25, 0.2, a))
		"trash":
			c.draw_rect(Rect2(m.x - s * 0.25, m.y - s * 0.15, s * 0.5, s * 0.5), Color(0.75, 0.3, 0.25, a), true)
			c.draw_rect(Rect2(m.x - s * 0.33, m.y - s * 0.28, s * 0.66, s * 0.1), Color(0.85, 0.85, 0.85, a), true)
		"age":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -s * 0.4), m + Vector2(s * 0.34, s * 0.02), m + Vector2(s * 0.12, s * 0.02), m + Vector2(s * 0.12, s * 0.38), m + Vector2(-s * 0.12, s * 0.38), m + Vector2(-s * 0.12, s * 0.02), m + Vector2(-s * 0.34, s * 0.02)]), Color(0.95, 0.85, 0.3, a))
		"farm":
			c.draw_rect(Rect2(m - Vector2(s, s) * 0.38, Vector2(s, s) * 0.76), Color(0.42, 0.28, 0.14, a), true)
			for i in 4:
				c.draw_line(Vector2(m.x - s * 0.3, m.y - s * 0.26 + i * s * 0.17), Vector2(m.x + s * 0.3, m.y - s * 0.26 + i * s * 0.17), Color(0.6, 0.78, 0.25, a), maxf(2.5, s * 0.08))
		"sapling":
			# retoño: tallo, dos hojas y montoncito de tierra
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.36, s * 0.38), m + Vector2(-s * 0.26, s * 0.24), m + Vector2(s * 0.26, s * 0.24), m + Vector2(s * 0.36, s * 0.38)]), Color(0.45, 0.30, 0.15, a))
			c.draw_line(m + Vector2(0, s * 0.28), m + Vector2(0, -s * 0.06), Color(0.45, 0.32, 0.16, a), maxf(2.5, s * 0.08))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -s * 0.04), m + Vector2(-s * 0.36, -s * 0.12), m + Vector2(-s * 0.26, -s * 0.34), m + Vector2(-s * 0.02, -s * 0.2)]), Color(0.35, 0.72, 0.28, a))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -s * 0.12), m + Vector2(s * 0.36, -s * 0.2), m + Vector2(s * 0.26, -s * 0.44), m + Vector2(s * 0.02, -s * 0.3)]), Color(0.5, 0.82, 0.32, a))
		"resources":
			# pico sobre una pepita de oro
			c.draw_circle(m + Vector2(s * 0.1, s * 0.22), s * 0.2, Color(0.95, 0.75, 0.12, a))
			c.draw_circle(m + Vector2(s * 0.04, s * 0.15), s * 0.06, Color(1, 0.96, 0.62, a * 0.9))
			c.draw_line(m + Vector2(-s * 0.24, s * 0.38), m + Vector2(s * 0.14, -s * 0.30), Color(0.55, 0.36, 0.16, a), maxf(3.0, s * 0.09))
			c.draw_arc(m + Vector2(s * 0.12, -s * 0.18), s * 0.30, PI * 1.12, PI * 1.9, 10, Color(0.78, 0.8, 0.86, a), maxf(3.0, s * 0.10))
		"back":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.32, 0), m + Vector2(s * 0.05, -s * 0.32), m + Vector2(s * 0.05, -s * 0.12), m + Vector2(s * 0.34, -s * 0.12), m + Vector2(s * 0.34, s * 0.12), m + Vector2(s * 0.05, s * 0.12), m + Vector2(s * 0.05, s * 0.32)]), Color(0.95, 0.9, 0.8, a))
		"anchor":
			var ac := Color(0.82, 0.88, 0.95, a)
			var aw := maxf(3.0, s * 0.09)
			c.draw_arc(m + Vector2(0, -s * 0.32), s * 0.08, 0, TAU, 12, ac, aw * 0.7)
			c.draw_line(m + Vector2(0, -s * 0.24), m + Vector2(0, s * 0.34), ac, aw)
			c.draw_line(m + Vector2(-s * 0.18, -s * 0.1), m + Vector2(s * 0.18, -s * 0.1), ac, aw)
			c.draw_arc(m + Vector2(0, s * 0.1), s * 0.3, 0.15, PI - 0.15, 14, ac, aw)
		"explore":
			var ec := Color(0.80, 0.90, 1.0, a)
			c.draw_arc(m, s * 0.34, 0, TAU, 20, ec, maxf(2.5, s * 0.07))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -s * 0.27), m + Vector2(s * 0.09, 0), m + Vector2(-s * 0.09, 0)]), Color(0.95, 0.35, 0.3, a))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, s * 0.27), m + Vector2(s * 0.09, 0), m + Vector2(-s * 0.09, 0)]), Color(0.88, 0.9, 0.95, a))
			c.draw_circle(m, s * 0.04, Color(0.2, 0.2, 0.25, a))
		"abil":
			# estrella de seis puntas: habilidad de civilización
			var gold := Color(1.0, 0.82, 0.30, a)
			for i in 6:
				var an := float(i) * TAU / 6.0 - PI * 0.5
				var an2 := an + TAU / 12.0
				c.draw_colored_polygon(PackedVector2Array([m + Vector2(cos(an - TAU / 12.0), sin(an - TAU / 12.0)) * s * 0.12, m + Vector2(cos(an), sin(an)) * s * 0.40, m + Vector2(cos(an2), sin(an2)) * s * 0.12]), gold)
			c.draw_circle(m, s * 0.16, Color(1.0, 0.95, 0.65, a))
		"ok":
			c.draw_line(m + Vector2(-s * 0.3, 0.0), m + Vector2(-s * 0.08, s * 0.24), Color(0.4, 1, 0.5, a), maxf(4.0, s * 0.12))
			c.draw_line(m + Vector2(-s * 0.08, s * 0.24), m + Vector2(s * 0.32, -s * 0.28), Color(0.4, 1, 0.5, a), maxf(4.0, s * 0.12))
		"cancel":
			c.draw_line(m + Vector2(-s * 0.26, -s * 0.26), m + Vector2(s * 0.26, s * 0.26), Color(1, 0.45, 0.4, a), maxf(4.0, s * 0.12))
			c.draw_line(m + Vector2(s * 0.26, -s * 0.26), m + Vector2(-s * 0.26, s * 0.26), Color(1, 0.45, 0.4, a), maxf(4.0, s * 0.12))
