# res://scenes/guild/training_list_screen.gd
# 育成の一覧（2026-09-27・人間「⚠ 上側のやつは育成に入れたほうがいい　⚠ 育成タブを復活させたほうがいい」→「⚠ 3あ」）。
#
# ⚠ 施設の帯の「育成」で開く。⚠ 全キャラの身上書カード（`DossierCard`）を傾いた紙で並べる。
# ⚠ カードの「開く ›」で育成（左に身上書・右に4タブ＝`training_screen`）へ入る。⚠ 育成の「戻る」はここへ戻る。
# ⚠ 並びは characters.json の順。⚠ 検証用は薄くして後ろ（⚠ リリースビルドでは出さない＝育成の札と同じ扱い）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。

extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const TRAINING_THEME_TYPE: StringName = &"Training"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var grid: GridContainer = $Margin/Layout/Scroll/Grid


func _ready() -> void:
	SceneManager.consume_transfer_data()
	header.back_pressed.connect(_on_back_pressed)
	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに（⚠ 本部の右上の素材16件はやめた）。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX))
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.TRAINING)
	var debug_alpha: float = float(get_theme_constant(&"chip_debug_alpha_pct", TRAINING_THEME_TYPE)) / 100.0
	var index: int = 0
	for character_id: String in character_order():
		var holder: TiltedSheet = TiltedSheet.create(index)
		holder.name = "Card_" + character_id
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if GameManager.is_debug_character(character_id):
			holder.modulate.a = debug_alpha
		grid.add_child(holder)
		var card: DossierCard = DossierCard.new()
		holder.sheet.add_child(card)
		card.setup(character_id)
		card.name = "Dossier"
		card.open_pressed.connect(_on_open_pressed)
		# ⚠ 10-07（人間「⚠ しおり紐は気づいたんだけど　そこから言ったページで何を見ればいいのかわかんなかった」）：⚠ 昇級できる人の札に紐。
		RibbonMark.set_on(holder.sheet, GameManager.can_level_up_now(character_id))
		index += 1


# ⚠ 本番のキャラ → 検証用（⚠ 検証用はリリースビルドでは出さない＝育成の札と同じ扱い）。
static func character_order() -> Array[String]:
	var ids: Array[String] = []
	var debug_ids: Array[String] = []
	for raw: Variant in MasterDataLoader.get_all_characters():
		var id: String = str(raw)
		if GameManager.is_debug_character(id):
			debug_ids.append(id)
		else:
			ids.append(id)
	if OS.is_debug_build():
		ids.append_array(debug_ids)
	return ids


func _on_open_pressed(character_id: String) -> void:
	SceneManager.change_scene_with_data(TRAINING_PATH, {TransferKeys.CHARACTER_ID: character_id})


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
