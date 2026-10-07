class_name RibbonMark
extends RefCounted

# しおり紐（2026-10-07・人間「⚠ Aはしおり的な奴がUIテストにあるのでそれを」「⚠ EはAとおなじ」）。
#
# ⚠ 「用事がある」「新しい」の印。⚠ 右上の縁から垂れる赤い紐・下の端は切り込み（⚠ 施設の帯の手本の形）。
# ⚠ 前は施設の帯が自分で描いていた＝⚠ 行・マスにも付けるので部品にした。⚠ 値は Theme の `FacilityBar` 型（`ribbon_*`）。
# ⚠ 使い方：⚠ 描くなら `RibbonMark.attach(control)`（⚠ その場で描き直す）。⚠ 自分で描く器は `draw_on(control)` を `draw` から呼ぶ。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const THEME_TYPE: StringName = &"FacilityBar"
const META_ON: StringName = &"ribbon_on"
# ⚠ 右端からの余白を変える（⚠ 細い器＝紙のタブは右端いっぱい。⚠ 施設の帯の余白のままだと字に重なった＝撮った絵）。
const META_INSET: StringName = &"ribbon_inset"


static func attach(control: Control) -> void:
	if control == null:
		return
	control.set_meta(META_ON, true)
	if not control.draw.is_connected(_on_draw.bind(control)):
		control.draw.connect(_on_draw.bind(control))
	control.queue_redraw()


static func detach(control: Control) -> void:
	if control == null or not control.has_meta(META_ON):
		return
	control.set_meta(META_ON, false)
	control.queue_redraw()


# ⚠ 付けるか外すかを1行で（⚠ 描き直しのたびに判定し直す画面向け）。
static func set_on(control: Control, on: bool) -> void:
	if on:
		attach(control)
	else:
		detach(control)


static func has_ribbon(control: Control) -> bool:
	return control != null and control.has_meta(META_ON) and bool(control.get_meta(META_ON))


static func _on_draw(control: Control) -> void:
	if has_ribbon(control):
		draw_on(control)


static func draw_on(control: Control) -> void:
	var w: float = float(control.get_theme_constant(&"ribbon_w", THEME_TYPE))
	var h: float = float(control.get_theme_constant(&"ribbon_h", THEME_TYPE))
	var inset: float = float(control.get_meta(META_INSET)) if control.has_meta(META_INSET) else float(control.get_theme_constant(&"ribbon_inset", THEME_TYPE))
	var x: float = control.size.x - inset - w
	control.draw_colored_polygon(PackedVector2Array([
		Vector2(x, 0.0), Vector2(x + w, 0.0), Vector2(x + w, h),
		Vector2(x + w * 0.5, h - w * 0.5), Vector2(x, h),
	]), control.get_theme_color(&"ribbon", THEME_TYPE))
