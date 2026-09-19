class_name RunHpBar
extends Control

# ランの3人のHPのバー（2026-09-20・人間の指示「⚠ きゃらのHPをバーにして見やすく」）。
#
# ⚠⚠ バーの全体は**素の MAX HP**。⚠ 満ちている部分が**いまの「戦闘時 MAX HP」**、
#   ⚠ 残りが**削れたぶん**（⚠ 人間「⚠ 最大HPが先頭によって減ってる状態ならバーもそれに応じた見た目に」）。
#   ⚠ ＝削れたぶんは消えずに**赤い帯として残る**。⚠ 「どれだけ減らされたか」が一目で分かること（§4-4）。
# ⚠ 戦闘は毎回この上限から満タンで始まる（決定18）ので、⚠ 「いまのHP」と「上限」は同じ値。
#   ⚠ だからバーは1本でよい（⚠ 2本目を足さないこと）。
# ⚠ 見た目の値（色・高さ・幅・角丸）は Theme の `RunHpBar` だけが持つ（AGENTS.md）。
# ⚠ 脱落したキャラは満ちを 0 にする（⚠ 行ごと消さない＝誰が欠けたかが分かること）。

const THEME_TYPE: StringName = &"RunHpBar"

var _current: int = 0
var _base: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	custom_minimum_size = Vector2(
		float(get_theme_constant(&"width", THEME_TYPE)),
		float(get_theme_constant(&"height", THEME_TYPE))
	)


# いまの「戦闘時 MAX HP」と素の MAX HP。⚠ 値は画面が GameManager に聞いたもの。
func set_values(current: int, base: int) -> void:
	_current = maxi(0, current)
	_base = maxi(1, base)
	queue_redraw()


# 満ちている割合（⚠ 検証の道具が読む）。⚠ 削れているほど小さい。
func get_ratio() -> float:
	return clampf(float(_current) / float(maxi(1, _base)), 0.0, 1.0)


func to_text() -> String:
	return "%d/%d" % [_current, _base]


func _draw() -> void:
	var groove: StyleBox = get_theme_stylebox(&"groove", THEME_TYPE)
	var fill: StyleBox = get_theme_stylebox(&"fill", THEME_TYPE)
	var lost: StyleBox = get_theme_stylebox(&"lost", THEME_TYPE)
	if groove == null or fill == null or lost == null:
		return
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(groove, full)
	# ⚠ 削れたぶんを先に敷く（⚠ 満ちの右側に残る）。⚠ 角丸が重なるので全体に敷いてから満ちを描く。
	if _current < _base:
		draw_style_box(lost, full)
	var ratio: float = clampf(float(_current) / float(_base), 0.0, 1.0)
	if ratio <= 0.0:
		return
	draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)))
