class_name SpBar
extends Control

# 敵の行動予告のゲージ（2026-09-18・人間の決定「敵に SP を付けて、それが溜まったら」
# 「ゲージは HP の下」）。
#
# ⚠⚠ 出すのは**敵だけ**（⚠ 味方はキーで撃つ・召喚はスキルを持たない）。
#   ⚠ SP を使わない個体（`sp_max` が 0＝スキルを持たない敵）は器ごと隠す。
# ⚠ 満ちた瞬間＝スキルを撃つ瞬間（`BattleController._step_enemy_sp()`）。
#   ⚠ 撃てない位置に居るときは満タンのまま待つので、⚠ 満タンの色のまま止まる。
# ⚠ 色と太さは Theme の `BattleUnitView` 型（⚠ ここに書かない）。
# ⚠ 値を持たない。⚠ 外から `set_ratio()` で毎フレーム受け取るだけ（`BattleBar` と同じ形）。

const THEME_TYPE: StringName = &"BattleUnitView"

var _ratio: float = 0.0
var _full: bool = false


# 満ち具合（0.0〜1.0）と、⚠ 満タンかどうか。⚠ 毎フレーム呼んでよい。
func set_ratio(ratio: float, is_full: bool) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	if is_equal_approx(clamped, _ratio) and is_full == _full:
		return
	_ratio = clamped
	_full = is_full
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"groove", THEME_TYPE))
	if _ratio <= 0.0:
		return
	var fill: Color = get_theme_color(&"sp_full" if _full else &"sp_fill", THEME_TYPE)
	draw_rect(Rect2(0.0, 0.0, size.x * _ratio, size.y), fill)
