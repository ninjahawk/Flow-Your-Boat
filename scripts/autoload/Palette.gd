extends Node

# --- Background & UI ---
const BG_COLOR       := Color(0.051, 0.059, 0.102)   # #0D0F1A  — very dark base
const LANE_COLOR     := Color(0.122, 0.141, 0.224)   # #1F2439  — visible but subtle
const GATE_BG        := Color(0.180, 0.196, 0.318)   # #2E3251  — clearly distinct
const GATE_ACTIVE_BG := Color(0.278, 0.306, 0.506)   # #474E81  — bright on approach
const TEXT_COLOR     := Color(1.0, 1.0, 1.0)
const SUBTEXT_COLOR  := Color(0.620, 0.686, 0.847)   # #9EAFD8
const DIVIDER_COLOR  := Color(0.278, 0.306, 0.506, 0.5)

# --- Item / Bin Colors ---
# Vibrant, dark-background-optimised
const ITEM_COLORS: Array[Color] = [
	Color(1.000, 0.278, 0.341),  # 0 RED     #FF4757
	Color(0.306, 0.804, 0.769),  # 1 TEAL    #4ECDC4
	Color(0.482, 0.929, 0.620),  # 2 GREEN   #7BED9F
	Color(1.000, 0.851, 0.239),  # 3 YELLOW  #FFD93D
	Color(0.635, 0.608, 0.996),  # 4 PURPLE  #A29BFE
]
const ITEM_NAMES: Array[String] = ["red", "teal", "green", "yellow", "purple"]

# Glow versions (brighter, slightly desaturated for bloom feel)
const GLOW_COLORS: Array[Color] = [
	Color(1.000, 0.500, 0.541),
	Color(0.600, 0.920, 0.900),
	Color(0.700, 0.980, 0.780),
	Color(1.000, 0.920, 0.580),
	Color(0.820, 0.800, 1.000),
]

# --- Rounded Rectangle Helper ---
# Draws a filled rounded rect on any CanvasItem inside _draw().
static func draw_rrect(
		canvas: CanvasItem,
		rect: Rect2,
		radius: float,
		color: Color,
		segments_per_corner: int = 8) -> void:

	var r := minf(minf(radius, rect.size.x * 0.5), rect.size.y * 0.5)
	var pts := PackedVector2Array()

	var corners: Array[Vector2] = [
		Vector2(rect.position.x + r,               rect.position.y + r),
		Vector2(rect.position.x + rect.size.x - r, rect.position.y + r),
		Vector2(rect.position.x + rect.size.x - r, rect.position.y + rect.size.y - r),
		Vector2(rect.position.x + r,               rect.position.y + rect.size.y - r),
	]
	var start_angles: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]

	for c in range(4):
		for s in range(segments_per_corner + 1):
			var a: float = start_angles[c] + (PI * 0.5) * float(s) / float(segments_per_corner)
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * r)

	var colors := PackedColorArray()
	colors.resize(pts.size())
	colors.fill(color)
	canvas.draw_polygon(pts, colors)

# Outline-only version (uses polyline)
static func draw_rrect_outline(
		canvas: CanvasItem,
		rect: Rect2,
		radius: float,
		color: Color,
		line_width: float = 2.0,
		segments_per_corner: int = 8) -> void:

	var r := minf(minf(radius, rect.size.x * 0.5), rect.size.y * 0.5)
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.position.x + r,               rect.position.y + r),
		Vector2(rect.position.x + rect.size.x - r, rect.position.y + r),
		Vector2(rect.position.x + rect.size.x - r, rect.position.y + rect.size.y - r),
		Vector2(rect.position.x + r,               rect.position.y + rect.size.y - r),
	]
	var start_angles: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]

	for c in range(4):
		for s in range(segments_per_corner + 1):
			var a: float = start_angles[c] + (PI * 0.5) * float(s) / float(segments_per_corner)
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * r)

	pts.append(pts[0])  # close the loop
	canvas.draw_polyline(pts, color, line_width, true)
