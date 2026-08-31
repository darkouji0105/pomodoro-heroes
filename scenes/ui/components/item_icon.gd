class_name ItemIcon
extends Panel

# 仮アセット＝文字のアイコン（2文字の漢字を中央・段数の数字を右下）。
#
# ⚠ 画像を1枚も使わない。段階13（SDキャラ）が素材待ちの間、
#   「どれが何か分かる」状態にするための仮のもの（NEXT_STEPS §0-A）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md「UIパーツの置き場所」）。
#   いま出ているのは 倉庫 / 装備 / ショップ / レリック選択 の4画面。
#
# ⚠ 文字は ja.csv の "ui_icon_" + item_id で引く。1件も分岐を書かない
#   （AGENTS.md「"ui_res_" + material_id で機械的に引ける状態を保つ」と同じ形）。
#   ⚠ ja.csv に無いとキー名がそのまま出る。これは意図した挙動（AGENTS.md）。
# ⚠ 色と大きさは Balance.icon（IconConfig）。ここに直書きしない。
# ⚠ 数字に tr() は使わない（AGENTS.md「数値のみの表示」）。

const SCENE_PATH: String = "res://scenes/ui/components/item_icon.tscn"

@onready var text_label: Label = $TextLabel
@onready var grade_label: Label = $GradeLabel

var _item_id: String = ""
var _grade: int = 0


# 呼ぶ側の1行の口。⚠ 装備の個体だけ grade を渡す（等級は instance_id ごとに
#   違うので item_id からは引けない）。装飾・素材は 0 のままでよい。
static func create(item_id: String, grade: int = 0) -> ItemIcon:
	var scene: PackedScene = load(SCENE_PATH)
	var icon: ItemIcon = scene.instantiate()
	icon.setup(item_id, grade)
	return icon


func _ready() -> void:
	_refresh()


func setup(item_id: String, grade: int = 0) -> void:
	_item_id = item_id
	_grade = grade
	# ⚠ create() は add_child() の前に呼ぶので、ここではまだ @onready が null。
	#   その場合は _ready() 側が描く。
	if is_inside_tree():
		_refresh()


func _refresh() -> void:
	var config: IconConfig = Balance.icon
	if config == null:
		push_error("[ItemIcon] Balance.icon が未割り当て。アイコンを描けない")
		return

	# 右下の数字と、色に使う等級を決める。
	# ⚠ 判定はここ1本。呼ぶ側で item_type を見ないこと。
	var grade: int = config.default_grade
	var number: String = ""
	if _grade > 0:
		# 装備の個体。等級 1〜10 をそのまま色に使う（人間の決定・10色）。
		grade = _grade
		number = str(_grade)
	else:
		var part: Dictionary = GameManager.get_part_definition(_item_id)
		var material_tier: int = GameManager.get_material_tier(_item_id)
		if not part.is_empty():
			var tier: int = int(part.get(GameManager.ITEM_MASTER_PART_TIER, 0))
			# ⚠ ルーンだけ段階が5（PartConfig.max_rune_tier）。写す表が違う。
			var is_rune: bool = not GameManager.get_rune_definition(_item_id).is_empty()
			grade = config.grade_of_tier(tier, is_rune)
			number = str(tier)
		elif material_tier > 0:
			grade = config.grade_of_tier(material_tier, false)
			number = str(material_tier)
		# それ以外（レリック・消耗品）は段数を持たない。数字を出さない。

	custom_minimum_size = Vector2(float(config.icon_size_px), float(config.icon_size_px))

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = config.color_of_grade(grade)
	box.set_corner_radius_all(config.icon_corner_radius)
	add_theme_stylebox_override("panel", box)

	text_label.text = tr("ui_icon_" + _item_id)
	text_label.add_theme_font_size_override("font_size", config.icon_font_size)
	text_label.add_theme_color_override("font_color", config.icon_text_color)

	grade_label.text = number
	grade_label.visible = number != ""
	grade_label.add_theme_font_size_override("font_size", config.grade_font_size)
	grade_label.add_theme_color_override("font_color", config.icon_text_color)
	# 右下に寄せる。⚠ 大きさが Config なので、位置もコードで合わせる。
	grade_label.offset_left = -float(config.icon_size_px) * 0.5
	grade_label.offset_top = -float(config.grade_font_size) - 4.0
