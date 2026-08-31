class_name IconConfig
extends Resource

# 仮アセット（文字のアイコン）の見た目のConfig。
# 実際の値は res://resources/balance/configs/icon_config.tres を Inspector で編集する。
#
# ⚠ .tres は @export の既定値を書き出さないため、値を変えていない項目は
#   icon_config.tres に行が現れない。実際に効いているのはここの既定値
#   （part_config.gd / equipment_config.gd と同じ罠）。
#
# ⚠ 色をここに置く理由：同じ「段数の色」を宝箱の演出（floor_map.gd）と
#   アイコン部品（item_icon.gd）の2箇所が読むため。const のまま2箇所に置くと
#   片方だけ直したときに宝箱とアイコンで色が食い違う。
#   ⚠ 色を Balance に置く前例は AdventureConfig の pop_*_color と status_chip_*_color。
#
# ⚠ 文字そのものは ja.csv の "ui_icon_" + item_id が持つ。ここには置かない
#   （AGENTS.md「翻訳キーの運用」。素材名 "ui_res_" + material_id と同じ規則）。

# --- 等級の色（10段） ---
# 添字0が等級1。装備の等級（1〜10）をそのまま添字にする。
#
# ⚠ 人間の決定（2026-08-31）：装備の色は10色。4段に畳まない。
# ⚠ 添字 0 / 3 / 6 / 9（＝等級 1 / 4 / 7 / 10）は、宝箱のレアリティ4色
#   （common 灰 / rare 青 / epic 紫 / legendary 金）と**同じ値**にしてある。
#   ⚠ floor_map.gd の CHEST_COLORS はこの4点に置き換えた。ここを動かすと
#     宝箱の色も動く。4点を動かすときは tier_grades の意味ごと見直すこと。
# ⚠ 長さは EquipmentConfig.max_equipment_grade と揃える（合わないと E132 が鳴る）。
@export var grade_colors: Array[Color] = [
	Color(0.80, 0.80, 0.82),  #  1 灰（＝宝箱 common）
	Color(0.62, 0.84, 0.62),  #  2 白緑
	Color(0.36, 0.78, 0.46),  #  3 緑
	Color(0.40, 0.70, 1.00),  #  4 青（＝宝箱 rare）
	Color(0.32, 0.52, 0.96),  #  5 濃青
	Color(0.55, 0.44, 0.98),  #  6 青紫
	Color(0.75, 0.45, 0.95),  #  7 紫（＝宝箱 epic）
	Color(0.98, 0.44, 0.74),  #  8 桃
	Color(1.00, 0.55, 0.30),  #  9 橙
	Color(1.00, 0.80, 0.25),  # 10 金（＝宝箱 legendary）
]

# アイコンの上に載る文字の色。⚠ 上の10色はどれも明るいので、暗い1色で足りる。
@export var icon_text_color: Color = Color(0.08, 0.08, 0.10)

# --- 段階を等級へ写す表 ---
# 装飾（宝石・護符・紋章）・素材・宝箱のレアリティは 1〜4 段。
# 添字0が段階1。値がその段階に使う等級。
#
# ⚠ 境目は EquipmentConfig.forge_material_tier_min_grades と同じ [1,4,7,10]。
#   ⚠ 新しい境目を発明しないこと。あちらは「どの鍛冶素材が要るか」の区切りで
#     意味が違うため、配列は別に持つ（あちらを読むと意味が混ざる）。
@export var tier_grades: Array[int] = [1, 4, 7, 10]

# ルーンだけ段階が5（PartConfig.max_rune_tier）。
# ⚠ tier_grades と長さが違う。使い回さないこと。
@export var rune_tier_grades: Array[int] = [1, 3, 6, 8, 10]

# 段階も等級も持たないもの（レリック・消耗品）に使う等級。
@export var default_grade: int = 1

# --- 大きさ ---
# アイコン1個の一辺（px）。⚠ 状態のマス（status_chip）の16pxより大きい。
# 行の高さを決めるので、変えたら scenario=layout を回すこと。
@export var icon_size_px: int = 40
# 中央の2文字の字の大きさ。
@export var icon_font_size: int = 18
# 右下の数字の字の大きさ。
@export var grade_font_size: int = 11
# 角の丸み。
@export var icon_corner_radius: int = 6


# 等級（1〜）から色を引く。⚠ 範囲外は端に丸める（黙って黒を返さない）。
func color_of_grade(grade: int) -> Color:
	if grade_colors.is_empty():
		return Color.WHITE
	var index: int = clampi(grade - 1, 0, grade_colors.size() - 1)
	return grade_colors[index]


# 段階（1〜）を等級へ写す。is_rune のときだけ5段の表を使う。
func grade_of_tier(tier: int, is_rune: bool) -> int:
	var table: Array[int] = rune_tier_grades if is_rune else tier_grades
	if table.is_empty():
		return default_grade
	var index: int = clampi(tier - 1, 0, table.size() - 1)
	return table[index]
