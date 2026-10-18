# res://scenes/guild/training_screen.gd
# ギルド：育成画面。
#
# ⚠⚠ 2026-09-27（回UI-組 育成・手本 Character / Nodes / Skills / Equip）：⚠ **作り替えた**。
#   ⚠ 左に身上書（`CharacterDossier`）・右に紙のタブ4枚（概要・ステータスノード・スキル・装備）。
#   ⚠ ~~右上にキャラの札~~ ⚠⚠ 10-18（回UI-1018-4・web版の手本・人間「⚠ ステータスノードの上側にキャラのアイコンがあるがそれはいらない」）：
#   ⚠ 札の列はやめた ＝ ⚠ 身上書の一番上の「◀ 前の人｜n / 18 人・一覧へ｜次の人 ▶」で切り替える。
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

var _dossier: CharacterDossier = null
var _tip: ItemTipCard = null
var _tabs: PaperTabs = null
var _page: VBoxContainer = null

# ビルド（キャラプリセット）の行（EXEC_PARTY_PRESETS.md）。
# ⚠ 判定も文面も GameManager 側の1本を通る。⚠ ここに書いてあるのは器の組み立てだけ。
# ⚠ 「焼く」と「適用」は向きが逆（焼く＝現在→ビルド／適用＝ビルド→現在）。⚠ 1つのボタンにまとめないこと。
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

	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに（⚠ 本部の右上の素材16件はやめた）。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX))
	_tip = ItemTipCard.attach(self)
	var holder: TiltedSheet = TiltedSheet.create(0)
	holder.name = "DossierHolder"
	holder.sheet.custom_minimum_size.x = float(get_theme_constant(&"dossier_width", THEME_TYPE))
	_dossier = CharacterDossier.new()
	_dossier.name = "Dossier"
	_dossier.tip = _tip
	_dossier.prev_pressed.connect(_on_nav.bind(-1))
	_dossier.next_pressed.connect(_on_nav.bind(1))
	_dossier.list_pressed.connect(_on_list_pressed)
	_dossier.loadout_pressed.connect(_on_loadout_pressed)
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
	var order: Array[String] = _character_order()
	var at: int = order.find(character_id)
	_dossier.prev_id = order[at - 1] if at > 0 else ""
	_dossier.next_id = order[at + 1] if at >= 0 and at + 1 < order.size() else ""
	_dossier.nav_index = at + 1
	_dossier.nav_total = order.size()
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
	_refresh_badges()
	_rebuild_page()


# ⚠ 「ステータスノード ③」（⚠ 振っていない点の数・手本 `02_training_nd.png`）。
func _refresh_badges() -> void:
	var index: int = _tab_ids.find(TransferKeys.TRAINING_TAB_NODES)
	if index >= 0:
		_tabs.set_badge(index, GameManager.get_stat_node_remaining_points(_selected_id))


# ⚠ 身上書の ◀ ▶（⚠ 並びは `_character_order()`）。⚠ タブはそのまま。
func _on_nav(step: int) -> void:
	var order: Array[String] = _character_order()
	var at: int = order.find(_selected_id) + step
	if at < 0 or at >= order.size():
		return
	_select_character(order[at])


func _on_list_pressed() -> void:
	SceneManager.swap_scene(LIST_PATH)


func _on_loadout_pressed(kind: String) -> void:
	_open_tab(TransferKeys.TRAINING_TAB_SKILLS if kind == LoadoutIcons.KIND_SKILL else TransferKeys.TRAINING_TAB_EQUIP)


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
			# ⚠ 10-16：⚠ 通常攻撃とパッシブの欄を足して紙の下からはみ出した＝⚠ 縦に送る（⚠ 横は送らない）。
			var skills_scroll: ScrollContainer = ScrollContainer.new()
			skills_scroll.name = "SkillsScroll"
			skills_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			skills_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			skills_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skills_scroll.add_child(skills)
			_page.add_child(skills_scroll)
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
	heading.right_text = tr("ui_training_overview_hint")
	overview.add_child(heading)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	overview.add_child(rows)
	rows.add_child(_build_overview_nodes())
	var skill_icons: LoadoutIcons = LoadoutIcons.skills(_selected_id, get_theme_constant(&"loadout_icon", THEME_TYPE))
	var skill_names: Array[String] = []
	for raw: Variant in GameManager.get_selected_skills(_selected_id):
		if raw != null and str(raw) != "":
			skill_names.append(tr(str(MasterDataLoader.get_skill(str(raw)).get("name_key", ""))))
	rows.add_child(_create_overview_row("ui_training_skill", skill_icons, tr("ui_barracks_skill_separator").join(skill_names),
		"%d / %d" % [_selected_skill_count(), GameManager.get_skill_slot_count()], TransferKeys.TRAINING_TAB_SKILLS))
	if TransferKeys.TRAINING_TAB_EQUIP in _tab_ids:
		var equip_icons: LoadoutIcons = LoadoutIcons.equipment(_selected_id, get_theme_constant(&"loadout_icon", THEME_TYPE), _tip)
		rows.add_child(_create_overview_row("ui_training_equipment", equip_icons, "",
			"%d / %d" % [_equipped_count(), GameManager.get_equip_slots().size()], TransferKeys.TRAINING_TAB_EQUIP))

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


# 「▷ ステータスノード　振った 7 pt・残り 3 pt …… 押して振る ›」＋ 振った軸の札（「[♡ +5] HP 4 pt +20」）。
func _build_overview_nodes() -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Row_" + TransferKeys.TRAINING_TAB_NODES
	row.pressed.connect(_open_tab.bind(TransferKeys.TRAINING_TAB_NODES))
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var title: Label = Label.new()
	title.name = "NameLabel"
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_training_nodes")
	head.add_child(title)
	var remaining: int = GameManager.get_stat_node_remaining_points(_selected_id)
	var used: int = 0
	var all_nodes: Dictionary = MasterDataLoader.get_all_character_nodes()
	var per_stat: Dictionary = {}
	for raw: Variant in GameManager.get_stat_nodes(_selected_id):
		var definition: Dictionary = all_nodes.get(str(raw), {})
		var cost: int = int(definition.get(GameManager.STAT_NODE_COST, 0))
		used += cost
		var stat_key: String = str(definition.get(GameManager.STAT_NODE_STAT, ""))
		var bucket: Array = per_stat.get(stat_key, [0, 0])
		per_stat[stat_key] = [int(bucket[0]) + cost, int(bucket[1]) + int(definition.get(GameManager.STAT_NODE_VALUE, 0))]
	var points: Label = Label.new()
	points.name = "ValueLabel"
	points.theme_type_variation = &"AccentLabel" if remaining > 0 else &"CaptionLabel"
	points.text = tr("ui_training_overview_points") % [used, remaining]
	points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(points)
	var go: Label = Label.new()
	go.theme_type_variation = &"CaptionLabel"
	go.text = tr("ui_training_overview_go_nodes")
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(go)
	if per_stat.is_empty():
		return row
	var chips: HFlowContainer = HFlowContainer.new()
	chips.name = "NodeChips"
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(chips)
	for stat_key: Variant in per_stat:
		var bucket: Array = per_stat[stat_key]
		var chip: PanelContainer = PanelContainer.new()
		chip.name = "NodeChip_" + str(stat_key)
		chip.theme_type_variation = &"NodeChipPanel"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(chip)
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(line)
		var step_value: int = int(GameManager.get_stat_node_step_value(_selected_id, str(stat_key)))
		line.add_child(StatNodeCell.create(str(stat_key), step_value, get_theme_constant(&"node_chip_cell", THEME_TYPE), false))
		var texts: VBoxContainer = VBoxContainer.new()
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(texts)
		var spent: Label = Label.new()
		spent.theme_type_variation = &"CaptionLabel"
		spent.text = tr("ui_training_overview_chip") % [tr("ui_training_stat_" + str(stat_key)), int(bucket[0])]
		texts.add_child(spent)
		var total: Label = Label.new()
		total.theme_type_variation = &"GainLabel"
		total.text = BelongingsDetail.stat_text(str(stat_key), int(bucket[1]))
		texts.add_child(total)
	return row


# 「[絵] スキル　強撃・横薙ぎ ……… 2 / 2 ›」。⚠ 押すとそのタブを開く。⚠ 絵は持ち物の並び（`LoadoutIcons`）。
func _create_overview_row(label_key: String, icons: Control, note_text: String, value_text: String, tab_id: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Row_" + tab_id
	row.pressed.connect(_open_tab.bind(tab_id))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(line)
	if icons != null:
		icons.custom_minimum_size.x = float(get_theme_constant(&"overview_icons", THEME_TYPE))
		line.add_child(icons)
	var label: Label = Label.new()
	label.name = "NameLabel"
	label.theme_type_variation = &"SheetHeadingLabel"
	label.text = tr(label_key)
	line.add_child(label)
	var note: Label = Label.new()
	note.theme_type_variation = &"CaptionLabel"
	note.text = note_text
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_child(note)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.theme_type_variation = &"DossierLevelLabel"
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
	# ⚠ 10-07（人間「⚠ しおり紐は気づいたんだけど　そこから言ったページで何を見ればいいのかわかんなかった」）：⚠ 上げられるなら「昇級させる」に紐。
	RibbonMark.set_on(button, GameManager.can_level_up_now(_selected_id))
	line.add_child(button)
	return block


# 「ビルド [1][2][3 ＋] 押すと切り替わる（詰所と同じ） …… [いまの形をビルドに残す]」（⚠ 手本 `02_training_ov.png`）。
# ⚠ 押すとそのビルドを当てる（`apply_character_preset()`）。⚠ 空きのビルドを押すと、いまの形をそこへ残す。
# ⚠ いまの形と同じ中身のビルドが真鍮（`get_matching_character_preset()`＝セーブに持たない）。
# ⚠ 「いまの形をビルドに残す」＝ ⚠ 同じ中身のビルドが在ればそこ・無ければ最後に押したビルド（⚠ 既定は1）。
func _build_preset_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PresetRow"
	var caption: Label = Label.new()
	caption.theme_type_variation = &"SheetHeadingLabel"
	caption.text = tr("ui_training_build")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var presets: Array = GameManager.get_character_presets(_selected_id)
	var matching: int = GameManager.get_matching_character_preset(_selected_id)
	for i: int in range(GameManager.get_character_preset_count()):
		var saved: bool = bool((presets[i] as Dictionary).get(GameStateKeys.PRESET_SAVED, false))
		var button: Button = UiButton.create_paper_choice("")
		button.name = "Build_%d" % i
		button.text = tr("ui_training_build_slot") % (i + 1) if saved else tr("ui_training_build_empty") % (i + 1)
		if i == matching:
			button.theme_type_variation = &"PaperChoiceApplied"
		button.pressed.connect(_on_build_pressed.bind(i, saved))
		row.add_child(button)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr("ui_training_build_hint")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	var burn: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_training_build_save")
	burn.name = "BurnButton"
	burn.tooltip_text = tr("ui_party_preset_burn_hint")
	burn.pressed.connect(_on_burn_pressed)
	row.add_child(burn)
	return row


# ⚠ 押したビルドを当てる（⚠ 空きなら、いまの形を残す）。
func _on_build_pressed(index: int, saved: bool) -> void:
	_selected_build = index
	if not saved:
		_on_burn_pressed()
		return
	var report: Dictionary = GameManager.apply_character_preset(_selected_id, index)
	# ⚠ 文面は GameManager が組む（適用の口が3つあるため）。
	_notice_text = GameManager.format_apply_report(report)
	_dossier.setup(_selected_id)
	_refresh_badges()
	_rebuild_page()


func _on_burn_pressed() -> void:
	var matching: int = GameManager.get_matching_character_preset(_selected_id)
	var index: int = matching if matching >= 0 else _selected_build
	if not GameManager.save_character_preset(_selected_id, index):
		# 失敗の理由は GameManager 側が push_error 済み。
		return
	# ⚠ 保存したことが分かる合図を出す。出さないと「押しても何も起きない」に見える。
	_notice_text = tr("ui_party_preset_burned") % (index + 1)
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
	# ⚠ 10-18（回UI-1018-3）：⚠ 鍛冶場の見出しに「◯◯の装備から来た」・戻るは「育成に戻る」＝キャラを渡す。
	SceneManager.open_detour(FORGE_PATH, {TransferKeys.FORGE_INSTANCE_ID: instance_id, TransferKeys.CHARACTER_ID: _selected_id}, TRAINING_PATH, _return_data())


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
	_refresh_badges()
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


func _equipped_count() -> int:
	var count: int = 0
	for slot: String in GameManager.get_equip_slots():
		if GameManager.get_equipped_instance_id(_selected_id, slot) != "":
			count += 1
	return count


