## Mech-suit arc gauge drawn entirely via _draw().
## No needle — uses a thick bold arc fill for at-a-glance readability.
## Features: warning zone arc, bezel, face with scanlines, tick marks, digital readout.
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
## 225° → 315° gives a classic bottom-open speedometer look.
var _start_angle_deg: float = 225.0
var _end_angle_deg: float = -45.0

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
	center.y -= 4.0

	_draw_bezel(center, radius)
	_draw_face(center, radius)
	_draw_tick_marks(center, radius)
	_draw_warning_arc(center, radius)
	_draw_arc_fill(center, radius)
	_draw_label(center, radius)
	_draw_value_text(center, radius)


## ── Bezel (outer metallic ring) ──────────────────────────────────────────
func _draw_bezel(center: Vector2, radius: float) -> void:
	# Outer ring — slightly larger, darker for depth
	draw_arc(center, radius + 7, 0, TAU, 64, Color(0.25, 0.28, 0.32, 0.95), 5.0, true)
	# Bright highlight ring (top-left quadrant chamfer effect)
	draw_arc(center, radius + 5, deg_to_rad(200), deg_to_rad(340), 32, Color(0.6, 0.65, 0.7, 0.5), 2.0, true)
	# Inner shadow ring
	draw_arc(center, radius + 2, 0, TAU, 64, Color(0.1, 0.1, 0.12, 0.8), 2.0, true)


## ── Face (dark background disc with scanlines) ──────────────────────────
func _draw_face(center: Vector2, radius: float) -> void:
	# Filled dark circle
	draw_circle(center, radius, Color(0.06, 0.07, 0.10, 0.95))
	# Subtle inner edge highlight
	draw_arc(center, radius - 1, 0, TAU, 64, Color(0.22, 0.25, 0.28, 0.3), 1.0, true)

	# Scanlines — faint horizontal lines across the face for cockpit-LCD feel
	var line_spacing := 5.0
	var top_y := center.y - radius + 3.0
	var bot_y := center.y + radius - 3.0
	var y := top_y
	while y <= bot_y:
		# Clip to circle: find x extent at this y
		var dy := y - center.y
		if abs(dy) < radius:
			var dx := sqrt(radius * radius - dy * dy) * 0.88
			draw_line(
				Vector2(center.x - dx, y),
				Vector2(center.x + dx, y),
				Color(0.15, 0.18, 0.22, 0.25),
				0.7, false
			)
		y += line_spacing


## ── Tick marks ───────────────────────────────────────────────────────────
func _draw_tick_marks(center: Vector2, radius: float) -> void:
	var start_rad := deg_to_rad(_start_angle_deg)
	var end_rad := deg_to_rad(_end_angle_deg)
	var sweep := end_rad - start_rad
	if sweep > 0:
		sweep -= TAU

	var major_ticks := 10
	var minor_per_major := 4

	for i in range(major_ticks + 1):
		var t := float(i) / float(major_ticks)
		var angle := start_rad + sweep * t

		# In danger zone? Tint red
		var val_at_tick := t * 100.0
		var is_danger := val_at_tick <= danger_threshold
		var tick_color: Color
		if is_danger:
			tick_color = Color(0.85, 0.2, 0.15, 0.75)
		else:
			tick_color = Color(0.65, 0.68, 0.72, 0.8)

		# Major tick
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 3)
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - 12)
		draw_line(inner, outer, tick_color, 1.5, true)

		# Minor ticks between majors
		if i < major_ticks:
			for j in range(1, minor_per_major):
				var mt := t + float(j) / float(major_ticks * minor_per_major)
				var m_angle := start_rad + sweep * mt
				var m_val := mt * 100.0
				var m_danger := m_val <= danger_threshold
				var m_outer := center + Vector2(cos(m_angle), sin(m_angle)) * (radius - 3)
				var m_inner := center + Vector2(cos(m_angle), sin(m_angle)) * (radius - 7)
				var m_color := Color(0.65, 0.15, 0.12, 0.45) if m_danger else Color(0.4, 0.42, 0.45, 0.45)
				draw_line(m_inner, m_outer, m_color, 0.8, true)


## ── Warning zone arc (always visible danger band) ────────────────────────
func _draw_warning_arc(center: Vector2, radius: float) -> void:
	var start_rad := deg_to_rad(_start_angle_deg)
	var end_rad := deg_to_rad(_end_angle_deg)
	var sweep := end_rad - start_rad
	if sweep > 0:
		sweep -= TAU

	var warn_t: float = clampf(danger_threshold / 100.0, 0.0, 1.0)
	var warn_fill_angle: float = start_rad + sweep * warn_t
	var arc_radius := radius - 20

	var point_count: int = int(abs(warn_fill_angle - start_rad) / (TAU / 128.0)) + 2
	point_count = max(point_count, 4)

	# Dim red band
	draw_arc(center, arc_radius, start_rad, warn_fill_angle, point_count,
		Color(0.7, 0.08, 0.05, 0.22), 10.0, true)
	# Fine border at the danger threshold
	var warn_tip := center + Vector2(cos(warn_fill_angle), sin(warn_fill_angle)) * arc_radius
	var warn_base := center + Vector2(cos(warn_fill_angle), sin(warn_fill_angle)) * (arc_radius - 10)
	draw_line(warn_base, warn_tip, Color(0.9, 0.15, 0.1, 0.55), 1.5, true)


## ── Colored arc fill proportional to value ───────────────────────────────
func _draw_arc_fill(center: Vector2, radius: float) -> void:
	var start_rad := deg_to_rad(_start_angle_deg)
	var end_rad := deg_to_rad(_end_angle_deg)
	var sweep := end_rad - start_rad
	if sweep > 0:
		sweep -= TAU

	var t: float = clampf(_displayed_value / 100.0, 0.0, 1.0)
	if t <= 0.001:
		return

	var fill_angle: float = start_rad + sweep * t
	var arc_radius := radius - 20

	# Choose colour — danger pulsing red when low
	var col: Color
	if _displayed_value <= danger_threshold:
		col = Color(0.9, 0.15, 0.1).lerp(Color(1.0, 0.4, 0.2), _danger_pulse)
	elif _displayed_value <= 50.0:
		var mid_t: float = (_displayed_value - danger_threshold) / (50.0 - danger_threshold)
		col = Color(0.95, 0.6, 0.1).lerp(gauge_color, mid_t)
	else:
		col = gauge_color

	var point_count: int = int(abs(fill_angle - start_rad) / (TAU / 128.0)) + 2
	point_count = max(point_count, 4)

	# Main bold arc — thick for at-a-glance readability
	draw_arc(center, arc_radius, start_rad, fill_angle, point_count, col, 10.0, true)

	# Bright leading edge highlight
	var tip_angle := fill_angle
	var tip_inner := center + Vector2(cos(tip_angle), sin(tip_angle)) * (arc_radius - 5)
	var tip_outer := center + Vector2(cos(tip_angle), sin(tip_angle)) * (arc_radius + 5)
	draw_line(tip_inner, tip_outer, Color(col.r, col.g, col.b, 0.9).lightened(0.3), 2.0, true)

	# Outer glow layer
	var glow_col := Color(col.r, col.g, col.b, 0.18)
	draw_arc(center, arc_radius, start_rad, fill_angle, point_count, glow_col, 18.0, true)

	# Inner subtle shadow under arc
	draw_arc(center, arc_radius, start_rad, fill_angle, point_count,
		Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.25), 14.0, true)


## ── Label beneath the dial ──────────────────────────────────────────────
func _draw_label(center: Vector2, radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 10
	var text_size := font.get_string_size(gauge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(center.x - text_size.x / 2.0, center.y + radius + 14)
	# Shadow
	draw_string(font, pos + Vector2(1,1), gauge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
		Color(0, 0, 0, 0.6))
	draw_string(font, pos, gauge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
		Color(0.7, 0.75, 0.8, 0.95))


## ── Numeric value in the centre of the dial ─────────────────────────────
func _draw_value_text(center: Vector2, _radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 15
	var txt := str(int(round(_displayed_value)))
	var text_size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(center.x - text_size.x / 2.0, center.y + 18)

	var col: Color
	if _displayed_value <= danger_threshold:
		col = Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.6, 0.3), _danger_pulse)
	else:
		col = Color(0.88, 0.92, 0.96)

	# Drop shadow for readability
	draw_string(font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
		Color(0, 0, 0, 0.7))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)
