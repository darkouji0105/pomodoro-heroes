class_name DungeonEdgeLines
extends Control

# 難ダンジョンのマップの通路を線で描く（段階19-e・人間の指示）。
#
# ⚠⚠ 人間の言葉：「⚠ 通路用のグラフィックを用意したほうがいい。⚠ 今ノードだけで、
#   通路が見えない状態」。⚠ 19-c-2 まではマスの前に絵文字を付けるだけで、
#   ⚠ 「どのマスからどのマスへ繋がっているか」が画面に1本も出ていなかった。
#
# ⚠ この部品は GameManager を1行も知らない。⚠ 線の一覧をもらって描くだけ。
#   ⚠ 知らせると、⚠ 「どの通路に効果があるか」の判定が2箇所になる。
# ⚠ 1画面でしか使わないので scenes/adventure/（AGENTS.md「UIパーツの置き場所」）。
# ⚠ マウスを取らない（mouse_filter = ignore）。⚠ 取るとマスのボタンが押せなくなる。

# 線1本ぶんのキー。⚠ 文字列リテラルを画面側と2箇所に書かないための定数。
const LINE_FROM: String = "from"
const LINE_TO: String = "to"
const LINE_COLOR: String = "color"
const LINE_WIDTH: String = "width"

# 線の一覧。⚠ [{from: Vector2, to: Vector2, color: Color, width: float}]
var _lines: Array = []


# 線を差し替える。⚠ 呼ぶのは dungeon_map.gd の1箇所だけ。
#
# ⚠ ここで queue_redraw() する。⚠ 呼ぶ側で描き直しを覚えないこと。
func set_lines(lines: Array) -> void:
	_lines = lines
	queue_redraw()


# いま引いている線の本数。⚠ 検証の道具（scenario=layout）が読む。
#
# ⚠⚠ 絵は取れないが「何本引いたか」は取れる。⚠ 0 本なら通路が1本も見えていない
#   （⚠ 人間が実機で報告した「通路が見えない状態」がそのまま数字で出る）。
func get_line_count() -> int:
	return _lines.size()


func _draw() -> void:
	for entry: Variant in _lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		draw_line(
			line.get(LINE_FROM, Vector2.ZERO),
			line.get(LINE_TO, Vector2.ZERO),
			line.get(LINE_COLOR, Color.WHITE),
			float(line.get(LINE_WIDTH, 2.0)),
			true
		)
