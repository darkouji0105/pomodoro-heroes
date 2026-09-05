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
# ⚠ 通路の真ん中に出す字（段階20-c・人間の指示「⚠ 通路にアイコンは、通路の真ん中に表示して」）。
#   ⚠ "" なら何も出さない。
const LINE_LABEL: String = "label"

# 通路の字の大きさと、字を置く箱の大きさ（段階20-c）。
#
# ⚠⚠ 箱を固定にして中央寄せする。⚠ そうしないと「線の中点」に置けない
#   （⚠ Label の実際の大きさはレイアウトが終わるまで分からない）。
const LABEL_FONT_SIZE: int = 16
const LABEL_BOX: Vector2 = Vector2(28.0, 24.0)

# 線の一覧。⚠ [{from: Vector2, to: Vector2, color: Color, width: float, label: String}]
var _lines: Array = []


# 線を差し替える。⚠ 呼ぶのは dungeon_map.gd の1箇所だけ。
#
# ⚠ ここで queue_redraw() する。⚠ 呼ぶ側で描き直しを覚えないこと。
# ⚠ 字は Label で置く（⚠ draw_string ではない）。⚠ カラー絵文字（COLR/CPAL）が
#   Label では出ることを実測済みで、⚠ draw_string では確かめていないため。
# ⚠ 再描画に await を持たせない。⚠ remove_child() してから queue_free()（AGENTS.md）。
func set_lines(lines: Array) -> void:
	_lines = lines
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for entry: Variant in _lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		var text: String = str(line.get(LINE_LABEL, ""))
		if text == "":
			continue
		var label: Label = Label.new()
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.size = LABEL_BOX
		# ⚠ 線の中点に置く。⚠ 箱のぶんだけ左上へずらして中央に合わせる。
		var mid: Vector2 = (
			(line.get(LINE_FROM, Vector2.ZERO) + line.get(LINE_TO, Vector2.ZERO)) * 0.5
		)
		label.position = mid - LABEL_BOX * 0.5
		add_child(label)
	queue_redraw()


# 通路の真ん中に出ている字の数。⚠ 検証の道具（scenario=layout）が読む。
func get_label_count() -> int:
	return get_child_count()


# 一番横に長い線の、横に動いた距離（段階20-g）。⚠ 検証の道具が読む。
#
# ⚠⚠ 絵は取れないが「線がどれだけ斜めか」は取れる。⚠ 人間の指摘
#   「⚠ 左から右に行く道がやたら生成される」がそのまま数字で出る。
# ⚠ 列を揃えたので、⚠ 隣の列ぶん（マスの幅＋間隔）までに収まるのが正解。
func get_max_horizontal_span() -> float:
	var worst: float = 0.0
	for entry: Variant in _lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		var dx: float = absf(
			(line.get(LINE_TO, Vector2.ZERO) as Vector2).x
			- (line.get(LINE_FROM, Vector2.ZERO) as Vector2).x
		)
		worst = maxf(worst, dx)
	return worst


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
