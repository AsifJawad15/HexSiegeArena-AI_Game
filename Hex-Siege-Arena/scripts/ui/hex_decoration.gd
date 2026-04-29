## HexDecoration — draws a brick-offset grid of hollow hex outlines.
## Use as a fixed-width decorative column inside panel cards.
## Set custom_minimum_size.x and size_flags_vertical = EXPAND_FILL.
extends Control

## Outline color. Keep alpha low (0.10 – 0.18) for a subtle background effect.
@export var hex_color: Color = Color(0.94, 0.75, 0.28, 0.13)
## Flat-top hex radius in pixels.
@export var hex_radius: float = 18.0
## Outline stroke width in pixels.
@export var stroke_width: float = 1.2


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	# Flat-top hex geometry
	var col_step: float = hex_radius * 1.5          # horizontal distance between hex centers
	var row_step: float = hex_radius * sqrt(3.0)    # vertical distance between hex centers
	var cols: int = int(ceil(w / col_step)) + 2
	var rows: int = int(ceil(h / row_step)) + 2

	for col in range(-1, cols):
		for row in range(-1, rows):
			# Odd columns offset downward by half a row
			var offset_y: float = row_step * 0.5 if col % 2 != 0 else 0.0
			var cx: float = col * col_step
			var cy: float = row * row_step + offset_y
			_draw_hex_outline(Vector2(cx, cy))


func _draw_hex_outline(center: Vector2) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		# Flat-top orientation: first vertex at 0°
		var angle: float = deg_to_rad(60.0 * i)
		pts.append(center + Vector2(cos(angle), sin(angle)) * hex_radius)

	for i in range(6):
		draw_line(pts[i], pts[(i + 1) % 6], hex_color, stroke_width, true)
