## A speedometer-style gauge dial drawn entirely via _draw().
## Attach to a Control node in the scene tree.
class_name GaugeDial
extends Control

## Current value of the gauge (0 – 100).
@export var gauge_value: float = 100.0
## Label printed below the dial (e.g. "HULL TEMP").
@export var gauge_label: String = "GAUGE"
## Primary arc colour when healthy.
@export var gauge_color: Color = Color(0.2, 0.8, 0.4)
## Value at or below which the gauge enters danger mode.
@export var danger_threshold: float = 25.0

## ── Internal drawing constants ──────────────────────────────────────────
## The arc sweeps from _start_angle to _end_angle (radians, 0 = right).
## 210° → 330° gives a classic bottom-open speedometer look.
var _start_angle_deg: float = 225.0
var _end_angle_deg: float = -45.0  # wraps clockwise

var _displayed_value: float = 100.0   # smoothed via lerp
var _danger_pulse: float = 0.0        # 0-1 oscillator for danger glow

## Smooth the needle movement every frame and trigger redraws.
func _process(delta: float) -> void:
	_displayed_value = lerp(_displayed_value, gauge_value, delta * 8.0)

	# Danger pulse oscillator (sine wave, ~2 Hz)
	if _displayed_value <= danger_threshold:
		_danger_pulse = (sin(Time.get_ticks_msec() / 250.0) + 1.0) / 2.0
	else:
		_danger_pulse = 0.0

	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius: float = min(size.x, size.y) * 0.42
	# Reserve a bit of room at the bottom for the label
	center.y -= 6.0

	_draw_bezel(center, radius)
	_draw_face(center, radius)
	_draw_tick_marks(center, radius)
	_draw_arc_fill(center, radius)
	_draw_needle(center, radius)
	_draw_center_cap(center)
	_draw_label(center, radius)
	_draw_value_text(center, radius)


## ── Bezel (outer metallic ring) ──────────────────────────────────────────
func _draw_bezel(center: Vector2, radius: float) -> void:
	# Outer ring
	draw_arc(center, radius + 6, 0, TAU, 64, Color(0.35, 0.38, 0.42, 0.9), 4.0, true)
	# Inner shadow ring
	draw_arc(center, radius + 2, 0, TAU, 64, Color(0.15, 0.15, 0.18, 0.7), 2.0, true)


## ── Face (dark background disc) ──────────────────────────────────────────
func _draw_face(center: Vector2, radius: float) -> void:
	# Filled dark circle for gauge face
	draw_circle(center, radius, Color(0.08, 0.09, 0.12, 0.92))
	# Subtle inner edge highlight
	draw_arc(center, radius - 1, 0, TAU, 64, Color(0.25, 0.27, 0.3, 0.3), 1.0, true)


## ── Tick marks ───────────────────────────────────────────────────────────
func _draw_tick_marks(center: Vector2, radius: float) -> void:
	var start_rad := deg_to_rad(_start_angle_deg)
	var end_rad := deg_to_rad(_end_angle_deg)
	var sweep := end_rad - start_rad
	if sweep > 0:
		sweep -= TAU  # ensure clockwise sweep

	var major_ticks := 10
	var minor_per_major := 4

	for i in range(major_ticks + 1):
		var t := float(i) / float(major_ticks)
		var angle := start_rad + sweep * t

		# Major tick
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 4)
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - 14)
		draw_line(inner, outer, Color(0.7, 0.72, 0.75, 0.85), 2.0, true)

		# Minor ticks between majors
		if i < major_ticks:
			for j in range(1, minor_per_major):
				var mt := t + float(j) / float(major_ticks * minor_per_major)
				var m_angle := start_rad + sweep * mt
				var m_outer := center + Vector2(cos(m_angle), sin(m_angle)) * (radius - 4)
				var m_inner := center + Vector2(cos(m_angle), sin(m_angle)) * (radius - 9)
				draw_line(m_inner, m_outer, Color(0.45, 0.47, 0.5, 0.5), 1.0, true)


## ── Colored arc fill proportional to value ───────────────────────────────
func _draw_arc_fill(center: Vector2, radius: float) -> void:
	var start_rad := deg_to_rad(_start_angle_deg)
	var end_rad := deg_to_rad(_end_angle_deg)
	var sweep := end_rad - start_rad
	if sweep > 0:
		sweep -= TAU

	var t = clamp(_displayed_value / 100.0, 0.0, 1.0)
	if t <= 0.001:
		return

	var fill_angle = start_rad + sweep * t
	var arc_radius = radius - 18

	# Choose colour — danger pulsing red when low
	var col: Color
	if _displayed_value <= danger_threshold:
		col = Color(0.9, 0.15, 0.1).lerp(Color(1.0, 0.4, 0.2), _danger_pulse)
	elif _displayed_value <= 50.0:
		# Mid-range: shift toward amber/yellow
		var mid_t := (_displayed_value - danger_threshold) / (50.0 - danger_threshold)
		col = Color(0.95, 0.6, 0.1).lerp(gauge_color, mid_t)
	else:
		col = gauge_color

	# Determine draw direction — we need to go from start_rad toward fill_angle.
	# Since sweep is negative (clockwise), we step from start_rad to fill_angle.
	var point_count := int(abs(fill_angle - start_rad) / (TAU / 128.0)) + 2
	point_count = max(point_count, 4)
	draw_arc(center, arc_radius, start_rad, fill_angle, point_count, col, 5.0, true)

	# Glow layer
	var glow_col := Color(col.r, col.g, col.b, 0.2)
	draw_arc(center, arc_radius, start_rad, fill_angle, point_count, glow_col, 10.0, true)


## ── Needle ───────────────────────────────────────────────────────────────
func _draw_needle(center: Vector2, radius: float) -> void:
	var start_rad := deg_to_rad(_start_angle_deg)
	var end_rad := deg_to_rad(_end_angle_deg)
	var sweep := end_rad - start_rad
	if sweep > 0:
		sweep -= TAU

	var t = clamp(_displayed_value / 100.0, 0.0, 1.0)
	var needle_angle = start_rad + sweep * t
	var needle_len := radius - 12

	var tip := center + Vector2(cos(needle_angle), sin(needle_angle)) * needle_len
	var base_offset := 4.0
	var left  := center + Vector2(cos(needle_angle + PI * 0.5), sin(needle_angle + PI * 0.5)) * base_offset
	var right := center + Vector2(cos(needle_angle - PI * 0.5), sin(needle_angle - PI * 0.5)) * base_offset

	# Needle colour — white normally, red-ish in danger
	var needle_col: Color
	if _displayed_value <= danger_threshold:
		needle_col = Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.6, 0.4), _danger_pulse)
	else:
		needle_col = Color(0.9, 0.92, 0.95)

	# Draw filled triangle needle
	draw_colored_polygon(PackedVector2Array([tip, left, right]), needle_col)
	# Subtle needle outline
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color(0.0, 0.0, 0.0, 0.4), 1.0, true)


## ── Center cap (pivot dot) ──────────────────────────────────────────────
func _draw_center_cap(center: Vector2) -> void:
	draw_circle(center, 6, Color(0.3, 0.32, 0.36))
	draw_circle(center, 4, Color(0.5, 0.52, 0.55))
	draw_circle(center, 2, Color(0.7, 0.72, 0.75))


## ── Label beneath the dial ──────────────────────────────────────────────
func _draw_label(center: Vector2, radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 11
	var text_size := font.get_string_size(gauge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(center.x - text_size.x / 2.0, center.y + radius + 18)
	draw_string(font, pos, gauge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.65, 0.68, 0.72, 0.9))


## ── Numeric value in the centre of the dial ─────────────────────────────
func _draw_value_text(center: Vector2, _radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14
	var txt := str(int(round(_displayed_value)))
	var text_size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(center.x - text_size.x / 2.0, center.y + 24)

	var col: Color
	if _displayed_value <= danger_threshold:
		col = Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.6, 0.3), _danger_pulse)
	else:
		col = Color(0.85, 0.87, 0.9)
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)
