# res://scenes/guild/training_screen.gd
# ギルド：育成画面。
#
# ⚠⚠ 2026-09-27（回UI-組 育成・手本 Character / Nodes / Skills / Equip）：⚠ **作り替えた**。
#   ⚠ 左に身上書（`CharacterDossier`）・右に紙のタブ4枚（概要・ステータスノード・スキル・装備）。
#   ⚠ 右上にキャラの札（⚠ 押すと切り替わる）。⚠ 前の「一覧 → 詳細」はやめた（⚠ 手本に一覧が無い）。
#   ⚠ 人間「⚠ 1い」＝**1画面の中でタブを切り替える**。⚠ 前は割り振り・スキル・装備が別の画面だった。
#   ⚠ 人間「⚠ 4あ」＝検証用のキャラは札を薄くして後ろに並べる（⚠ リリースビルドでは出さない）。
#   ⚠ 昇級は別の画面（`level_up_screen`＝昇級申請書・人間「⚠ 3あ」）。⚠ 概要の「昇級させる」から入る。
#   ⚠ 装備のタブの「鍛冶場で鍛える」は**鍛冶場をその品を選んだ状態で開く**（⚠ 09-27 回UI-仕組み①・人間「⚠ 3あ」）。
#
# ⚠ キャラの一覧は `MasterDataLoader.get_all_characters()` から引く（⚠ 決め打ちしない）。
# ⚠ 検証用（`char_debug_*`）の判定は `GameManager.is_debug_character()`。

class_name TrainingScreen
extends Control

# ⚠ 2026-09-26（回UI-3）：⚠ 戻る先は本部（拠点）→ ⚠ 09-27 から育成の一覧（`training_list_screen`）。
const LIST_PATH: String = "res://scenes/guild/training_list_screen.tscn"
const LEVEL_UP_PATH: String = "res://scenes/guild/level_up_screen.tscn"
# ⚠ 鍛冶場（⚠ 装備のタブの「鍛冶場で鍛える」の行き先）。
const FORGE_PATH: String = "res://scenes/guild/forge_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const THEME_TYPE: StringName = &"Training"

# ⚠ タブの並び。⚠ 外から開くときは `TransferKeys.TRAINING_TAB_*` の字で指す（⚠ 番号を漏らさない）。
const TAB_IDS: Array[String] = [
	TransferKeys.TRAINING_TAB_OVERVIEW, TransferKeys.TRAINING_TAB_NODES,
	TransferKeys.TRAINING_TAB_SKILLS, TransferKeys.TRAINING_TAB_EQUIP,
]
const TAB_KEYS: Array[String] = [
	"ui_training_tab_overview", "ui_training_nodes", "ui_training_skill", "ui_training_equipment",
]

var _selected_id: String = ""
var _tab_ids: Array[String] = []
var _tab: String = TransferKeys.TRAINING_TAB_OVERVIEW

var _chips: HBoxContainer = null
var _dossier: CharacterDossier = null
var _tabs: PaperTabs = null
var _page: VBoxContainer = null

# ビルド（キャラプリセット）の行（EXEC_PARTY_PRESETS.md）。
# ⚠ 判定も文面も GameManager 側の1本を通る。⚠ ここに書いてあるのは器の組み立てだけ。
# ⚠ 「焼く」と「適用」は向きが逆（焼く＝現在→ビルド／適用＝ビルド→現在）。⚠ 1つのボタンにまとめないこと。
var _build_picker: OptionButton = null
var _selected_build: int = 0
# ⚠ 結果の1行。⚠ 概要を組み直すたびに作り直すので、⚠ 文言は変数で持ち越す。
var _notice_text: String = ""

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: HBoxContainer = $Margin/Layout/Body
@onready var right: VBoxContainer = $Margin/Layout/Body/Right


func _ready() -> void:
	# ⚠ 10-07：⚠ 入手先の窓から戻ってきたときの姿を預ける（`SceneManager.set_return_data_provider()`）。
	SceneManager.set_return_data_provider(_return_data)
	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.TRAINING)
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.material_changed.connect(_on_material_changed)

	_build_chips()
	var holder: TiltedSheet = TiltedSheet.create(0)
	holder.name = "DossierHolder"
	holder.sheet.custom_minimum_size.x = float(get_theme_constant(&"dossier_width", THEME_TYPE))
	_dossier = CharacterDossier.new()
	_dossier.name = "Dossier"
	holder.sheet.add_child(_dossier)
	body.add_child(holder)
	body.move_child(holder, 0)

	_tabs = PaperTabs.new()
	_tabs.name = "Tabs"
	_tabs.tab_changed.connect(_on_tab_changed)
	right.add_child(_tabs)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Page"
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sheet)
	_page = VBoxContainer.new()
	_page.name = "PageBody"
	sheet.add_child(_page)

	# ⚠ キャラを渡されて開いたときはその人から（⚠ 昇級から戻るとき）。⚠ 無ければ編成の先頭。
	var data: Dictionary = SceneManager.consume_transfer_data()
	var passed_id: String = str(data.get(TransferKeys.CHARACTER_ID, ""))
	if passed_id == "" or MasterDataLoader.get_character(passed_id).is_empty():
		passed_id = _default_character()
	_tab = str(data.get(TransferKeys.TRAINING_TAB, TransferKeys.TRAINING_TAB_OVERVIEW))
	_select_character(passed_id)


# --- キャラの札（右上） ---

func _build_chips() -> void:
	_chips = HBoxContainer.new()
	_chips.name = "Chips"
	_chips.theme_type_variation = &"TrainingChips"
	var spacer: Control = Control.new()
	spacer.name = "ChipSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	header.add_child(_chips)
	# ⚠ 右の HUD の場所は空けたまま（⚠ `ScreenHeader.hud_spacer` を一番右に残す）。
	if header.hud_spacer != null:
		header.move_child(header.hud_spacer, header.get_child_count() - 1)
	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに（⚠ 本部の右上の素材16件はやめた）。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX))


func _rebuild_chips() -> void:
	for child: Node in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	var side: int = get_theme_constant(&"chip", THEME_TYPE)
	var debug_alpha: float = float(get_theme_constant(&"chip_debug_alpha_pct", THEME_TYPE)) / 100.0
	for character_id: String in _character_order():
		var chip: CharacterAvatar = CharacterAvatar.create(character_id, side)
		chip.name = "Chip_" + character_id
		chip.tooltip_text = tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))
		if GameManager.is_debug_character(character_id):
			chip.modulate.a = debug_alpha
		if character_id == _selected_id:
			chip.set_border(get_theme_color(&"chip_selected", THEME_TYPE), get_theme_constant(&"chip_border", THEME_TYPE))
		UiButton.attach_hit(chip, _select_character.bind(character_id))
		_chips.add_child(chip)


# ⚠ 本番のキャラ → 検証用（⚠ 検証用はリリースビルドでは出さない＝編成の候補と同じ扱い）。
func _character_order() -> Array[String]:
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


func _default_character() -> String:
	var party: Array = GameManager.get_party_members()
	for member: Variant in party:
		if str(member) != "":
			return str(member)
	var order: Array[String] = _character_order()
	return order[0] if not order.is_empty() else ""


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	_notice_text = ""
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	header.set_subtitle_text(tr(str(char_data.get("name_key", ""))))
	_rebuild_chips()
	_dossier.setup(character_id)
	# ⚠ 装備のタブは装備が解放されてから（段階解放・GAME_DESIGN.md 9-5 の #2。⚠ 「出さない」）。
	_tab_ids.clear()
	var keys: Array[String] = []
	for i: int in TAB_IDS.size():
		if TAB_IDS[i] == TransferKeys.TRAINING_TAB_EQUIP and not GameManager.is_screen_unlocked(GameStateKeys.SCREEN_EQUIPMENT):
			continue
		_tab_ids.append(TAB_IDS[i])
		keys.append(TAB_KEYS[i])
	if not (_tab in _tab_ids):
		_tab = TransferKeys.TRAINING_TAB_OVERVIEW
	_tabs.set_tabs(keys, _tab_ids.find(_tab))
	_rebuild_page()


# --- タブ ---

func _on_tab_changed(index: int) -> void:
	_tab = _tab_ids[index]
	_notice_text = ""
	_rebuild_page()


func _open_tab(tab_id: String) -> void:
	var index: int = _tab_ids.find(tab_id)
	if index < 0:
		return
	_tabs.current = index
	_on_tab_changed(index)


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _rebuild_page() -> void:
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_build_picker = null
	match _tab:
		TransferKeys.TRAINING_TAB_NODES:
			var nodes: TrainingNodesPage = TrainingNodesPage.new()
			nodes.name = "NodesPage"
			nodes.setup(_selected_id)
			_page.add_child(nodes)
		TransferKeys.TRAINING_TAB_SKILLS:
			var skills: TrainingSkillsPage = TrainingSkillsPage.new()
			skills.name = "SkillsPage"
			skills.setup(_selected_id)
			_page.add_child(skills)
		TransferKeys.TRAINING_TAB_EQUIP:
			var equip: TrainingEquipPage = TrainingEquipPage.new()
			equip.name = "EquipPage"
			equip.setup(_selected_id)
			equip.forge_requested.connect(_on_forge_requested)
			_page.add_child(equip)
		_:
			_build_overview()


# --- 概要（手本 Character） ---

func _build_overview() -> void:
	var overview: VBoxContainer = VBoxContainer.new()
	overview.name = "OverviewPage"
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(overview)

	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_training_tab_overview"
	heading.ornament = true
	overview.add_child(heading)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	overview.add_child(rows)
	var remaining: int = GameManager.get_stat_node_remaining_points(_selected_id)
	rows.add_child(_create_overview_row(
		"ui_training_nodes", IconTextures.for_screen(GameStateKeys.SCREEN_TRAINING),
		tr("ui_training_points_value") % remaining, remaining > 0, TransferKeys.TRAINING_TAB_NODES
	))
	rows.add_child(_create_overview_row(
		"ui_training_skill", _skill_icon(),
		"%d / %d" % [_selected_skill_count(), GameManager.get_skill_slot_count()], false,
		TransferKeys.TRAINING_TAB_SKILLS
	))
	if TransferKeys.TRAINING_TAB_EQUIP in _tab_ids:
		rows.add_child(_create_overview_row(
			"ui_training_equipment", IconTextures.for_screen(GameStateKeys.SCREEN_EQUIPMENT),
			"%d / %d" % [_equipped_count(), GameManager.get_equip_slots().size()], false,
			TransferKeys.TRAINING_TAB_EQUIP
		))

	overview.add_child(_build_application())

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview.add_child(spacer)
	if _notice_text != "":
		var notice: Label = Label.new()
		notice.name = "NoticeLabel"
		notice.theme_type_variation = &"AccentLabel"
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.text = _notice_text
		overview.add_child(notice)
	overview.add_child(HSeparator.new())
	overview.add_child(_build_preset_row())


# 「[絵] ステータスノード ………… 0 pt ›」。⚠ 押すとそのタブを開く。
func _create_overview_row(label_key: String, texture: Texture2D, value_text: String, accent: bool, tab_id: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Row_" + tab_id
	row.pressed.connect(_open_tab.bind(tab_id))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	if texture != null:
		var side: float = float(get_theme_constant(&"row_icon", THEME_TYPE))
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(side, side)
		icon.modulate = get_theme_color(&"row_icon", THEME_TYPE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
	var label: Label = Label.new()
	label.name = "NameLabel"
	label.theme_type_variation = &"SheetHeadingLabel"
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	# ⚠ 「まだ振っていないポイントが在る」だけ強調（⚠ 次にやることを1つに絞る）。
	value.theme_type_variation = &"AccentLabel" if accent else &""
	value.text = value_text
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(value)
	var chevron: Label = Label.new()
	chevron.theme_type_variation = &"CaptionLabel"
	chevron.text = tr("ui_common_chevron")
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(chevron)
	return row


# 「昇級の申請」：1 → 2 ／ 必要なもの 修練の証 3 / 57 ／ [昇級させる]。
# ⚠ 判定は前の詳細と同じ2つ（⚠ 上限 ／ 素材）。⚠ 押せてから失敗するより、押せないほうが分かりやすい。
func _build_application() -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.name = "Application"
	var caption: Label = Label.new()
	caption.theme_type_variation = &"SectionLabel"
	caption.text = tr("ui_training_apply_header")
	block.add_child(caption)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ApplicationPanel"
	block.add_child(panel)
	var line: HBoxContainer = HBoxContainer.new()
	panel.add_child(line)

	var level: int = _level_of(_selected_id)
	var cap: int = GameManager.get_effective_level_cap(_selected_id)
	var at_cap: bool = level >= cap
	var arrow: Label = Label.new()
	arrow.name = "LevelArrow"
	arrow.theme_type_variation = &"LevelArrowLabel"
	arrow.text = str(level) if at_cap else tr("ui_training_level_arrow") % [level, level + 1]
	line.add_child(arrow)
	line.add_child(VSeparator.new())

	var need: VBoxContainer = VBoxContainer.new()
	need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	need.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(need)
	var need_caption: Label = Label.new()
	need_caption.theme_type_variation = &"CaptionLabel"
	need_caption.text = tr("ui_training_need_header")
	need.add_child(need_caption)
	var need_value: Label = Label.new()
	need_value.name = "NeedLabel"
	var enough: bool = false
	if at_cap:
		need_value.text = tr("ui_training_max_level")
	else:
		var cost: Dictionary = GameManager.get_level_up_cost(_selected_id)
		var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
		var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
		var owned: int = GameManager.get_material_count(material_id)
		enough = owned >= amount
		need_value.theme_type_variation = &"" if enough else &"ErrorLabel"
		need_value.text = tr("ui_training_need_value") % [tr("ui_res_" + material_id), amount, owned]
	need.add_child(need_value)
	# ⚠ 「入手先を見る」は 10-07 に外した（⚠ 人間「⚠ 減らして」）＝足りないまま「昇級させる」を押すと窓・見出しの素材の「＋」。

	var button: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_training_apply")
	button.name = "LevelUpButton"
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# ⚠ 10-07（人間「⚠ プラスボタン押さなくても　例えば必要な素材を提示する画面などがあれば」・`NAV-19`）：⚠ 足りなくても押せる＝押すと入手先の窓。
	button.disabled = at_cap
	button.pressed.connect(_on_level_up_pressed)
	line.add_child(button)
	return block


# 「ビルド [ビルド1 ▼] [焼く] [適用]」。
func _build_preset_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PresetRow"
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_training_build")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	_build_picker = OptionButton.new()
	_build_picker.name = "BuildPicker"
	_build_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 接続は項目を入れる前でよい（add_item / select は item_selected を出さない）。
	_build_picker.item_selected.connect(_on_build_selected)
	row.add_child(_build_picker)
	var burn: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_party_preset_burn")
	burn.name = "BurnButton"
	burn.tooltip_text = tr("ui_party_preset_burn_hint")
	burn.pressed.connect(_on_burn_pressed)
	row.add_child(burn)
	var apply: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_party_preset_apply")
	apply.name = "ApplyButton"
	apply.tooltip_text = tr("ui_party_preset_apply_hint")
	apply.pressed.connect(_on_apply_pressed)
	row.add_child(apply)
	_refresh_preset_row()
	return row


# 選択肢の「（空き）」表示を、いまの保存状態に合わせて作り直す。
func _refresh_preset_row() -> void:
	if _build_picker == null or _selected_id == "":
		return
	var presets: Array = GameManager.get_character_presets(_selected_id)
	var count: int = GameManager.get_character_preset_count()
	if _selected_build >= count:
		_selected_build = 0
	_build_picker.clear()
	for i: int in range(count):
		var label: String = tr("ui_party_preset_build") % (i + 1)
		var entry: Variant = presets[i] if i < presets.size() else null
		var saved: bool = entry is Dictionary and bool((entry as Dictionary).get(GameStateKeys.PRESET_SAVED, false))
		if not saved:
			label += "（%s）" % tr("ui_party_preset_empty")
		_build_picker.add_item(label)
	_build_picker.select(_selected_build)


func _on_build_selected(item_index: int) -> void:
	# ⚠ ここでは状態を触らない。焼く先が変わるだけ。
	_selected_build = item_index


func _on_burn_pressed() -> void:
	if not GameManager.save_character_preset(_selected_id, _selected_build):
		# 失敗の理由は GameManager 側が push_error 済み。
		return
	# ⚠ 保存したことが分かる合図を出す。出さないと「押しても何も起きない」に見える。
	_notice_text = tr("ui_party_preset_burned") % (_selected_build + 1)
	_rebuild_page()


# ビルドを当て直す。⚠ 編成は触らない（このキャラの中身だけ）。
func _on_apply_pressed() -> void:
	var report: Dictionary = GameManager.apply_character_preset(_selected_id, _selected_build)
	# ⚠ 文面は GameManager が組む（適用の口が3つあるため）。
	_notice_text = GameManager.format_apply_report(report)
	_rebuild_page()


# --- 操作 ---

# ⚠ 昇級は申請書の画面で行う（人間「⚠ 3あ」）。⚠ ここでは上げない。
func _on_level_up_pressed() -> void:
	var cost: Dictionary = GameManager.get_level_up_cost(_selected_id)
	if ItemSourceWindow.open_if_short(self, str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, "")),
			int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0)), _return_data()):
		return
	SceneManager.open_detour(LEVEL_UP_PATH, {TransferKeys.CHARACTER_ID: _selected_id}, TRAINING_PATH, _return_data())


# ⚠ 2026-09-27（人間「⚠ 3あ」）：⚠ 鍛冶場をその品を選んだ状態で開く（⚠ 前は持ち物を開いていた）。
#   ⚠ 10-06（`NAV-18`）：⚠ 寄り道で開く＝鍛冶場の「戻る」でこのキャラの装備タブへ戻る（⚠ 前は本部へ飛んだ）。
func _on_forge_requested(instance_id: String) -> void:
	SceneManager.open_detour(FORGE_PATH, {TransferKeys.FORGE_INSTANCE_ID: instance_id}, TRAINING_PATH, _return_data())


# ⚠ 寄り道から戻ったときに、⚠ いまのキャラとタブで開き直すためのデータ。
func _return_data() -> Dictionary:
	return {TransferKeys.CHARACTER_ID: _selected_id, TransferKeys.TRAINING_TAB: _tab}


# ⚠ 2026-09-27（人間「⚠ 3あ」）：⚠ 戻る先は育成の一覧（⚠ 身上書カード）。
# ⚠ 10-06（`NAV-18`）：⚠ 寄り道で来た（⚠ 記録・詰所・出撃の準備から）なら来た画面へ。
func _on_back_pressed() -> void:
	SceneManager.go_back_or(LIST_PATH)


# --- シグナル ---

# ⚠ 身上書は値が変わるたびに描き直す（⚠ 装備・割り振りで値が変わる）。⚠ タブの中身は自分で受ける。
func _on_character_growth_changed(character_id: String) -> void:
	if character_id != _selected_id:
		return
	_dossier.setup(_selected_id)
	if _tab == TransferKeys.TRAINING_TAB_OVERVIEW:
		_rebuild_page()


func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	if _tab == TransferKeys.TRAINING_TAB_OVERVIEW:
		_rebuild_page()


# --- 内部ヘルパー ---

func _level_of(character_id: String) -> int:
	return int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))


func _selected_skill_count() -> int:
	var count: int = 0
	for entry: Variant in GameManager.get_selected_skills(_selected_id, GameManager.SLOT_KIND_SKILL):
		if str(entry) != "":
			count += 1
	return count


# ⚠ スキルの行の絵は、いま持ち込んでいる1つ目のスキルの絵（⚠ 無ければ絵なし）。
func _skill_icon() -> Texture2D:
	for entry: Variant in GameManager.get_selected_skills(_selected_id, GameManager.SLOT_KIND_SKILL):
		if str(entry) != "":
			return IconTextures.for_skill(str(entry))
	return null


func _equipped_count() -> int:
	var count: int = 0
	for slot: String in GameManager.get_equip_slots():
		if GameManager.get_equipped_instance_id(_selected_id, slot) != "":
			count += 1
	return count


