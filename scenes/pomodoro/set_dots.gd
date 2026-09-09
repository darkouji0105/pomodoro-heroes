class_name SetDots
extends Control

# セットの進み（2026-09-09・人間のモック「D案＋輪」）。
#
# ⚠ 上部バーの真ん中。⚠ **「1 / 4 Sets」の文字を置き換える**。
# ⚠ 終わったセット＝薄い点 ／ 今のセット＝横長の器が真鍮で満ちる ／ これからのセット＝暗い点。
# ⚠ 満ちる量は**今のフェーズの進み**をそのまま使う（＝輪と同じ値）。
#   ⚠ 「セット1つぶん」を厳密に測ると集中・休憩・振り返りの重みを決める話になるため、
#   ⚠ 今回は輪と揃えておく（⚠ 人間が見て違和感があれば別途）。
# ⚠ 色と寸法は Theme が持つ（`tools/theme_builder.gd` の `_build_pomodoro()`）。
# ⚠ 1画面でしか使わないので `scenes/pomodoro/`（AGENTS.md）。

const SCENE_PATH: String = "res://scenes/pomodoro/set_dots.tscn"

var _total: int = 0
var _current: int = -1
var _ratio: float = 0.0


func setup(total: int) -> void:
	_total = maxi(0, total)
	_update_minimum_size()
	queue_redraw()


# ⚠ 今が何セット目（0 始まり）と、そのセットの進み。
#   ⚠ `current` に -1 を渡すと**1つも光らない**（加護を選ぶ段）。
func set_state(current: int, ratio: float) -> void:
	_current = current
	_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func _update_minimum_size() -> void:
	if _total <= 0:
		custom_minimum_size = Vector2.ZERO
		return
	var size_px: int = get_theme_constant(&"size", &"SetDots")
	var wide: int = get_theme_constant(&"current_width", &"SetDots")
	var gap: int = get_theme_constant(&"gap", &"SetDots")
	# ⚠ 今のセットだけ横長。⚠ 1つも「今」でなくても幅は変えない
	#   （⚠ セットが進むたびに横幅が動くと、⚠ 真ん中寄せの点が左右に揺れる）。
	var width: int = (_total - 1) * (size_px + gap) + wide
	custom_minimum_size = Vector2(width, size_px)


func _ready() -> void:
	_update_minimum_size()


func _draw() -> void:
	if _total <= 0:
		return

	var size_px: int = get_theme_constant(&"size", &"SetDots")
	var wide: int = get_theme_constant(&"current_width", &"SetDots")
	var gap: int = get_theme_constant(&"gap", &"SetDots")
	var done_color: Color = get_theme_color(&"done", &"SetDots")
	var todo_color: Color = get_theme_color(&"todo", &"SetDots")
	var fill_color: Color = get_theme_color(&"current", &"SetDots")

	var radius: float = float(size_px) * 0.5
	var x: float = 0.0
	for i: int in range(_total):
		if i == _current:
			# ⚠ 横長の器。⚠ 両端は半円（⚠ モックの `border-radius` が高さと同じ＝丸い）。
			_draw_pill(x, float(wide), float(size_px), todo_color)
			if _ratio > 0.0:
				_draw_pill(x, float(wide) * _ratio, float(size_px), fill_color)
			x += float(wide) + float(gap)
			continue

		var color: Color = done_color if i < _current else todo_color
		draw_circle(Vector2(x + radius, radius), radius, color)
		x += float(size_px) + float(gap)


# ⚠ 両端が半円の横長。⚠ `draw_rect()` だけだと角が四角くなる。
#   ⚠ 幅が高さ以下のときは円1つ（⚠ 満ち始めに角が飛び出さないように）。
func _draw_pill(x: float, width: float, height: float, color: Color) -> void:
	var radius: float = height * 0.5
	if width <= height:
		draw_circle(Vector2(x + radius, radius), radius, color)
		return
	draw_circle(Vector2(x + radius, radius), radius, color)
	draw_circle(Vector2(x + width - radius, radius), radius, color)
	draw_rect(Rect2(Vector2(x + radius, 0.0), Vector2(width - height, height)), color)
