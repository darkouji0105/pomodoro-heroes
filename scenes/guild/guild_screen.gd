# res://scenes/guild/guild_screen.gd
# ギルド画面：5つのサブ画面（倉庫/ショップ/育成/研究/作業場）への入口。
# 遷移先は GUILD_SCENES に集約し、カードごとに直書きしない（完了条件17）。
#
# ⚠⚠ 2026-09-11（人間のモック「ギルド／育成」A）：⚠ **縦1列のボタンからカードの 3 × 2 に変えた**。
#   ⚠ 前は 96 x 300 の列が中央にあるだけで、⚠ 1280 x 720 の1割も使っていなかった。
#   ⚠ カードは「⚠ 絵 ／ 名前 ／ 何をする所か ／ いまの状態」の4段。
#   ⚠ **状態の行がこの画面の主役**（⚠ 入るまで分からなかったことを外に出す）。
#
# ⚠ 琥珀（`ActiveCardPanel`）は **育成の1枚だけ**（⚠ モックの決定「次にやることを1つに絞る」）。
#   ⚠ ボタンの4階層の「⚠ 真鍮は1画面に1個」と同じ考え方。
# ⚠ 枠は6つで固定（`SLOT_COUNT`）。⚠ 開いていない画面も**枠は残す**＝位置が動かない。
#   ⚠ ただし**名前も説明も出さない**（⚠ 人間の決定・2026-08-24「出さない」）。
#   ⚠ 6つ目は最初から空き。⚠ 入口が増えたときの置き場所。

class_name GuildScreen
extends Control

# --- シーン ---
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const RESEARCH_PATH: String = "res://scenes/guild/research_screen.tscn"
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
# ⚠ 作業場は段階11で復活した（EXEC_WORKSHOP_REVIVE.md）。装飾のランダム製作。
#   ⚠ 開くのは stage_3 のクリア（stages.json の unlocks）。閉じている間は
#     カードが空き枠になる（.tscn 側では閉じない）。
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"


# sub_screen_id -> 遷移先パス
# ⚠ sub_screen_id は GameStateKeys の画面IDと同じ綴り（段階9）。
#   ⚠ 文字列リテラルを書かないこと（AGENTS.md）。unlocked_screens のキーでもある。
# ⚠⚠ 倉庫の入口は消した（2026-09-15・人間の指示「倉庫画面は、この窓だけに」「カードを消す」）。
#   ⚠ 倉庫は右上の「倉庫」ボタンで別窓に出す（`InventoryWindow`）。
const GUILD_SCENES: Dictionary = {
	GameStateKeys.SCREEN_SHOP: SHOP_PATH,
	GameStateKeys.SCREEN_TRAINING: TRAINING_PATH,
	GameStateKeys.SCREEN_RESEARCH: RESEARCH_PATH,
	GameStateKeys.SCREEN_WORKSHOP: WORKSHOP_PATH,
}

# ⚠ カードの並び（モックの並び）。⚠ `GUILD_SCENES` は Dictionary で順が保証されないので、
#   ⚠ 並びはここが持つ。⚠ 入口を足すときは両方に足す。
const CARD_ORDER: Array[String] = [
	GameStateKeys.SCREEN_TRAINING,
	GameStateKeys.SCREEN_SHOP,
	GameStateKeys.SCREEN_RESEARCH,
	GameStateKeys.SCREEN_WORKSHOP,
]

# ⚠ 枠の数。⚠ 3 × 2。⚠ 入口が5つでも6つ目の空き枠を出す（⚠ 位置を動かさないため）。
const SLOT_COUNT: int = 6
# ⚠ 琥珀にする1枚。⚠ 2枚にしないこと。
const PRIMARY_SCREEN: String = GameStateKeys.SCREEN_TRAINING
# ⚠ カードの絵の大きさ。⚠ 線画は 48px で読み込まれるので、⚠ 器は必ず
#   `EXPAND_IGNORE_SIZE` にする（⚠ 既定のままだと 48px が最小になる。§0-UI-B-1）。
const CARD_ICON_SIZE: int = 38

# --- ノード参照 ---
@onready var cards: GridContainer = $Margin/Layout/Cards
@onready var header: ScreenHeader = $Margin/Layout/Header

func _ready() -> void:
	# ⚠⚠ 戻るはヘッダーの左上（2026-09-14・人間の指示「⚠ ギルドから拠点に戻るボタンは左上に」
	#   「⚠ 戻るボタンの位置を画面によって変えたくない」）。⚠ 前は右下の Foot に居た。
	header.back_pressed.connect(_on_back_pressed)
	# 段階解放（GAME_DESIGN.md 9-5）。⚠ base_screen.gd と同じ1行。
	#   ⚠ 閉じ方は _rebuild() の1箇所だけ。.tscn 側で二重に閉じない。
	GameManager.screen_unlocked.connect(_on_screen_unlocked)
	# ⚠ 状態の行は所持品・素材・研究で変わる。⚠ 開いている間に変わることは無いが、
	#   ⚠ 演出（`ResourceGainEffect`）が着地したあとに数が合わないと嘘になる。
	GameManager.inventory_changed.connect(_on_state_changed)
	GameManager.research_node_unlocked.connect(_on_state_changed)
	GameManager.character_growth_changed.connect(_on_state_changed)
	GameManager.material_changed.connect(_on_material_changed)
	_rebuild()


# --- カード ---

# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _rebuild() -> void:
	for child: Node in cards.get_children():
		cards.remove_child(child)
		child.queue_free()

	for index: int in range(SLOT_COUNT):
		var screen_id: String = CARD_ORDER[index] if index < CARD_ORDER.size() else ""
		# ⚠ 開いていない入口は**空き枠として**出す。⚠ 名前は出さない（人間の決定）。
		if screen_id != "" and not GameManager.is_screen_unlocked(screen_id):
			screen_id = ""
		cards.add_child(_create_card(screen_id))


func _create_card(screen_id: String) -> PanelContainer:
	var is_empty: bool = screen_id == ""
	var is_primary: bool = screen_id == PRIMARY_SCREEN

	var card: PanelContainer = PanelContainer.new()
	card.name = "Card_" + (screen_id if not is_empty else "empty")
	# ⚠⚠ 2026-09-11（人間の指示「⚠ 育成の輪が浮いて見える。⚠ 倉庫のボタンと同じに」）：
	#   ⚠ **面はどのカードも同じ**にした。⚠ 前は育成だけ琥珀の枠（`ActiveCardPanel`）で、
	#   ⚠ 常時光る輪が1枚だけ浮いて見えた（⚠ ホバーの白い縁と二重の輪にもなっていた）。
	#   ⚠ 「次にやることを1つに絞る」は**下の状態の行の色**だけで言う（⚠ 枠では言わない）。
	card.theme_type_variation = &"CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ⚠ 空き枠は沈める。⚠ 押せないことを色で言う（⚠ 当たりも付けない）。
	card.modulate.a = 0.45 if is_empty else 1.0

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	card.add_child(column)

	var icon: Texture2D = IconTextures.for_screen(screen_id)
	if icon != null:
		column.add_child(_create_icon(icon))

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	# ⚠ 名前も説明も `"ui_guild_" + screen_id` で機械的に引く（AGENTS.md 翻訳キーの運用）。
	name_label.text = tr("ui_guild_empty_slot") if is_empty else tr("ui_guild_" + screen_id)
	column.add_child(name_label)

	var description: Label = Label.new()
	description.name = "DescriptionLabel"
	description.theme_type_variation = &"CaptionLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = tr("ui_guild_empty_desc") if is_empty else tr("ui_guild_desc_" + screen_id)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)

	column.add_child(_create_status(screen_id, is_primary))

	# ⚠ 面ぜんぶを押せるようにする。⚠ 透明なボタンを重ねる（Theme の `HitButton`）。
	#   ⚠ `PanelContainer` は子を全面に伸ばすので、⚠ 2枚目の子として足すだけでよい。
	if not is_empty:
		UiButton.attach_hit(card, _go_to_sub.bind(screen_id))
	return card


# ⚠ 絵の器。⚠ `EXPAND_IGNORE_SIZE` を外さないこと（§0-UI-B-1 の再発防止）。
func _create_icon(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return rect


# カードの一番下の1行。⚠ 「入ってみないと分からないこと」をここに出す。
#
# ⚠ 文言も数も `_status_text()` の1本から引く。⚠ カードごとに if を並べない。
func _create_status(screen_id: String, is_primary: bool) -> Label:
	var label: Label = Label.new()
	label.name = "StatusLabel"
	label.theme_type_variation = &"AccentLabel" if is_primary else &"CaptionLabel"
	label.text = _status_text(screen_id)
	return label


# 入口ごとの「いまの状態」。⚠ 取れない値を作り話で埋めないこと。
func _status_text(screen_id: String) -> String:
	match screen_id:
		GameStateKeys.SCREEN_TRAINING:
			return _training_status()
		GameStateKeys.SCREEN_SHOP:
			return tr("ui_guild_status_shop") % _shop_count()
		GameStateKeys.SCREEN_RESEARCH:
			return tr("ui_guild_status_research") % _research_count()
		GameStateKeys.SCREEN_WORKSHOP:
			return tr("ui_guild_status_workshop") % GameManager.get_available_recipes().size()
	return tr("ui_guild_empty_status")


# 「剣士が Lv13 に上げられます」。⚠ 上げられるキャラが居なければその旨。
#
# ⚠ 一覧は `MasterDataLoader.get_all_characters()` から引く（⚠ 画面に列挙しない）。
# ⚠ 検証用は数えない（⚠ 「検証・状態が上げられます」と出ても意味が無い）。
# ⚠ 判定は育成画面と同じ2つ（⚠ 上限に達していない ／ 素材が足りている）。
func _training_status() -> String:
	for character_id: Variant in MasterDataLoader.get_all_characters():
		var id: String = str(character_id)
		if GameManager.is_debug_character(id):
			continue
		var level: int = int(GameManager.get_character_growth(id).get(GameStateKeys.GROWTH_LEVEL, 1))
		if level >= GameManager.get_effective_level_cap(id):
			continue
		var cost: Dictionary = GameManager.get_level_up_cost(id)
		var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
		if GameManager.get_material_count(material_id) < int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0)):
			continue
		return tr("ui_guild_status_training") % [
			tr(str(MasterDataLoader.get_character(id).get("name_key", ""))),
			level + 1,
		]
	return tr("ui_guild_status_training_none")


# ⚠ ショップは3種（日替わり・週替わり・月替わり）を合わせて数える。
#   ⚠ 種類の一覧はマスターに聞く（⚠ 3 と書かない）。
# ⚠⚠ モックは「次の入れ替えまで 6:12」だったが、⚠ **`refresh_at` はゲーム内の日付の
#   文字列**（`"2026-08-11"`）で、⚠ 秒まで刻む値をどこも持っていない＝**出せない**。
#   ⚠ 代わりに品揃えの件数を出す（⚠ 報告済み）。
func _shop_count() -> int:
	var total: int = 0
	for shop_type: Variant in MasterDataLoader.get_all_shop_types():
		total += GameManager.get_shop_lineup(str(shop_type)).size()
	return total


# ⚠ いま解放できる研究ノードの数。⚠ 判定は GameManager の1本
#   （⚠ 前提と素材の見方をここで作り直さない）。
# ⚠⚠ モックは「進行中 1 件 ／ 残り 2:40」だったが、⚠ **研究に待ち時間の仕組みは無い**
#   （⚠ 解放は即時）。⚠ 出せないので「解放できる N 件」にした（⚠ 報告済み）。
func _research_count() -> int:
	var total: int = 0
	for node_id: Variant in MasterDataLoader.get_all_research_nodes():
		if GameManager.can_unlock_research_node(str(node_id)):
			total += 1
	return total


# --- シグナル ---

func _on_screen_unlocked(_screen_id: String) -> void:
	_rebuild()

func _on_state_changed(_id: String) -> void:
	_rebuild()

func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	_rebuild()

func _go_to_sub(sub_id: String) -> void:
	var path: String = str(GUILD_SCENES.get(sub_id, ""))
	if path == "":
		push_warning("[GuildScreen] unknown sub_screen_id: " + sub_id)
		return
	# 未実装画面は placeholder_screen が screen_id を表示に使うため SCREEN_ID を渡す
	if path == PLACEHOLDER_PATH:
		SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: sub_id})
	else:
		# 倉庫画面はそのまま開く（タブ指定が必要なら呼び出し側で change_scene_with_data を使う）
		SceneManager.change_scene(path)

func _on_back_pressed() -> void:
	# 拠点へ戻る。go_back() は履歴管理がダミー扱いのため使わない
	SceneManager.change_scene(BASE_PATH)
