class_name MenuIcon
extends Control
## Ícones vetoriais do menu, desenhados em código (sem imagens externas):
## pessoa, grupo, entrar, engrenagem, desligar, ajustes e bandeiras de idioma.

@export var kind := "person"
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


static func make(icon_kind: String, icon_size: float, icon_color: Color = Color.WHITE) -> MenuIcon:
	var icon := MenuIcon.new()
	icon.kind = icon_kind
	icon.color = icon_color
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size = icon.custom_minimum_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2.ONE * s) / 2.0
	match kind:
		"person":
			_person(o + Vector2(s * 0.5, 0), s, 1.0)
		"group":
			_person(o + Vector2(s * 0.28, s * 0.08), s, 0.72, Color(color, 0.55))
			_person(o + Vector2(s * 0.72, s * 0.08), s, 0.72, Color(color, 0.55))
			_person(o + Vector2(s * 0.5, 0), s, 0.92)
		"join":
			_join(o, s)
		"gear":
			_gear(o + Vector2.ONE * s / 2.0, s)
		"power":
			_power(o + Vector2.ONE * s / 2.0, s)
		"sliders":
			_sliders(o, s)
		"play":
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(s * 0.26, s * 0.14), o + Vector2(s * 0.86, s * 0.5), o + Vector2(s * 0.26, s * 0.86)]), color)
		"flag_pt_BR":
			_flag_br(Rect2(o + Vector2(0, s * 0.15), Vector2(s, s * 0.7)))
		"flag_en":
			_flag_us(Rect2(o + Vector2(0, s * 0.15), Vector2(s, s * 0.7)))


func _person(top: Vector2, s: float, scale_factor: float, tint: Color = color) -> void:
	var k := s * scale_factor
	var head := top + Vector2(0, s * 0.14 + k * 0.2)
	draw_circle(head, k * 0.17, tint)
	var shoulders := head + Vector2(0, k * 0.27)
	var body := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * float(i) / 12.0
		body.append(shoulders + Vector2(cos(angle) * k * 0.3, sin(angle) * k * 0.2) + Vector2(0, k * 0.2))
	body.append(shoulders + Vector2(k * 0.3, k * 0.42))
	body.append(shoulders + Vector2(-k * 0.3, k * 0.42))
	draw_colored_polygon(body, tint)


func _join(o: Vector2, s: float) -> void:
	var w := s * 0.085
	# Porta (moldura aberta à esquerda).
	var door := PackedVector2Array([
		o + Vector2(s * 0.5, s * 0.14), o + Vector2(s * 0.84, s * 0.14),
		o + Vector2(s * 0.84, s * 0.86), o + Vector2(s * 0.5, s * 0.86)])
	draw_polyline(door, color, w, true)
	# Seta entrando.
	var y := s * 0.5
	draw_line(o + Vector2(s * 0.1, y), o + Vector2(s * 0.6, y), color, w, true)
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(s * 0.68, y), o + Vector2(s * 0.48, y - s * 0.17), o + Vector2(s * 0.48, y + s * 0.17)]), color)


func _gear(c: Vector2, s: float) -> void:
	var points := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		var angle := TAU * float(i) / float(teeth * 4)
		var outer := (i % 4) < 2
		points.append(c + Vector2(cos(angle), sin(angle)) * s * (0.46 if outer else 0.34))
	draw_colored_polygon(points, color)
	draw_circle(c, s * 0.14, Color(0.07, 0.09, 0.12))


func _power(c: Vector2, s: float) -> void:
	var w := s * 0.1
	draw_arc(c + Vector2(0, s * 0.04), s * 0.34, -PI * 0.32, PI * 1.32, 32, color, w, true)
	draw_line(c + Vector2(0, -s * 0.44), c + Vector2(0, -s * 0.02), color, w, true)


func _sliders(o: Vector2, s: float) -> void:
	var w := s * 0.07
	for row: Array in [[0.25, 0.65], [0.5, 0.3], [0.75, 0.55]]:
		var y := s * float(row[0])
		draw_line(o + Vector2(s * 0.1, y), o + Vector2(s * 0.9, y), Color(color, 0.6), w, true)
		draw_circle(o + Vector2(s * float(row[1]), y), s * 0.1, color)


func _flag_br(r: Rect2) -> void:
	draw_rect(r, Color(0.0, 0.61, 0.23))
	var c := r.get_center()
	draw_colored_polygon(PackedVector2Array([
		Vector2(r.position.x + r.size.x * 0.08, c.y), Vector2(c.x, r.position.y + r.size.y * 0.1),
		Vector2(r.end.x - r.size.x * 0.08, c.y), Vector2(c.x, r.end.y - r.size.y * 0.1)]), Color(1.0, 0.87, 0.0))
	var radius := r.size.y * 0.26
	draw_circle(c, radius, Color(0.0, 0.15, 0.46))
	draw_arc(c + Vector2(0, radius * 1.6), radius * 1.75, -PI * 0.68, -PI * 0.32, 16, Color.WHITE, maxf(1.0, r.size.y * 0.05), true)


func _flag_us(r: Rect2) -> void:
	var stripe := r.size.y / 13.0
	for i in 13:
		draw_rect(Rect2(r.position + Vector2(0, stripe * i), Vector2(r.size.x, stripe + 0.5)),
			Color(0.75, 0.1, 0.18) if i % 2 == 0 else Color.WHITE)
	var canton := Rect2(r.position, Vector2(r.size.x * 0.42, stripe * 7))
	draw_rect(canton, Color(0.14, 0.2, 0.42))
	for row in 4:
		for col in 5:
			var p := canton.position + Vector2((col + 0.5 + (row % 2) * 0.0) * canton.size.x / 5.0, (row + 0.5) * canton.size.y / 4.0)
			draw_circle(p, maxf(0.6, canton.size.y * 0.06), Color.WHITE)
