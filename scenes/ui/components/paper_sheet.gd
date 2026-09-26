class_name PaperSheet
extends PanelContainer

# 紙（書類）（2026-09-26・回UI-2・手本の「紙」）。
#
# ⚠ 情報は必ず紙の上（手本 UI_GUIDE §1）。⚠ 中に置いた字は**自動で墨色**になる
#   （⚠ `paper_theme.tres` をこの器の `theme` に持たせる＝決定 `UI-14`）。
# ⚠ 地は `PaperPanel`（羊皮紙・角丸3・影）、⚠ 四隅の角飾りは `_draw()` で引く。
#   ⚠ 値は Theme の `PaperPanel` 型が持つ（⚠ ここに色も寸法も書かない）。
# ⚠⚠ 手本の「少し傾ける」は**しない**。⚠ `Container` は子を並べるたびに回転を 0 に戻す
#   （⚠ 紙はいつも器の中に置かれる）。⚠ 質感（繊維・焼け）も画像待ち。
# ⚠ `.new()` で作る（⚠ `.tscn` を持たない。⚠ `ItemGrid` と同じ流儀）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const PAPER_THEME: Theme = preload("res://theme/paper_theme.tres")

# 四隅の角飾りを出すか。⚠ 小さい紙（⚠ 値札など）では消せる。
@export var show_corners: bool = true:
	set(value):
		show_corners = value
		queue_redraw()


func _init() -> void:
	theme_type_variation = &"PaperPanel"
	theme = PAPER_THEME


func _draw() -> void:
	if not show_corners:
		return
	var color: Color = get_theme_color(&"corner", &"PaperPanel")
	var length: float = float(get_theme_constant(&"corner_size", &"PaperPanel"))
	var width: float = float(get_theme_constant(&"corner_width", &"PaperPanel"))
	var inset: float = float(get_theme_constant(&"corner_inset", &"PaperPanel"))
	var left: float = inset
	var top: float = inset
	var right: float = size.x - inset
	var bottom: float = size.y - inset
	# ⚠ L字を4つ。⚠ 角から縦横に同じ長さ。
	for corner: Array in [
		[Vector2(left, top), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(right, top), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(left, bottom), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(right, bottom), Vector2(-1, 0), Vector2(0, -1)],
	]:
		var origin: Vector2 = corner[0]
		draw_line(origin, origin + (corner[1] as Vector2) * length, color, width)
		draw_line(origin, origin + (corner[2] as Vector2) * length, color, width)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
