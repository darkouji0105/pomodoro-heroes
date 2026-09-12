class_name TierDots
extends Control

# 段の進み（2026-09-12・人間のモック「Stat node mock」）。
#
# ⚠⚠ 前は **20段が20行**として縦に並んでいた（⚠ 3枝で60行）。⚠ モックは
#   ⚠ **1軸を1行にして、⚠ 段の進みを点の列で出す**。⚠ 縦が 1/20 になる。
# ⚠ 済んだ段＝真鍮の点 ／ これからの段＝暗い点。⚠ 記号（● ○ ✕）は使わない
#   （⚠ 「記号で状態を言わない」）。⚠ 点は状態ではなく**進み具合の目盛り**。
# ⚠ 5段ごとに間を空ける。⚠ `nodes.json` の `cost` が6段目から上がるため、
#   ⚠ 「あと何段で重くなるか」が並びで読める。
#
# ⚠ 色と寸法は Theme が持つ（`tools/theme_builder.gd` の `_build_stat_nodes()`）。
#   ⚠ ここに px も色も書かない（⚠ `TimerRing` / `SetDots` と同じ置き方）。
# ⚠ 1画面でしか使わないので `scenes/guild/`（AGENTS.md「UIパーツの置き場所ルール」）。
# ⚠ `.tscn` は持たない（⚠ 中身が `_draw()` だけなので、⚠ シーンにする意味が無い）。

var _total: int = 0
var _done: int = 0


# 段の総数と、そのうち解放ずみの数。⚠ 木に入る前に呼んでもよい。
func setup(total: int, done: int) -> void:
	_total = maxi(0, total)
	_done = clampi(done, 0, _total)
	name = "Dots"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_inside_tree():
		_update_minimum_size()
	queue_redraw()


func _ready() -> void:
	_update_minimum_size()


func _update_minimum_size() -> void:
	if _total <= 0:
		custom_minimum_size = Vector2.ZERO
		return
	var size_px: int = get_theme_constant(&"size", &"TierDots")
	custom_minimum_size = Vector2(_width_of(_total), size_px)


# 点 `count` 個ぶんの横幅。⚠ 描画の x 送りと同じ式にすること
#   （⚠ 別々に書くと、⚠ 最後の点が器からはみ出して欠ける）。
func _width_of(count: int) -> float:
	if count <= 0:
		return 0.0
	var size_px: int = get_theme_constant(&"size", &"TierDots")
	var gap: int = get_theme_constant(&"gap", &"TierDots")
	var group: int = maxi(1, get_theme_constant(&"group", &"TierDots"))
	var group_gap: int = get_theme_constant(&"group_gap", &"TierDots")
	var width: float = float(count * size_px + (count - 1) * gap)
	# ⚠ 区切りの数＝「区切りをまたいだ回数」。⚠ ちょうど割り切れるときは
	#   ⚠ 末尾に区切りを足さない（⚠ 右端に空白が余る）。
	var breaks: int = int((count - 1) / group)
	return width + float(breaks * group_gap)


func _draw() -> void:
	if _total <= 0:
		return
	var size_px: int = get_theme_constant(&"size", &"TierDots")
	var gap: int = get_theme_constant(&"gap", &"TierDots")
	var group: int = maxi(1, get_theme_constant(&"group", &"TierDots"))
	var group_gap: int = get_theme_constant(&"group_gap", &"TierDots")
	var done_color: Color = get_theme_color(&"done", &"TierDots")
	var todo_color: Color = get_theme_color(&"todo", &"TierDots")

	var radius: float = float(size_px) * 0.5
	var x: float = 0.0
	for i: int in range(_total):
		if i > 0:
			x += float(gap)
			if i % group == 0:
				x += float(group_gap)
		var color: Color = done_color if i < _done else todo_color
		draw_circle(Vector2(x + radius, radius), radius, color)
		x += float(size_px)


# 検証用（⚠ 設計役は絵を見られない）。⚠ ゲームのロジックから呼ばないこと。
func to_text() -> String:
	return "%d/%d" % [_done, _total]
