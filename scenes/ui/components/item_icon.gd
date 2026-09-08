class_name ItemIcon
extends Panel

# 仮アセット＝絵文字のアイコン。
#   ⚠ 種類の絵文字を中央 ／ 品の1文字を左上 ／ 段数の数字を右下 ／ **等級を枠線の色**。
#
# ⚠⚠ 2026-09-08：⚠ 等級を「地の色」から「枠線の色」へ移した（⚠ 人間のモック）。
#   ⚠ 地は暗い一色（`IconConfig.icon_bg_color`）。⚠ 40個並べても画面が色で埋まらない。
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

# grade_and_number() の戻りのキー。⚠ 文字列リテラルを呼ぶ側に書かせない。
const RESULT_GRADE: String = "grade"
const RESULT_NUMBER: String = "number"

@onready var text_label: Label = $TextLabel
@onready var grade_label: Label = $GradeLabel
# 左上の種類の絵文字（段階19-a）。⚠ 対応表は Glyphs の1本だけ。
@onready var glyph_label: Label = $GlyphLabel

var _item_id: String = ""
var _grade: int = 0

# 中央の線画（2026-09-08）。⚠ SVG が在ればこちら、⚠ 無ければ絵文字の Label。
#   ⚠ `.tscn` を触らずコードで作る（⚠ 3つの Label と同じ流儀）。
var _glyph_texture: TextureRect = null
# 枠の中に重ねる絵（2026-09-08）。⚠ 装飾だけ（⚠ 枠＝種類 ／ 中身＝ステータス）。
var _inner_texture: TextureRect = null

# 中身の絵の大きさ（⚠ 枠に対する割合）。⚠ 見た目の都合だけ。
const INNER_RATIO: float = 0.52


# 呼ぶ側の1行の口。⚠ 装備の個体だけ grade を渡す（等級は instance_id ごとに
#   違うので item_id からは引けない）。装飾・素材は 0 のままでよい。
static func create(item_id: String, grade: int = 0) -> ItemIcon:
	var scene: PackedScene = load(SCENE_PATH)
	var icon: ItemIcon = scene.instantiate()
	icon.setup(item_id, grade)
	return icon


# item_id（＋装備の個体の等級）から「背景の色に使う等級」と「右下の数字」を決める。
#
# ⚠⚠ 判定はここ1本。⚠ 呼ぶ側で item_type を見ないこと。
# ⚠ 静的にしてあるのは、⚠ アイコンを1個も作らずに等級だけ知りたい呼び出しがあるため
#   （⚠ UI テストのページが等級順に並べる・2026-09-07）。⚠ 同じ写し方を2箇所に書かない。
# ⚠ Balance.icon が未割り当てのときは等級1・数字なしを返す（⚠ 赤は _refresh() 側が出す）。
static func grade_and_number(item_id: String, instance_grade: int) -> Dictionary:
	var config: IconConfig = Balance.icon
	if config == null:
		return {RESULT_GRADE: 1, RESULT_NUMBER: ""}
	if instance_grade > 0:
		# 装備の個体。等級 1〜10 をそのまま色に使う（人間の決定・10色）。
		return {RESULT_GRADE: instance_grade, RESULT_NUMBER: str(instance_grade)}
	var part: Dictionary = GameManager.get_part_definition(item_id)
	if not part.is_empty():
		var tier: int = int(part.get(GameManager.ITEM_MASTER_PART_TIER, 0))
		# ⚠ ルーンだけ段階が5（PartConfig.max_rune_tier）。写す表が違う。
		var is_rune: bool = not GameManager.get_rune_definition(item_id).is_empty()
		return {RESULT_GRADE: config.grade_of_tier(tier, is_rune), RESULT_NUMBER: str(tier)}
	var material_tier: int = GameManager.get_material_tier(item_id)
	if material_tier > 0:
		return {
			RESULT_GRADE: config.grade_of_tier(material_tier, false),
			RESULT_NUMBER: str(material_tier),
		}
	# それ以外（レリック・消耗品）は段数を持たない。⚠ 数字を出さない。
	return {RESULT_GRADE: config.default_grade, RESULT_NUMBER: ""}


func _ready() -> void:
	_refresh()


func setup(item_id: String, grade: int = 0) -> void:
	_item_id = item_id
	_grade = grade
	# ⚠ create() は add_child() の前に呼ぶので、ここではまだ @onready が null。
	#   その場合は _ready() 側が描く。
	if is_inside_tree():
		_refresh()


# 検証用（⚠ 設計役は絵を見られない）。⚠ いま中央に何を出しているかを文字で返す。
#   ⚠ ゲームのロジックから呼ばないこと。
# ⚠⚠ これが無いと、⚠ 線画に差し替えた瞬間に検証の「絵=」が空になって意味を失う
#   （⚠ 2026-09-08 に実際にそうなった。⚠ 等級を枠線へ移したときと同じ失敗）。
func get_center_debug_text() -> String:
	if _glyph_texture != null and is_instance_valid(_glyph_texture) and _glyph_texture.visible:
		if _glyph_texture.texture != null:
			var text: String = "SVG:" + _glyph_texture.texture.resource_path.get_file()
			# ⚠ 中身（装飾のステータス）も出す。⚠ 出さないと「枠だけ同じで中身が違う」
			#   ⚠ 品を並べたときに、⚠ 中身が入っているかを確かめられない。
			if _inner_texture != null and is_instance_valid(_inner_texture) and _inner_texture.visible:
				if _inner_texture.texture != null:
					text += "+" + _inner_texture.texture.resource_path.get_file()
			return text
	return glyph_label.text


# 中央の線画の器。⚠ 1回だけ作る。⚠ 枠と中身の2枚。
func _ensure_glyph_texture() -> void:
	if _glyph_texture != null and is_instance_valid(_glyph_texture):
		return
	_glyph_texture = _make_texture_rect("GlyphTexture")
	add_child(_glyph_texture)
	_inner_texture = _make_texture_rect("InnerTexture")
	_inner_texture.visible = false
	add_child(_inner_texture)


func _make_texture_rect(node_name: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = node_name
	# ⚠ ホバーの枠や `ItemSlot` の中に入るので、⚠ マウスを止めない。
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _refresh() -> void:
	var config: IconConfig = Balance.icon
	if config == null:
		push_error("[ItemIcon] Balance.icon が未割り当て。アイコンを描けない")
		return

	# 右下の数字と、色に使う等級を決める。⚠ 判定は grade_and_number() の1本。
	var decided: Dictionary = grade_and_number(_item_id, _grade)
	var grade: int = int(decided.get(RESULT_GRADE, config.default_grade))
	var number: String = str(decided.get(RESULT_NUMBER, ""))

	custom_minimum_size = Vector2(float(config.icon_size_px), float(config.icon_size_px))

	# ⚠⚠ 等級は **枠線** の色で持つ（2026-09-08・人間のモック）。⚠ 地は暗い一色。
	#   ⚠ 前は地が等級の色だった。⚠ 40個並ぶと画面が色の面で埋まっていた。
	#   ⚠ 色の表（`grade_colors`）は変えていない。⚠ 塗る場所を変えただけ。
	var grade_color: Color = config.color_of_grade(grade)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = config.icon_bg_color
	box.set_corner_radius_all(config.icon_corner_radius)
	box.set_border_width_all(maxi(0, config.icon_border_width))
	box.border_color = grade_color
	add_theme_stylebox_override("panel", box)

	# 左上に「どの品か」の1文字。
	#
	# ⚠ 2026-09-07 に中央から左上へ移した（人間の指示「絵文字を大きくして、
	#   文字を小さく」）。⚠ .tscn は触らず、位置もここから当てる（下の絵文字・
	#   右下の数字と同じ形）。⚠ .tscn を開くと3つの Label が入れ替わる前の
	#   位置のままなので、位置はこの関数が正。
	text_label.text = tr("ui_icon_" + _item_id)
	text_label.add_theme_font_size_override("font_size", config.icon_font_size)
	text_label.add_theme_color_override("font_color", config.icon_text_color)
	text_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	text_label.offset_left = 3.0
	text_label.offset_top = 1.0
	text_label.offset_right = 3.0 + float(config.icon_font_size) + 4.0
	text_label.offset_bottom = 1.0 + float(config.icon_font_size) + 4.0
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# 中央に「どの種類か」の絵文字（段階19-a）。
	#
	# ⚠⚠ 左上の1文字を置き換えない。⚠ 絵文字は種類ごと（11種）なので、
	#   ⚠ 置き換えると91件の品が11種類の見た目に潰れ、⚠ どの品か分からなくなる。
	#   ⚠ 「どの品か」＝左上の1文字 ／ 「どの種類か」＝絵文字 ／ 「何段か」＝右下の数字
	#   ⚠ ／ 「どの等級か」＝**枠線の色**（2026-09-08 に背景から移した）。
	#   ⚠ 4つで役割が分かれている。
	# ⚠⚠ 1文字が系統ごとにしか無いのは、⚠ 「絵文字＋1文字」の組で見分ける前提だから
	#   （⚠ 例：「鉄」は 🔪 鉄剣 / 🎩 鉄兜 / 👕 鉄鎧 / 👟 鉄脚 の4件に出る）。
	#   ⚠ 絵文字を種類ごとに分けるのをやめると、⚠ この4件が見分けられなくなる。
	# ⚠ glyph_font_size が 0 なら出さない（⚠ フォントが無い環境の逃げ道）。
	# ⚠⚠ 線画（SVG）が在ればそちらを出す（2026-09-08）。⚠ 無ければ絵文字に落ちる
	#   ＝⚠ 1枚ずつ差し替えられる（⚠ 全部そろうまで待たない）。
	# ⚠ 線画は白の1色なので、⚠ **等級の色を着せる**（⚠ カラー絵文字ではできなかったこと）。
	var texture: Texture2D = IconTextures.for_item(_item_id)
	var glyph_size: float = float(maxi(1, config.glyph_font_size))
	if texture != null:
		_ensure_glyph_texture()
		_glyph_texture.texture = texture
		_glyph_texture.modulate = grade_color
		_glyph_texture.visible = config.glyph_font_size > 0
		_glyph_texture.size = Vector2(glyph_size, glyph_size)
		# ⚠ 中央に置く。⚠ 器はコンテナではないので、⚠ 位置も自分で当てる。
		_glyph_texture.position = (
			Vector2(float(config.icon_size_px), float(config.icon_size_px))
			- Vector2(glyph_size, glyph_size)
		) * 0.5
		# ⚠⚠ 装飾は枠の中にステータスの絵を重ねる（2026-09-08・人間の指示）。
		#   ⚠ 枠＝宝石／護符／紋章、⚠ 中身＝その装飾が上げる軸。
		#   ⚠ 中身を持たない品（⚠ 装備・素材・ルーン）では出さない。
		var inner: Texture2D = IconTextures.inner_for_item(_item_id)
		if inner != null:
			var inner_size: float = glyph_size * INNER_RATIO
			_inner_texture.texture = inner
			_inner_texture.modulate = grade_color
			_inner_texture.visible = _glyph_texture.visible
			_inner_texture.size = Vector2(inner_size, inner_size)
			_inner_texture.position = (
				Vector2(float(config.icon_size_px), float(config.icon_size_px))
				- Vector2(inner_size, inner_size)
			) * 0.5
		else:
			_inner_texture.visible = false

		glyph_label.visible = false
		grade_label.text = number
		grade_label.visible = number != ""
		grade_label.add_theme_font_size_override("font_size", config.grade_font_size)
		grade_label.add_theme_color_override("font_color", grade_color)
		grade_label.offset_left = -float(config.icon_size_px) * 0.5
		grade_label.offset_top = -float(config.grade_font_size) - 4.0
		return

	if _glyph_texture != null:
		_glyph_texture.visible = false
	glyph_label.text = Glyphs.for_item(_item_id)
	glyph_label.visible = config.glyph_font_size > 0
	glyph_label.add_theme_font_size_override("font_size", maxi(1, config.glyph_font_size))
	glyph_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph_label.offset_left = 0.0
	glyph_label.offset_top = 0.0
	glyph_label.offset_right = 0.0
	glyph_label.offset_bottom = 0.0
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	grade_label.text = number
	grade_label.visible = number != ""
	grade_label.add_theme_font_size_override("font_size", config.grade_font_size)
	# ⚠ 右下の数字だけ等級の色で出す（2026-09-08・モック）。⚠ 枠線と同じ色＝
	#   ⚠ 枠が細くて色が読み取りにくいときの2つ目の手がかりになる。
	grade_label.add_theme_color_override("font_color", grade_color)
	# 右下に寄せる。⚠ 大きさが Config なので、位置もコードで合わせる。
	grade_label.offset_left = -float(config.icon_size_px) * 0.5
	grade_label.offset_top = -float(config.grade_font_size) - 4.0
