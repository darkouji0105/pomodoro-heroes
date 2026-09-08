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

# アイコンの上に載る文字の色。
#
# ⚠⚠ 2026-09-08 に暗い色 → 明るい色へ変えた（人間のモック）。
#   ⚠ 等級の色を **地から枠線へ移した**ため、⚠ 地が暗い一色になった。
#   ⚠ 暗い文字のままだと地に沈んで1文字も読めない。
@export var icon_text_color: Color = Color(0.88, 0.84, 0.81)

# --- 地と枠（2026-09-08・人間のモック「等級は枠線の色で持つ」）---
#
# ⚠⚠ 前は「地の色＝等級」だった。⚠ 10色とも明るいので、⚠ マスが40個並ぶと
#   ⚠ 画面が色の面で埋まっていた。⚠ モックは **地を暗い一色にして、枠線だけ等級の色**。
# ⚠ 等級の色（`grade_colors`）はそのまま。⚠ 塗る場所が変わっただけ。
#   ⚠ 宝箱の演出（`floor_map.gd`）は同じ10色を今までどおり読む。
@export var icon_bg_color: Color = Color(0.110, 0.090, 0.082)
# 枠線の太さ（px）。⚠ 0 にすると枠が消える＝等級が分からなくなる。
@export var icon_border_width: int = 2

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
# 左上の1文字の字の大きさ。
#
# ⚠ 2026-09-07 に 18 → 11 へ下げた（人間の指示「絵文字を大きくして、文字を小さく」）。
#   ⚠ 同じ回に文字を2文字 → 1文字にした（ja.csv の ui_icon_* 103行）。
#   ⚠ 2文字に戻すならここも上げ直すこと（11 のままだと読めない）。
@export var icon_font_size: int = 11
# 右下の数字の字の大きさ。
@export var grade_font_size: int = 10
# 中央の種類の絵文字の字の大きさ（段階19-a）。
#
# ⚠ 絵文字そのものは `scripts/utils/glyphs.gd` の1本。⚠ ここは大きさだけ。
# ⚠ 0 にすると絵文字を出さない（⚠ 左上の1文字だけに戻る）。⚠ フォントが
#   入っていない環境で豆腐が並ぶときの逃げ道。
# ⚠ 2026-09-07 に 13 → 20 へ上げた（人間の指示）。⚠ マス 40px の半分。
@export var glyph_font_size: int = 20
# 角の丸み。
@export var icon_corner_radius: int = 6

# --- 装飾の枠のマス（2026-09-08・段階②・`PartSlotIcon`）---
#
# ⚠ アイテムのマス（40px）より小さい。⚠ 7個並べて1行に収める前提。
@export var part_slot_size_px: int = 22
# 枠の中の絵文字の大きさ。
@export var part_slot_glyph_font_size: int = 11
# 空きの枠の枠線の太さ。
@export var part_slot_border_width: int = 1
# 装填済の枠線の太さ。⚠ 太くして、⚠ 等級の色が読めるようにする。
@export var part_slot_filled_border_width: int = 2
# 空きの枠の絵文字の薄さ（0.0〜1.0）。⚠ 1.0 で装填済と同じ濃さ。
@export var part_slot_dim_alpha: float = 0.55

# --- 空きの枠の枠線の色＝そこに刺さる種類（2026-09-08・人間の指示
#     「⚠ スロットの周りの枠で何を付けられるかわかるようにしたい」）---
#
# ⚠⚠ 色が言うことは、⚠ 空きと装填済で違う：
#   ⚠ 空き   … **そこに刺さる種類**（⚠ 下の5色）
#   ⚠ 装填済 … **刺さっているものの等級**（⚠ `grade_colors`。⚠ 種類は中の絵文字が言う）
#   ⚠ 刺さってしまえば「何が刺さるか」は要らないので、⚠ 1つの枠線を2つの意味で使い分ける。
# ⚠ 等級の10色と紛らわしくならないよう、⚠ 彩度を落としてある。
@export var part_slot_gem_color: Color = Color(0.44, 0.72, 0.78)
@export var part_slot_charm_color: Color = Color(0.48, 0.72, 0.52)
@export var part_slot_emblem_color: Color = Color(0.66, 0.55, 0.80)
@export var part_slot_rune_color: Color = Color(0.78, 0.68, 0.40)
# ワイルド枠（⚠ 宝石・護符・紋章のどれでも受ける）。
#
# ⚠⚠ **虹色**（2026-09-08・人間の指示「⚠ 装備のワイルドは虹色にして」）。
#   ⚠ 1色では「どれでも受ける」を言えないため。⚠ `StyleBoxFlat` の枠線は1色しか
#   持てないので、⚠ `PartSlotIcon` が枠を自前で描く（⚠ そのときだけ）。
# ⚠ 下の2つは色相を回すときの彩度と明度。⚠ 色相は 0〜1 を1周させる。
# ⚠ `part_slot_wild_color` は虹を描けないときの逃げ道（⚠ ツールチップや検証には出ない）。
@export var part_slot_wild_color: Color = Color(0.55, 0.50, 0.46)
@export var part_slot_wild_saturation: float = 0.55
@export var part_slot_wild_value: float = 0.95


# 等級（1〜）から色を引く。⚠ 範囲外は端に丸める（黙って黒を返さない）。
func color_of_grade(grade: int) -> Color:
	if grade_colors.is_empty():
		return Color.WHITE
	var index: int = clampi(grade - 1, 0, grade_colors.size() - 1)
	return grade_colors[index]


# ワイルド枠か（＝刺さる種類が1つに決まっていないか）。
#
# ⚠ 判定はここ1本。⚠ 「1つならその種類」の書き方を呼ぶ側に写さないこと。
func is_wild_part_slot(kinds: Variant) -> bool:
	return not (kinds is Array) or (kinds as Array).size() != 1


# 空きの枠に使う色。⚠ 刺さる種類が1つならその色、⚠ 複数（ワイルド枠）なら wild。
#
# ⚠⚠ ここが唯一の対応表。⚠ 呼ぶ側で種類ごとに if を分岐させないこと
#   （⚠ `Glyphs.for_part_slot()` と同じ形）。
func color_of_part_slot_kinds(kinds: Variant) -> Color:
	if is_wild_part_slot(kinds):
		return part_slot_wild_color
	match str((kinds as Array)[0]):
		GameManager.PART_KIND_GEM:
			return part_slot_gem_color
		GameManager.PART_KIND_CHARM:
			return part_slot_charm_color
		GameManager.PART_KIND_EMBLEM:
			return part_slot_emblem_color
		GameManager.PART_KIND_RUNE:
			return part_slot_rune_color
	return part_slot_wild_color


# 段階（1〜）を等級へ写す。is_rune のときだけ5段の表を使う。
func grade_of_tier(tier: int, is_rune: bool) -> int:
	var table: Array[int] = rune_tier_grades if is_rune else tier_grades
	if table.is_empty():
		return default_grade
	var index: int = clampi(tier - 1, 0, table.size() - 1)
	return table[index]
