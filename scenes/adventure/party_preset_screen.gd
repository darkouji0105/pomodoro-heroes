# res://scenes/adventure/party_preset_screen.gd
# 出撃の準備 ／ 詰所（⚠ 1つの画面・⚠ ファイル名はパーティ選択のまま）。
#
# ⚠⚠ 2026-09-28（モック `docs/pomodoro-heroes-ui-docs/barracks/`・決定 `NAV-11`）：⚠ **作り替えた**。
#   ⚠ 人間「⚠ 出撃前の画面を用意　⚠ プリセットに応じて決めたり、この画面で決めたり」「⚠ キャラを選んで入れ替えるってのが大事」
#     「⚠ キャラの配置とキャラ個別のものはべつにしよう」→ 答え「⚠ 1い　⚠ 2あ　⚠ 3い　⚠ 4あ」。
#   ⚠ 依頼掲示板から開く（`TransferKeys.SORTIE_STAGE_ID` ／ `SORTIE_DUNGEON_ID`）＝「出撃の準備」：⚠ 上の帯に依頼 ／ 右下に「出撃する」。
#     ⚠ 周回は通さない（⚠ 09-28 人間「⚠ 周回の時は編成画面はいらない」＝掲示板でその場で回す）。
#   ⚠ 施設の帯から開く（⚠ どちらも無い）＝「詰所」：⚠ 右下に「選んだ人を育成で開く」（⚠ モック Q1 A案）。
#   ⚠ 3つの枠（傾いた紙）：番号・写真・名前・役割・Lv・HP の棒・主な値・「ビルド ▼」・「押すと入れ替え」。
#   ⚠ 枠を押す → 下の名簿から選ぶ（⚠ 出ている人を選ぶと入れ替わる）。⚠ 名簿は Lv か名前で並べる（⚠ 役割で絞るのは「⚠ 3い」＝まだ）。
#   ⚠ 右に編成の控え（8件）：3人の顔・「いまと同じ」の判 ／ 「呼ぶ」（⚠ 並び・ビルド・装備が移るを予告する窓を通す）・「いまを残す」。
#   ⚠ 名前（控えの「ボス用」・ビルドの「支える」）は入れない（⚠ 人間「⚠ 1い」）。
#   ⚠ はじめてのガイド（⚠ 人間「⚠ 2あ」）：初めて開いたときだけ（`SortieGuide`・`GameManager.GUIDE_SORTIE`）。
#   ⚠ 難ダンジョンも同じ画面（⚠ 人間「⚠ 4あ」）。⚠ 新しく入るときは右の欄の上に「潜る深さ」（⚠ 10-03・決定49・モック Q8 A案）。
#   ⚠ 「ビルド ▼」は選ぶと**そのビルドを当てる**（⚠ 出撃前の画面なので、選んだものが戦闘に効かないと意味が無い。⚠ 中身の無いビルドは選べない）。
# ⚠ 出撃の手続き（⚠ 解放・スタミナ・フロア・戦闘・難ダンジョン）は前は掲示板にあった。⚠ ここへ移した（⚠ 判定は GameManager の口のまま）。
# ⚠ 装備を選ぶ欄は作らない（GAME_DESIGN 13章「装備の変更はできない。ギルドで行う」）。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。remove_child() してから queue_free()。

extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const PARTY_PRESET_PATH: String = "res://scenes/adventure/party_preset_screen.tscn"
const THEME_TYPE: StringName = &"Sortie"
const TRAINING_THEME_TYPE: StringName = &"Training"
const POSITION_KEYS: Array[String] = ["ui_sortie_front", "ui_sortie_middle", "ui_sortie_back"]
const SORT_LEVEL: String = "level"
const SORT_NAME: String = "name"
const SORT_POWER: String = "power"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var strip_body: HBoxContainer = $Margin/Layout/Strip/Body
@onready var slots_box: HBoxContainer = $Margin/Layout/Middle/Slots
@onready var side: VBoxContainer = $Margin/Layout/Middle/Side
@onready var roster_body: HBoxContainer = $Margin/Layout/Roster/Body

# 「戻る」で帰る先。入口が2つあるので来た側が渡す（TransferKeys.RETURN_PATH）。
var _return_path: String = BASE_PATH
# ⚠ 受けた依頼（⚠ どちらも空なら詰所）。
var _stage_id: String = ""
var _dungeon_id: String = ""
# ⚠ 名簿から入れる先の枠（⚠ -1 なら選んでいない）／ ⚠ 控えで選んでいる行。
var _pick: int = -1
var _preset_pick: int = 0
var _sort: String = SORT_LEVEL
# ⚠ 名簿の役割の絞り込み（⚠ 空＝すべて・10-18）。
var _role_filter: String = ""
# ⚠ 帯の右に出す結果の1行（⚠ 空なら出さない）。
var _message: String = ""
var _message_error: bool = false
# ⚠ 詰所で最後に押した名簿の人（⚠ 「選んだ人を育成で開く」の相手・⚠ 無ければ1番の人）。
var _roster_pick: String = ""
# ⚠ 出撃の署名（⚠ 出撃の準備だけ）：枠ごとの署名の行・帯の「受理」の判・書いている最中か・流している Tween・押すと飛ばす幕。
var _signatures: Array[SortieSignature] = []
var _stamp: Stamp = null
var _signing: bool = false
var _sign_tween: Tween = null
var _sign_blocker: Control = null
# ⚠ 難ダンジョンに入るフロア（⚠ 0＝まだ選んでいない＝最深の次・決定49）。⚠ 状態には無い（⚠ 出撃するときに渡す）。
var _start_floor: int = 0


func _ready() -> void:
	# ⚠ 10-07：⚠ 入手先の窓から戻ってきたときの姿を預ける（`SceneManager.set_return_data_provider()`）。
	SceneManager.set_return_data_provider(_source_return_data)
	var data: Dictionary = SceneManager.consume_transfer_data()
	var path: String = str(data.get(TransferKeys.RETURN_PATH, ""))
	if path != "":
		_return_path = path
	_stage_id = str(data.get(TransferKeys.SORTIE_STAGE_ID, ""))
	_dungeon_id = str(data.get(TransferKeys.SORTIE_DUNGEON_ID, ""))
	_start_floor = int(data.get(TransferKeys.SORTIE_START_FLOOR, 0))
	# ⚠ 10-07（H）：⚠ 名簿の並べ替えを覚える。
	_sort = str(SceneManager.recall(TransferKeys.MEMORY_ROSTER_SORT, _sort))
	_role_filter = str(SceneManager.recall(TransferKeys.MEMORY_ROSTER_ROLE, ""))
	header.back_pressed.connect(_on_back_pressed)
	if _is_barracks():
		header.set_subtitle_text(tr("ui_sortie_barracks_subtitle"))
		# ⚠ 拠点から来たときだけ施設の帯を出す（⚠ 詰所）。
		if _return_path == BASE_PATH:
			BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.BARRACKS)
	else:
		header.title_key = "ui_sortie_title"
		header.set_subtitle_text(tr("ui_dungeon_section") if _dungeon_id != "" else tr("ui_barracks_sortie"))
	side.custom_minimum_size.x = float(get_theme_constant(&"roster_width", THEME_TYPE))
	# ⚠ 10-18（回UI-1018-5）：⚠ 下の板は「編成の控え」の紙（⚠ 名簿は右へ移った）。
	($Margin/Layout/Roster as PanelContainer).theme_type_variation = &"SortiePaperPanel"
	($Margin/Layout/Roster as PanelContainer).theme = PaperSheet.PAPER_THEME
	_rebuild()
	# ⚠ はじめてのガイド（⚠ 人間「⚠ 2あ」）。⚠ 並べ終わってから穴の位置を取る。
	if not GameManager.is_guide_seen(GameManager.GUIDE_SORTIE):
		_open_guide.call_deferred()
	# ⚠ 10-06（人間「⚠ ３はどっちも行う」）：⚠ 掲示板の「すぐ出撃」＝開いたらそのまま「出撃する」と同じ口を通す
	#   （⚠ 「受ける」から右下の「出撃する」まで約900px 動かしていた）。⚠ 出られなければこの画面に理由が出る。
	#   ⚠ ガイドを見ていない人は止める（⚠ はじめは準備の画面を見せる）。
	elif bool(data.get(TransferKeys.SORTIE_AUTO_GO, false)) and not _is_barracks():
		_on_sortie_pressed.call_deferred()


func _is_barracks() -> bool:
	return _stage_id == "" and _dungeon_id == ""


func _rebuild() -> void:
	# ⚠ 10-18：⚠ 名簿・控えを押しても先頭へ戻らない（`ScrollKeeper`）。
	var kept: Dictionary = ScrollKeeper.capture(self)
	SlotActionPopover.close_in(self)
	_rebuild_strip()
	_rebuild_slots()
	_rebuild_side()
	_rebuild_roster()
	ScrollKeeper.restore(self, kept)


func _clear(box: Node) -> void:
	# ⚠ queue_free() だけだと、同じフレームに2本作ると行が二重に並ぶ（AGENTS.md）。
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _name_of(character_id: String) -> String:
	return tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))


func _role_of(character_id: String) -> String:
	# ⚠ 役割は `characters.json` に欄が無い。⚠ 検証用はIDをそのまま出す（⚠ 身上書と同じ）。
	return character_id if GameManager.is_debug_character(character_id) else tr("ui_role_" + character_id)


func _level_of(character_id: String) -> int:
	return int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))


# ⚠ いまの形と同じ中身のビルド（⚠ 10-18 からセーブの写しを持たない＝`get_matching_character_preset()`）。⚠ 無ければ -1。
func _build_of(character_id: String) -> int:
	return GameManager.get_matching_character_preset(character_id)


func _say(text: String, error: bool = false) -> void:
	_message = text
	_message_error = error
	_rebuild_strip()


# --- 上の帯（依頼 ／ 詰所の案内） ---------------------------------------

func _rebuild_strip() -> void:
	_clear(strip_body)
	_stamp = null
	if _is_barracks():
		var tag: Label = Label.new()
		tag.theme_type_variation = &"CaptionLabel"
		tag.text = tr("ui_sortie_barracks_tag")
		strip_body.add_child(tag)
		var note: Label = Label.new()
		note.theme_type_variation = &"SmallLabel"
		note.text = tr("ui_sortie_barracks_note")
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip_body.add_child(note)
	else:
		var kind: Label = Label.new()
		kind.theme_type_variation = &"CaptionLabel"
		kind.text = tr("ui_quest_tab_hard") if _dungeon_id != "" else tr("ui_quest_tab_normal")
		strip_body.add_child(kind)
		var title: Label = Label.new()
		title.name = "QuestTitle"
		title.theme_type_variation = &"SheetHeadingLabel"
		title.text = _quest_title()
		strip_body.add_child(title)
		if _stage_id != "":
			var cost: Label = Label.new()
			# ⚠ 10-07（人間「⚠ 足りないボタンは不足とは出さないで数字の色で」）：⚠ スタミナが足りなければ数字を赤に。
			var stamina_cost: int = int(Balance.adventure.stamina_cost_per_stage)
			cost.name = "StaminaCostLabel"
			cost.theme_type_variation = &"SmallLabel" if GameManager.get_resource_amount(GameStateKeys.STAMINA) >= stamina_cost else &"SmallErrorLabel"
			cost.text = tr("ui_sortie_stamina") % stamina_cost
			strip_body.add_child(cost)
		elif not GameManager.is_in_dungeon():
			# ⚠ ノルマ札（2026-10-02・手本 DungeonGate「入るのに使う：ノルマ札1枚　3 → 2」）。⚠ 続きからは使わない。
			var have: int = GameManager.get_quota_ticket_count()
			var use: int = GameManager.get_quota_tickets_per_entry()
			var ticket: Label = Label.new()
			ticket.name = "QuotaTicketLabel"
			ticket.theme_type_variation = &"SmallLabel" if have >= use else &"SmallErrorLabel"
			ticket.text = tr("ui_quota_ticket_use") % [use, have, maxi(0, have - use)]
			strip_body.add_child(ticket)
			# ⚠ 持ち込みなし（2026-10-03・決定49・手本 DungeonGate「持ち込み できない」・モック Q8 は帯の右）。
			var carry: Label = Label.new()
			carry.name = "CarryLabel"
			carry.theme_type_variation = &"SmallLabel"
			carry.text = tr("ui_depth_carry") % int(Balance.dungeon.bag_initial_slots)
			strip_body.add_child(carry)
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip_body.add_child(gap)
		# ⚠ 「受理」の判（⚠ 手本 Sign のマスターの判）。⚠ 署名を書き終えると押される＝それまで見えない。
		#   ⚠ 器は素の Control（⚠ `Container` は子の位置と大きさを戻す＝大きさの演出が効かない）。⚠ 判は帯からはみ出してよい。
		var holder: Control = Control.new()
		holder.name = "StampHolder"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip_body.add_child(holder)
		_stamp = Stamp.new()
		_stamp.name = "AcceptStamp"
		_stamp.shape = Stamp.Shape.CIRCLE
		_stamp.label_key = "ui_sortie_accepted"
		_stamp.modulate.a = 0.0
		holder.add_child(_stamp)
		_fit_stamp(holder)
	if _message != "":
		var message: Label = Label.new()
		message.name = "MessageLabel"
		message.theme_type_variation = &"ErrorLabel" if _message_error else &"AccentLabel"
		message.text = _message
		message.tooltip_text = _message
		message.mouse_filter = Control.MOUSE_FILTER_PASS
		message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		message.clip_text = true
		message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		strip_body.add_child(message)


# 「第3話　荒野の群れ」／「難ダンジョン」。
func _quest_title() -> String:
	if _dungeon_id != "":
		return tr(str(MasterDataLoader.get_dungeon(_dungeon_id).get("name_key", _dungeon_id)))
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	var name_text: String = tr(str(MasterDataLoader.get_stage(_stage_id).get("name_key", _stage_id)))
	var index: int = order.find(_stage_id)
	return name_text if index < 0 else "%s　%s" % [tr("ui_quest_episode") % (index + 1), name_text]


# --- 3つの枠（2026-10-18・回UI-1018-5・web版の手本 `01_barracks.png`） -----------------------
#   ⚠ 番号・位置・「✕ 外す」／ 写真・名前・役割・Lv ／ HP・主な値・戦力 ／ 使うビルド（1〜3・押すとすぐ切り替わる・空きは「＋組む」）
#   ／ 「育成で開く ›」「中身を直す・着替える ›」（⚠ ビルドと装備の窓）／ ◀ 前へ・後ろへ ▶。
#   ⚠ 空きの枠（`NAV-31`）は「＋ 空き」。⚠ 枠を押すと名簿から入れる先になる（⚠ もう1回で取り消す）。

func _rebuild_slots() -> void:
	_clear(slots_box)
	_signatures.clear()
	var members: Array = GameManager.get_party_members()
	for slot_index: int in range(members.size()):
		var character_id: String = str(members[slot_index])
		slots_box.add_child(_make_slot(slot_index, character_id) if character_id != "" else _make_empty_slot(slot_index))


func _slot_head(slot_index: int) -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	var number: Label = Label.new()
	number.theme_type_variation = &"SortieFrontNumberLabel" if slot_index == 0 else &"SortieNumberLabel"
	number.text = str(slot_index + 1)
	head.add_child(number)
	var position_label: Label = Label.new()
	position_label.name = "PositionLabel"
	position_label.theme_type_variation = &"CaptionLabel"
	position_label.text = tr(POSITION_KEYS[mini(slot_index, POSITION_KEYS.size() - 1)])
	position_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(position_label)
	return head


# 空きの枠（⚠ 手本 `01_barracks_out.png`）。
func _make_empty_slot(slot_index: int) -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(slot_index)
	holder.name = "Slot_%d" % slot_index
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.sheet.theme_type_variation = &"SortiePaperChosenPanel" if slot_index == _pick else &"SortieEmptySlotPanel"
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	holder.sheet.add_child(body)
	body.add_child(_slot_head(slot_index))
	var center: VBoxContainer = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var plus: Label = Label.new()
	plus.theme_type_variation = &"DossierLevelLabel"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.text = tr("ui_sortie_empty_plus")
	center.add_child(plus)
	var empty: Label = Label.new()
	empty.name = "EmptyLabel"
	empty.theme_type_variation = &"SheetHeadingLabel"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.text = tr("ui_sortie_empty_slot")
	center.add_child(empty)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("ui_sortie_empty_hint")
	center.add_child(hint)
	UiButton.attach_hit(holder.sheet, _on_slot_pressed.bind(slot_index))
	if slot_index == _pick:
		PulseFrame.attach(holder, PulseFrame.Strength.STRONG)
	return holder


func _make_slot(slot_index: int, character_id: String) -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(slot_index)
	holder.name = "Slot_%d" % slot_index
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.sheet.theme_type_variation = &"SortiePaperChosenPanel" if slot_index == _pick else &"SortiePaperPanel"
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.theme_type_variation = &"TightList"
	holder.sheet.add_child(body)

	var head: HBoxContainer = _slot_head(slot_index)
	var remove: Button = _small_button("ui_sortie_remove")
	remove.name = "RemoveButton_%d" % slot_index
	remove.disabled = GameManager.get_party_member_count() <= 1
	remove.tooltip_text = tr("ui_sortie_remove_last") if remove.disabled else ""
	remove.pressed.connect(_on_remove_pressed.bind(slot_index))
	head.add_child(remove)
	body.add_child(head)

	var hero: HBoxContainer = HBoxContainer.new()
	hero.name = "Hero"
	hero.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"photo", THEME_TYPE)))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = _name_of(character_id)
	column.add_child(name_label)
	var level: Label = Label.new()
	level.theme_type_variation = &"CaptionLabel"
	level.text = "%s ／ %s %d" % [_role_of(character_id), tr("ui_dossier_lv"), _level_of(character_id)]
	column.add_child(level)
	body.add_child(hero)

	# HP ／ 主な値 ／ 戦力（⚠ 1行）。
	var stats: Dictionary = GameManager.get_effective_stats(character_id)
	var main_key: String = GameStateKeys.STAT_MAG if int(stats.get(GameStateKeys.STAT_MAG, 0)) > int(stats.get(GameStateKeys.STAT_ATK, 0)) else GameStateKeys.STAT_ATK
	var stat_row: HBoxContainer = HBoxContainer.new()
	stat_row.name = "StatRow"
	stat_row.add_child(_stat_pair(tr("ui_training_stat_hp"), str(int(stats.get(GameStateKeys.STAT_HP, 0)))))
	stat_row.add_child(_stat_pair(tr("ui_training_stat_" + main_key), str(int(stats.get(main_key, 0)))))
	var power: HBoxContainer = _stat_pair(tr("ui_sortie_power"), str(GameManager.get_character_power(character_id)))
	power.name = "PowerPair"
	stat_row.add_child(power)
	body.add_child(stat_row)

	body.add_child(_build_box(character_id))

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)
	# ⚠ 署名の行（⚠ 出撃の準備だけ・人間「⚠ 2い」＝枠の中で書く）。
	if not _is_barracks():
		var signature: SortieSignature = SortieSignature.create(character_id)
		signature.name = "Signature_%d" % slot_index
		body.add_child(signature)
		_signatures.append(signature)
	# ⚠ 下の段：「◀ 前へ」／「後ろへ ▶」（⚠ 09-28 人間「⚠ 右と左にボタンを作ってそこと入れ替え」）。
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	var left: Button = _small_button("ui_sortie_move_left")
	left.name = "MoveLeft_%d" % slot_index
	left.disabled = slot_index <= 0
	left.pressed.connect(_on_move_pressed.bind(slot_index, -1))
	foot.add_child(left)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(gap)
	var right: Button = _small_button("ui_sortie_move_right")
	right.name = "MoveRight_%d" % slot_index
	right.disabled = slot_index >= GameStateKeys.PARTY_SLOT_COUNT - 1
	right.pressed.connect(_on_move_pressed.bind(slot_index, 1))
	foot.add_child(right)
	body.add_child(foot)
	UiButton.attach_hit(holder.sheet, _on_slot_pressed.bind(slot_index))
	if slot_index == _pick:
		PulseFrame.attach(holder, PulseFrame.Strength.STRONG)
	return holder


func _stat_pair(caption_text: String, value_text: String) -> HBoxContainer:
	var pair: HBoxContainer = HBoxContainer.new()
	pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caption: Label = Label.new()
	caption.theme_type_variation = &"FieldCaptionLabel"
	caption.text = caption_text
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pair.add_child(caption)
	var value: Label = Label.new()
	value.name = "Value"
	value.text = value_text
	pair.add_child(value)
	return pair


# 「使うビルド　押すとすぐ切り替わる」＋ 1〜3 の行（⚠ 名前・スキルと装備の絵）＋「育成で開く ›」「中身を直す・着替える ›」。
func _build_box(character_id: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "BuildBox"
	panel.theme_type_variation = &"LoadoutPanel"
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"TightList"
	panel.add_child(column)
	var caption_row: HBoxContainer = HBoxContainer.new()
	column.add_child(caption_row)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_sortie_use_build")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_row.add_child(caption)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr("ui_sortie_use_build_hint")
	caption_row.add_child(hint)
	var presets: Array = GameManager.get_character_presets(character_id)
	var matching: int = GameManager.get_matching_character_preset(character_id)
	var side: int = get_theme_constant(&"build_icon", THEME_TYPE)
	for index: int in range(presets.size()):
		var preset: Dictionary = presets[index]
		var saved: bool = bool(preset.get(GameStateKeys.PRESET_SAVED, false))
		var row: LedgerRow = LedgerRow.new()
		row.name = "Build_%s_%d" % [character_id, index]
		row.compact = true
		row.selected = index == matching
		row.show_rule = false
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ⚠ 10-23（人間「⚠ ひかえを登録すると横幅が広くなる」）：⚠ ビルドのアイコンは2段目（⚠ 1段目に番号・名前と横一列だと 309px になり、3人の枠ごと画面を押し広げていた）。
		var stack: VBoxContainer = VBoxContainer.new()
		stack.theme_type_variation = &"TightList"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stack)
		stack.add_child(line)
		var number: Label = Label.new()
		number.theme_type_variation = &"AccentLabel" if index == matching else &"CaptionLabel"
		number.text = tr("ui_sortie_build_no") % (index + 1)
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(number)
		if saved:
			var title: Label = Label.new()
			title.name = "BuildName"
			title.text = _preset_name(character_id, index)
			title.custom_minimum_size.x = float(get_theme_constant(&"build_name", THEME_TYPE))
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.clip_text = true
			title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(title)
			var icons: LoadoutIcons = LoadoutIcons.from_preset(preset, side)
			icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for child: Node in icons.get_children():
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(icons)
			row.pressed.connect(_on_build_chosen.bind(character_id, index))
		else:
			var empty: Label = Label.new()
			empty.theme_type_variation = &"CaptionLabel"
			empty.text = tr("ui_sortie_build_new")
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(empty)
			row.pressed.connect(_open_build_window.bind(character_id, index))
		column.add_child(row)
	var links: HBoxContainer = HBoxContainer.new()
	links.name = "Links"
	column.add_child(links)
	var open: Button = _small_button("ui_sortie_open_training_short")
	open.name = "OpenTraining_" + character_id
	open.pressed.connect(_on_open_training_for.bind(character_id))
	links.add_child(open)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.add_child(gap)
	var edit: Button = _small_button("ui_sortie_edit_build")
	edit.name = "EditBuild_" + character_id
	edit.pressed.connect(_open_build_window.bind(character_id, maxi(0, matching)))
	links.add_child(edit)
	return panel


func _preset_name(character_id: String, index: int) -> String:
	var preset_name: String = GameManager.get_character_preset_name(character_id, index)
	return preset_name if preset_name != "" else tr("ui_party_preset_build") % (index + 1)


func _small_button(key: String) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"PaperToggle"
	button.focus_mode = Control.FOCUS_NONE
	button.text = tr(key)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


# 「◀」「▶」：隣の枠と入れ替える（⚠ `set_party_member()` の1本＝別の枠にいる人を置くと交換になる）。⚠ 空きの枠とも入れ替わる。
func _on_move_pressed(slot_index: int, step: int) -> void:
	var members: Array = GameManager.get_party_members()
	var other: int = slot_index + step
	if other < 0 or other >= members.size():
		return
	var mine: String = str(members[slot_index])
	var theirs: String = str(members[other])
	if theirs == "":
		# ⚠ 空きへ動かす＝先に置いてから元を空ける（⚠ 最後の1人は外せないため）。
		var copy: Array = members.duplicate()
		copy[other] = mine
		copy[slot_index] = ""
		_write_members(copy)
	else:
		GameManager.set_party_member(other, mine)
	_pick = -1
	_message = ""
	_rebuild()


# ⚠ 並びをまとめて書く（⚠ `set_party_member()` の1本を、⚠ 人の居る枠 → 空きの順に呼ぶ）。
func _write_members(members: Array) -> void:
	for i: int in range(members.size()):
		if str(members[i]) != "":
			GameManager.set_party_member(i, str(members[i]))
	for i: int in range(members.size()):
		if str(members[i]) == "":
			GameManager.set_party_member(i, "")


func _on_remove_pressed(slot_index: int) -> void:
	if not GameManager.set_party_member(slot_index, ""):
		_say(tr("ui_sortie_remove_last"), true)
		return
	_pick = -1
	_message = ""
	_rebuild()


# 枠を押す＝名簿から入れる先にする（⚠ もう1回で取り消す）。
func _on_slot_pressed(slot_index: int) -> void:
	_pick = -1 if _pick == slot_index else slot_index
	_message = ""
	_rebuild()


# ビルドの行を押す＝⚠ すぐ当てる（`apply_character_preset()`）。
func _on_build_chosen(character_id: String, index: int) -> void:
	var report: Dictionary = GameManager.apply_character_preset(character_id, index)
	_message = GameManager.format_apply_report(report)
	_message_error = not bool(report.get(GameManager.APPLY_OK, false))
	_rebuild()


# ビルドと装備の窓（⚠ 手本 `01_barracks_window.png`）。⚠ 閉じたら描き直す。
func _open_build_window(character_id: String, index: int) -> void:
	var window: BuildEditWindow = BuildEditWindow.open(self, character_id, index)
	window.closed.connect(_on_build_window_closed)


func _on_build_window_closed(notice: String) -> void:
	_message = notice
	_message_error = false
	_rebuild()


# --- 右：名簿（⚠ 2列・縦に送る・並び＝Lv・戦力・名前 ／ 役割で絞る） --------------------------
#   ⚠ 押す：⚠ 枠を選んでいればそこへ（⚠ 出ている人なら入れ替わる）／ ⚠ 出ていない人＝空いている枠へ ／ ⚠ 出ている人＝外れる（`NAV-31`）。

func _rebuild_side() -> void:
	_clear(side)
	# ⚠ 潜る深さ（2026-10-03・決定49）。⚠ 新しく入るときだけ。
	if _is_new_dungeon_entry():
		side.add_child(_build_depth_sheet())
	var holder: TiltedSheet = TiltedSheet.create(2)
	holder.name = "RosterSheet"
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.sheet.theme_type_variation = &"SortiePaperPanel"
	side.add_child(holder)
	var body: VBoxContainer = VBoxContainer.new()
	body.theme_type_variation = &"TightList"
	holder.sheet.add_child(body)
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "RosterHeading"
	heading.title_key = "ui_sortie_roster"
	heading.right_text = tr("ui_sortie_roster_count") % [_roster_ids(false).size(), GameManager.get_party_member_count(), GameStateKeys.PARTY_SLOT_COUNT]
	body.add_child(heading)
	var hint: Label = Label.new()
	hint.name = "RosterHint"
	hint.theme_type_variation = &"AccentLabel" if _pick >= 0 else &"CaptionLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("ui_sortie_roster_for") % [_pick + 1, tr(POSITION_KEYS[_pick])] if _pick >= 0 else tr("ui_sortie_roster_hint_v2")
	# ⚠ 潜る深さの紙が上に乗るときは、⚠ 札の高さを空けるため決まり文句の案内は出さない（⚠ 枠を選んだときの案内は出す・10-18）。
	hint.visible = _pick >= 0 or not _is_new_dungeon_entry()
	body.add_child(hint)
	body.add_child(_seg_row("ui_sortie_sort_caption", "SortSeg", [SORT_LEVEL, SORT_POWER, SORT_NAME],
		["ui_sortie_sort_level", "ui_sortie_power", "ui_sortie_sort_name"], _sort, _on_sort_pressed))
	var roles: Array[String] = [""]
	var role_keys: Array[String] = ["ui_belongings_filter_all"]
	for role: String in GameManager.CHARACTER_ROLES:
		roles.append(role)
		role_keys.append("ui_role_kind_" + role)
	body.add_child(_seg_row("ui_sortie_role_caption", "RoleSeg", roles, role_keys, _role_filter, _on_role_pressed))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "RosterScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.name = "RosterCards"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var members: Array = GameManager.get_party_members()
	var debug_alpha: float = float(get_theme_constant(&"chip_debug_alpha_pct", TRAINING_THEME_TYPE)) / 100.0
	for character_id: String in _roster_ids(true):
		grid.add_child(_roster_card(character_id, members.find(character_id), debug_alpha))


func _seg_row(caption_key: String, seg_name: String, values: Array[String], keys: Array[String], current: String, handler: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	caption.theme_type_variation = &"FieldCaptionLabel"
	caption.text = tr(caption_key)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var box: PanelContainer = PanelContainer.new()
	box.name = seg_name
	box.theme_type_variation = &"SegGroup"
	row.add_child(box)
	var seg: HBoxContainer = HBoxContainer.new()
	seg.theme_type_variation = &"SegRow"
	box.add_child(seg)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in range(values.size()):
		var button: Button = Button.new()
		button.name = "%s_%s" % [seg_name, values[i] if values[i] != "" else "all"]
		button.theme_type_variation = &"SegButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.text = tr(keys[i])
		button.button_pressed = values[i] == current
		button.pressed.connect(handler.bind(values[i]))
		seg.add_child(button)
	return row


func _roster_card(character_id: String, in_slot: int, debug_alpha: float) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Roster_" + character_id
	card.theme_type_variation = &"SortieRosterOutPanel" if in_slot >= 0 else &"SortieRosterPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if GameManager.is_debug_character(character_id):
		card.modulate.a = debug_alpha
	var line: HBoxContainer = HBoxContainer.new()
	card.add_child(line)
	line.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"roster_photo", THEME_TYPE)))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _name_of(character_id)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	column.add_child(name_label)
	var sub: Label = Label.new()
	sub.name = "Badge"
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.clip_text = true
	if in_slot >= 0 and _pick >= 0 and in_slot != _pick:
		sub.theme_type_variation = &"AccentLabel"
		sub.text = tr("ui_sortie_swap_with") % (in_slot + 1)
	elif in_slot >= 0 and _pick < 0:
		sub.theme_type_variation = &"ErrorLabel"
		sub.text = tr("ui_sortie_press_to_remove") % (in_slot + 1)
	elif _pick >= 0:
		sub.theme_type_variation = &"AccentLabel"
		sub.text = tr("ui_sortie_press_to_slot") % (_pick + 1)
	else:
		sub.theme_type_variation = &"CaptionLabel"
		sub.text = "%s・%s %d" % [_role_short(character_id), tr("ui_dossier_lv"), _level_of(character_id)]
	column.add_child(sub)
	var power: VBoxContainer = VBoxContainer.new()
	power.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(power)
	var value: Label = Label.new()
	value.name = "PowerLabel"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = str(GameManager.get_character_power(character_id))
	power.add_child(value)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"FieldCaptionLabel"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.text = tr("ui_sortie_power")
	power.add_child(caption)
	UiButton.attach_hit(card, _on_roster_pressed.bind(character_id))
	return card


# 役割を短く（⚠ 名簿の札は狭い＝⚠ 役割の種類の最初の1つ）。
func _role_short(character_id: String) -> String:
	var roles: Array[String] = GameManager.get_character_roles(character_id)
	return tr("ui_role_kind_" + roles[0]) if not roles.is_empty() else _role_of(character_id)


# ⚠ 本番のキャラ → 検証用（⚠ 検証用はデバッグビルドだけ・薄く）。⚠ `filtered`＝役割で絞る。
func _roster_ids(filtered: bool = true) -> Array[String]:
	var ids: Array[String] = []
	var debug_ids: Array[String] = []
	for raw: Variant in GameManager.get_party_candidates():
		var id: String = str(raw)
		if filtered and _role_filter != "" and not (_role_filter in GameManager.get_character_roles(id)):
			continue
		if GameManager.is_debug_character(id):
			debug_ids.append(id)
		else:
			ids.append(id)
	match _sort:
		SORT_NAME:
			ids.sort_custom(func(a: String, b: String) -> bool: return _name_of(a) < _name_of(b))
		SORT_POWER:
			ids.sort_custom(func(a: String, b: String) -> bool: return GameManager.get_character_power(a) > GameManager.get_character_power(b))
		_:
			ids.sort_custom(func(a: String, b: String) -> bool: return _level_of(a) > _level_of(b))
	ids.append_array(debug_ids)
	return ids


func _on_sort_pressed(sort: String) -> void:
	_sort = sort
	SceneManager.remember(TransferKeys.MEMORY_ROSTER_SORT, _sort)
	_rebuild_side()


func _on_role_pressed(role: String) -> void:
	_role_filter = role
	SceneManager.remember(TransferKeys.MEMORY_ROSTER_ROLE, _role_filter)
	_rebuild_side()


# 名簿の札を押す。
func _on_roster_pressed(character_id: String) -> void:
	_roster_pick = character_id
	var members: Array = GameManager.get_party_members()
	var in_slot: int = members.find(character_id)
	if _pick >= 0:
		# ⚠ 枠を選んでいる＝そこへ（⚠ 別の枠にいる人なら入れ替わる）。
		if in_slot >= 0 and str(members[_pick]) == "":
			var copy: Array = members.duplicate()
			copy[_pick] = character_id
			copy[in_slot] = ""
			_write_members(copy)
		else:
			GameManager.set_party_member(_pick, character_id)
		_pick = -1
		_message = ""
		_rebuild()
		return
	if in_slot >= 0:
		# ⚠ 出ている人＝外れる（⚠ 最後の1人は外せない）。
		_on_remove_pressed(in_slot)
		return
	var empty: int = members.find("")
	if empty < 0:
		_say(tr("ui_sortie_no_empty_slot"), true)
		return
	GameManager.set_party_member(empty, character_id)
	_message = ""
	_rebuild()


func _on_open_training_for(character_id: String, tab_id: String = "") -> void:
	var data: Dictionary = {TransferKeys.CHARACTER_ID: character_id}
	if tab_id != "":
		data[TransferKeys.TRAINING_TAB] = tab_id
	# ⚠ 10-06（`NAV-18`）：⚠ 寄り道＝育成の「戻る」で、この画面（⚠ 同じ依頼・同じ深さ）へ戻る。
	SceneManager.open_detour(TRAINING_PATH, data, PARTY_PRESET_PATH, {
		TransferKeys.RETURN_PATH: _return_path,
		TransferKeys.SORTIE_STAGE_ID: _stage_id,
		TransferKeys.SORTIE_DUNGEON_ID: _dungeon_id,
		TransferKeys.SORTIE_START_FLOOR: _start_floor,
	})


# ⚠ 控えに残すビルドの番号（⚠ いまの形と同じビルド ／ 無ければ空いているビルドへいまの形を焼いて指す ／ 全部埋まっていれば 1）。
func _build_for_keep(character_id: String) -> int:
	if character_id == "":
		return 0
	var matching: int = _build_of(character_id)
	if matching >= 0:
		return matching
	var presets: Array = GameManager.get_character_presets(character_id)
	for index: int in range(presets.size()):
		if not bool((presets[index] as Dictionary).get(GameStateKeys.PRESET_SAVED, false)):
			GameManager.save_character_preset(character_id, index)
			return index
	return 0


# --- 下：編成の控え（⚠ 8件・横一列）＋ 出撃する -----------------------------------------------

func _rebuild_roster() -> void:
	_clear(roster_body)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Reserve"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_body.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_barracks_reserve")
	head.add_child(title)
	var count: Label = Label.new()
	count.theme_type_variation = &"CaptionLabel"
	count.text = tr("ui_sortie_reserve_hint") % GameManager.get_party_preset_count()
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	var presets: Array = GameManager.get_party_presets()
	var call_button: Button = _small_button("ui_barracks_call")
	call_button.name = "CallButton"
	call_button.disabled = not _is_saved(presets[_preset_pick] if _preset_pick < presets.size() else null)
	call_button.pressed.connect(_on_call_pressed)
	head.add_child(call_button)
	var keep_button: Button = _small_button("ui_sortie_keep")
	keep_button.name = "KeepButton"
	keep_button.pressed.connect(_on_keep_pressed)
	head.add_child(keep_button)
	var delete_button: Button = _small_button("ui_sortie_reserve_delete")
	delete_button.name = "DeletePresetButton"
	delete_button.disabled = call_button.disabled
	delete_button.pressed.connect(_on_delete_preset_pressed)
	head.add_child(delete_button)

	var cards: HBoxContainer = HBoxContainer.new()
	cards.name = "PresetRows"
	column.add_child(cards)
	var face: int = get_theme_constant(&"mini_photo", THEME_TYPE)
	for index: int in range(GameManager.get_party_preset_count()):
		var preset: Variant = presets[index] if index < presets.size() else null
		var card: PanelContainer = PanelContainer.new()
		card.name = "Preset_%d" % index
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.theme_type_variation = &"SortieRosterOutPanel" if index == _preset_pick else &"SortieRosterPanel"
		if not _is_saved(preset) and index != _preset_pick:
			card.modulate.a = 0.6
		var inner: VBoxContainer = VBoxContainer.new()
		card.add_child(inner)
		var number: Label = Label.new()
		number.theme_type_variation = &"SmallLabel"
		number.text = str(index + 1)
		inner.add_child(number)
		if _is_saved(preset):
			var faces: HBoxContainer = HBoxContainer.new()
			faces.alignment = BoxContainer.ALIGNMENT_CENTER
			inner.add_child(faces)
			var builds: Array[String] = []
			for entry: Variant in _preset_slots(preset):
				var member: String = str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))
				if member == "":
					var blank: PanelContainer = PanelContainer.new()
					blank.theme_type_variation = &"MergeSlotEmptyPanel"
					blank.custom_minimum_size = Vector2(face, face)
					faces.add_child(blank)
					builds.append("-")
				else:
					faces.add_child(CharacterAvatar.create(member, face))
					builds.append(str(int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0)) + 1))
			var build_line: Label = Label.new()
			build_line.theme_type_variation = &"CaptionLabel"
			build_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			build_line.text = tr("ui_sortie_reserve_builds") % "・".join(builds)
			build_line.clip_text = true
			build_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			inner.add_child(build_line)
			if _matches_now(preset):
				build_line.text = tr("ui_sortie_same")
				build_line.theme_type_variation = &"AccentLabel"
		else:
			var empty: Label = Label.new()
			empty.theme_type_variation = &"CaptionLabel"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.text = tr("ui_party_preset_empty")
			inner.add_child(empty)
		UiButton.attach_hit(card, _on_preset_row_pressed.bind(index))
		cards.add_child(card)

	if _is_barracks():
		return
	# ⚠ 「出撃する」（⚠ 出撃の準備だけ）。⚠ 「周回する」は置かない（⚠ 09-28 人間「⚠ 周回の時は編成画面はいらない」）。
	var go: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_quest_sortie_go")
	go.name = "SortieButton"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_on_sortie_pressed)
	roster_body.add_child(go)


# 控えを消す（⚠ 確かめの窓）。⚠ キャラ側のビルドは消さない（`clear_party_preset()`）。
func _on_delete_preset_pressed() -> void:
	var index: int = _preset_pick
	var ok: bool = await Modal.confirm(self, "ui_sortie_reserve_delete_confirm", [index + 1], false, {
		Modal.OPTION_TITLE: tr("ui_sortie_reserve_delete_title") % (index + 1),
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_sortie_reserve_delete",
	})
	if not ok or not is_inside_tree():
		return
	if GameManager.clear_party_preset(index):
		_say(tr("ui_sortie_reserve_deleted") % (index + 1))
	_rebuild()


# --- 潜る深さ（2026-10-03・決定49・`EXEC_DUNGEON_SHAPE.md` §5-5・人間「⚠ 2あ　⚠ 4あ」） ---------------
#   ⚠ 選べる深さの判定は GameManager の1本（`get_dungeon_start_floor_options()`）。⚠ 画面は番号を持つだけ。

func _is_new_dungeon_entry() -> bool:
	return _dungeon_id != "" and not GameManager.is_in_dungeon()


# 入るフロア（⚠ まだ選んでいなければ最深の次＝手本の「31層から」）。⚠ 開いていない深さを指していたら丸める。
func _chosen_start_floor() -> int:
	var options: Array[int] = GameManager.get_dungeon_start_floor_options(_dungeon_id)
	if options.is_empty():
		return 1
	if _start_floor in options:
		return _start_floor
	return options[options.size() - 1]


func _build_depth_sheet() -> TiltedSheet:
	# ⚠ 塔は選べない＝縦図を出さず「12階から」の1枚（2026-10-09・回D-塔・人間「⚠ ２あ」）。
	if GameManager.is_tower_dungeon(_dungeon_id):
		return _build_tower_sheet()
	# ⚠⚠ 10-19（回SEE29-E・`NAV-38`・人間「⚠ 狭い　深さを選ぶ画面に分ける1っ回画面を挟む」）：⚠ 深さは前の画面（`DepthSelectScreen`）で選ぶ。
	#   ⚠ ここは「◯層から」と「深さを変える ›」の1行だけ（⚠ 名簿が縦に広く使える）。
	var per_floor: int = GameManager.get_dungeon_layers_per_floor(_dungeon_id)
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "Depth"
	holder.sheet.theme_type_variation = &"SortiePaperPanel"
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "DepthLine"
	holder.sheet.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_depth_title")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var big: Label = Label.new()
	big.name = "StartLayerLabel"
	big.theme_type_variation = &"DepthBigLabel"
	big.text = str((_chosen_start_floor() - 1) * per_floor + 1)
	line.add_child(big)
	var unit: Label = Label.new()
	unit.text = tr("ui_depth_from")
	unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(unit)
	var change: Button = UiButton.create_paper_choice("ui_depth_change")
	change.name = "ChangeDepthButton"
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	change.pressed.connect(_on_change_depth_pressed)
	line.add_child(change)
	return holder


func _on_change_depth_pressed() -> void:
	DepthSelectScreen.open(_dungeon_id, _chosen_start_floor())


# 塔の入る階（⚠ 最後に帰った階の次・選べない）。⚠ 名前は縦図の紙と同じ（⚠ 検査が名前で探す）。
func _build_tower_sheet() -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "Depth"
	holder.sheet.theme_type_variation = &"SortiePaperPanel"
	var body: VBoxContainer = VBoxContainer.new()
	holder.sheet.add_child(body)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_tower_depth_title"
	body.add_child(heading)
	var big_line: HBoxContainer = HBoxContainer.new()
	big_line.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(big_line)
	var big: Label = Label.new()
	big.name = "StartLayerLabel"
	big.theme_type_variation = &"DepthBigLabel"
	big.text = str(_chosen_start_floor())
	big_line.add_child(big)
	var unit: Label = Label.new()
	unit.text = tr("ui_tower_depth_from")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	big_line.add_child(unit)
	var best: Label = Label.new()
	best.name = "TowerBestLabel"
	best.theme_type_variation = &"SmallLabel"
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.text = tr("ui_tower_depth_best") % GameManager.get_dungeon_best_floors(_dungeon_id)
	body.add_child(best)
	return holder


func _is_saved(preset: Variant) -> bool:
	return preset is Dictionary and bool((preset as Dictionary).get(GameStateKeys.PRESET_SAVED, false))


func _preset_slots(preset: Variant) -> Array:
	if not (preset is Dictionary):
		return []
	var slots: Variant = (preset as Dictionary).get(GameStateKeys.PRESET_SLOTS, [])
	return slots as Array if slots is Array else []


# 「いまと同じ」＝並びと各自のビルド番号が同じ。
func _matches_now(preset: Variant) -> bool:
	var members: Array = GameManager.get_party_members()
	var slots: Array = _preset_slots(preset)
	if slots.size() != members.size():
		return false
	for i: int in range(slots.size()):
		var entry: Dictionary = slots[i]
		if str(entry.get(GameStateKeys.PRESET_CHARACTER_ID, "")) != str(members[i]):
			return false
		if str(members[i]) != "" and int(entry.get(GameStateKeys.PRESET_INDEX, 0)) != _build_of(str(members[i])):
			return false
	return true


func _on_preset_row_pressed(index: int) -> void:
	_preset_pick = index
	_rebuild_roster()


# 呼ぶ＝⚠ 予告の窓（⚠ 並び・ビルド・装備が移る）を通してから当てる（⚠ モック「控えを呼ぶ」）。
func _on_call_pressed() -> void:
	var index: int = _preset_pick
	var report: Dictionary = GameManager.get_party_preset_apply_report(index)
	if not bool(report.get(GameManager.APPLY_OK, false)):
		_say(tr(str(report.get(GameManager.APPLY_REASON, ""))), true)
		return
	var ok: bool = await Modal.confirm(self, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_sortie_call_title") % (index + 1),
		Modal.OPTION_CONTENT: _build_call_preview(index, report),
		Modal.OPTION_CONFIRM_LABEL: "ui_barracks_call",
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
	})
	if not ok or not is_inside_tree():
		return
	var applied: Dictionary = GameManager.apply_party_preset(index)
	_pick = -1
	_message = GameManager.format_apply_report(applied)
	_message_error = not bool(applied.get(GameManager.APPLY_OK, false))
	_rebuild()


# 予告の中身：並び ／ ビルド（変わる人だけ）／ 装備が移る（奪うもの）。
func _build_call_preview(index: int, report: Dictionary) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "CallPreview"
	var slots: Array = _preset_slots(GameManager.get_party_presets()[index])
	var order: HBoxContainer = HBoxContainer.new()
	order.name = "Order"
	order.add_child(_caption(tr("ui_sortie_call_order")))
	for i: int in range(slots.size()):
		var member: String = str((slots[i] as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		if member == "":
			var blank: Label = Label.new()
			blank.text = tr("ui_sortie_empty_slot")
			order.add_child(blank)
		else:
			order.add_child(CharacterAvatar.create(member, get_theme_constant(&"mini_photo", THEME_TYPE)))
		var n: Label = Label.new()
		n.text = str(i + 1)
		order.add_child(n)
	box.add_child(order)
	var changes: Array[String] = []
	for entry: Variant in slots:
		var character_id: String = str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var to_index: int = int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
		if character_id != "" and to_index != _build_of(character_id):
			changes.append("%s → %s" % [_name_of(character_id), _preset_name(character_id, to_index)])
	var build_line: Label = Label.new()
	build_line.name = "BuildLine"
	build_line.theme_type_variation = &"SmallLabel"
	build_line.text = "%s　%s" % [tr("ui_training_build"), "、".join(changes) if not changes.is_empty() else tr("ui_forge_unchanged")]
	box.add_child(build_line)
	var conflicts: Array = report.get(GameManager.APPLY_CONFLICTS, [])
	if not conflicts.is_empty():
		var moves: Label = Label.new()
		moves.theme_type_variation = &"ErrorLabel"
		moves.text = tr("ui_sortie_call_moves")
		box.add_child(moves)
		for raw: Variant in conflicts:
			var conflict: Dictionary = raw
			var instance: Dictionary = GameManager.get_equipment_instance(str(conflict.get(GameManager.APPLY_INSTANCE_ID, "")))
			var line: Label = Label.new()
			line.name = "MoveLine"
			line.theme_type_variation = &"SmallLabel"
			line.text = tr("ui_sortie_call_move_line") % [
				tr(GameManager.item_name_key(str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")))),
				_name_of(str(conflict.get(GameManager.APPLY_FROM_CHARACTER_ID, ""))),
				_name_of(str(conflict.get(GameManager.APPLY_CHARACTER_ID, ""))),
			]
			box.add_child(line)
	return box


func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = text
	return label


# いまを残す＝選んでいる控えに、いまの並び ＋ 各自のビルド番号を焼く（⚠ 参照だけ・`GR-4`）。⚠ 上書きは確かめる。
func _on_keep_pressed() -> void:
	var index: int = _preset_pick
	if _is_saved(GameManager.get_party_presets()[index]):
		var ok: bool = await Modal.confirm(self, "ui_sortie_keep_overwrite", [index + 1], false, {
			Modal.OPTION_TITLE: tr("ui_sortie_keep_title") % (index + 1),
			Modal.OPTION_CONFIRM_LABEL: "ui_sortie_keep",
		})
		if not ok or not is_inside_tree():
			return
	var slots: Array = []
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		slots.append({
			GameStateKeys.PRESET_CHARACTER_ID: character_id,
			GameStateKeys.PRESET_INDEX: _build_for_keep(character_id),
		})
	if GameManager.save_party_preset(index, slots):
		_say(tr("ui_barracks_kept") % (index + 1))
	_rebuild()


# --- 出撃の手続き（⚠ 前は依頼掲示板にあった。⚠ 判定は GameManager の口のまま） --------------------

# 「出撃する」：⚠ 出られるかを先に全部見る（CLAUDE.md 6番）→ ⚠ 署名を書いて判を押す（手本 Sign）→ ⚠ 出発。
#   ⚠ 出られないときは署名を書かない（⚠ 書き終わってから断られると嘘の演出になる）。
func _on_sortie_pressed() -> void:
	if _signing:
		return
	var error: String = _sortie_error()
	if error != "":
		_say(error, true)
		# ⚠ 10-07（人間「⚠ プラスボタン押さなくても　例えば必要な素材を提示する画面などがあれば」・`NAV-19`）：⚠ スタミナが足りないときは入手先の窓も出す（⚠ ポーションを使う・ショップ・ポモドーロ）。
		var back_data: Dictionary = {
			TransferKeys.RETURN_PATH: _return_path, TransferKeys.SORTIE_STAGE_ID: _stage_id,
			TransferKeys.SORTIE_DUNGEON_ID: _dungeon_id, TransferKeys.SORTIE_START_FLOOR: _start_floor,
		}
		if _dungeon_id == "" and _is_unlocked(_stage_id):
			var _shown: bool = ItemSourceWindow.open_if_short(self, GameStateKeys.STAMINA, int(Balance.adventure.stamina_cost_per_stage), back_data)
		elif _dungeon_id != "" and not GameManager.is_in_dungeon():
			var _ticket: bool = ItemSourceWindow.open_if_short(self, GameStateKeys.ITEM_QUOTA_TICKET, GameManager.get_quota_tickets_per_entry(), back_data)
		return
	_play_sign()


# 出られない理由（⚠ 空なら出られる）。⚠ 状態は触らない。
func _sortie_error() -> String:
	if _dungeon_id != "":
		# ⚠ 別のランの途中なら断る（⚠ 黙って捨てると鞄も戦闘時 MAX HP も消える）。
		if GameManager.is_in_dungeon():
			var current_id: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
			if current_id != _dungeon_id:
				return tr("ui_dungeon_other_in_progress")
			return ""
		# ⚠ 新しく入るにはノルマ札（2026-10-02・`EXEC_QUOTA_TICKET.md`・人間「⚠ 4あ」）。
		if not GameManager.has_quota_ticket_for_entry():
			return tr("ui_quota_ticket_needed")
		# ⚠ 開いていない深さ（⚠ 選び直したあと最深が変わることは無いが、⚠ 判定は口に聞く）。
		if not (_chosen_start_floor() in GameManager.get_dungeon_start_floor_options(_dungeon_id)):
			return tr("ui_dungeon_start_failed")
		return ""
	if GameManager.get_party_member_count() <= 0:
		return tr("ui_sortie_no_member")
	# 解放状態の最終チェック（EXEC §5.1）
	if not _is_unlocked(_stage_id):
		return tr("ui_adventure_locked")
	# スタミナの確認（EXEC §5.2 / §5.3）
	var cost: int = int(Balance.adventure.stamina_cost_per_stage)
	var stamina: Dictionary = GameManager.get_state().get(GameStateKeys.STAMINA, {})
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	if current < cost:
		return tr("ui_adventure_stamina_short") + " (%d / %d)" % [cost, current]
	# フロア形式（段階14-c）。⚠ 別のフロアに入っていたら断る（黙って捨てると、たいまつもレリックも持ち越しHPも消える）。
	if GameManager.is_floor_stage(_stage_id) and GameManager.is_in_floor():
		var current_floor: String = str(GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_FLOOR_ID, ""))
		if current_floor != _stage_id:
			return tr("ui_floor_other_in_progress")
	return ""


# --- 出撃の署名（2026-09-28・手本 Sign・人間「⚠ 2い　⚠ 3あ　⚠ 4それで」） ---------------
#   ⚠ 1番から順に署名 → 帯に「受理」の判 → 出発。⚠ 画面のどこかを押すと飛ばしてすぐ出発。⚠ 値は Theme の `Sortie` 型（`sign_*`）。

func _play_sign() -> void:
	_signing = true
	var go: Node = find_child("SortieButton", true, false)
	if go is BaseButton:
		(go as BaseButton).disabled = true
	# ⚠ 押すと飛ばす幕（⚠ 書いている間は枠・名簿・控えを押させない）。
	_sign_blocker = Control.new()
	_sign_blocker.name = "SignBlocker"
	_sign_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_sign_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sign_blocker.gui_input.connect(_on_sign_blocker_input)
	add_child(_sign_blocker)
	var write: float = float(get_theme_constant(&"sign_write_ms", THEME_TYPE)) / 1000.0
	var gap: float = float(get_theme_constant(&"sign_gap_ms", THEME_TYPE)) / 1000.0
	var tween: Tween = create_tween().set_speed_scale(GameSettings.effect_speed())
	for signature: SortieSignature in _signatures:
		tween.tween_property(signature, "progress", 1.0, write).from(0.0)
		tween.tween_interval(gap)
	if _stamp != null:
		var from_scale: float = float(get_theme_constant(&"sign_stamp_from_pct", THEME_TYPE)) / 100.0
		var final_scale: float = float(get_theme_constant(&"sign_stamp_scale_pct", THEME_TYPE)) / 100.0
		var slam: float = float(get_theme_constant(&"sign_stamp_slam_ms", THEME_TYPE)) / 1000.0
		_stamp.scale = Vector2.ONE * from_scale
		tween.tween_interval(float(get_theme_constant(&"sign_stamp_delay_ms", THEME_TYPE)) / 1000.0)
		tween.tween_property(_stamp, "modulate:a", 1.0, slam)
		tween.parallel().tween_property(_stamp, "scale", Vector2.ONE * final_scale, slam).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_interval(float(get_theme_constant(&"sign_hold_ms", THEME_TYPE)) / 1000.0)
	tween.tween_callback(_depart)
	_sign_tween = tween


# 判の大きさと中心（⚠ 器の高さは帯の高さ＝判はそこからはみ出して上下の真ん中に置く）。
func _fit_stamp(holder: Control) -> void:
	if _stamp == null or not is_instance_valid(_stamp):
		return
	var final_scale: float = float(get_theme_constant(&"sign_stamp_scale_pct", THEME_TYPE)) / 100.0
	_stamp.size = _stamp.custom_minimum_size
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.rotation = deg_to_rad(-14.0)
	holder.custom_minimum_size.x = _stamp.size.x * final_scale
	_center_stamp(holder)
	# ⚠ 帯の高さは並べ終わってから決まる（⚠ ラムダで掴まない＝CLAUDE.md 10番）。
	holder.resized.connect(_center_stamp.bind(holder))


func _center_stamp(holder: Control) -> void:
	if _stamp == null or not is_instance_valid(_stamp) or _stamp.get_parent() != holder:
		return
	_stamp.position = Vector2((holder.size.x - _stamp.size.x) * 0.5, (holder.size.y - _stamp.size.y) * 0.5)


func _on_sign_blocker_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		skip_sign()


# 飛ばす：⚠ 全員書き終え・判を押した姿にして、すぐ出発。
func skip_sign() -> void:
	if not _signing:
		return
	if _sign_tween != null and _sign_tween.is_valid():
		_sign_tween.kill()
	for signature: SortieSignature in _signatures:
		signature.progress = 1.0
	if _stamp != null:
		_stamp.modulate.a = 1.0
		_stamp.scale = Vector2.ONE * float(get_theme_constant(&"sign_stamp_scale_pct", THEME_TYPE)) / 100.0
	_depart()


func _depart() -> void:
	if not _signing:
		return
	_signing = false
	if _sign_blocker != null and is_instance_valid(_sign_blocker):
		remove_child(_sign_blocker)
		_sign_blocker.queue_free()
	_sign_blocker = null
	if _dungeon_id != "":
		_start_dungeon()
	else:
		_start_stage()


func _start_stage() -> void:
	# ⚠ 判定は `_sortie_error()`（⚠ 署名の前に見た。⚠ ここでもう一度見る＝書いている間に変わっていないか）。
	var error: String = _sortie_error()
	if error != "":
		_say(error, true)
		return
	# フロア形式（段階14-c）。⚠ 同じフロアの途中なら続きへ。
	if GameManager.is_floor_stage(_stage_id):
		if GameManager.is_in_floor():
			SceneManager.change_scene(FLOOR_MAP_PATH)
			return
		if not GameManager.start_floor(_stage_id):
			_say(tr("ui_floor_start_failed"), true)
			return
		SceneManager.change_scene(FLOOR_MAP_PATH)
		return
	# 遷移（EXEC §5.4）。PARTY_ID は渡さない
	SceneManager.change_scene_with_data(BATTLE_PATH, {
		TransferKeys.STAGE_ID: _stage_id,
		TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
	})


# ⚠ 入れるかの判定は GameManager が持つ。⚠ 別のランの途中なら断る（⚠ 黙って捨てると鞄も戦闘時 MAX HP も消える）。
# ⚠ 入るとノルマ札を1枚使う（`DG-1`）。⚠ 選んだ深さから入る（決定49）。
func _start_dungeon() -> void:
	var error: String = _sortie_error()
	if error != "":
		_say(error, true)
		return
	if GameManager.is_in_dungeon():
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return
	# ⚠ 新しく入る＝ノルマ札を使う（⚠ 判定・入る・減らすは GameManager の1本）。
	if not GameManager.enter_dungeon_with_ticket(_dungeon_id, _chosen_start_floor()):
		_say(tr("ui_dungeon_start_failed"), true)
		return
	SceneManager.change_scene(DUNGEON_MAP_PATH)


# 解放判定。stage_order の index 関係のみを使う（EXEC §4.2）。
func _is_unlocked(stage_id: String) -> bool:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	var idx: int = order.find(stage_id)
	if idx < 0:
		return false
	return idx == 0 or GameManager.is_stage_cleared(str(order[idx - 1]))


# --- はじめてのガイド（⚠ 人間「⚠ 2あ」） ---------------------------------

func _open_guide() -> void:
	if not is_inside_tree():
		return
	var slots: Array[Control] = []
	for child: Node in slots_box.get_children():
		slots.append(child as Control)
	var steps: Array[Dictionary] = [
		{SortieGuide.KEY_TARGETS: slots, SortieGuide.KEY_TITLE: "ui_sortie_guide_1_title", SortieGuide.KEY_BODY: "ui_sortie_guide_1_body"},
		{SortieGuide.KEY_TARGETS: [side as Control], SortieGuide.KEY_TITLE: "ui_sortie_guide_2_title", SortieGuide.KEY_BODY: "ui_sortie_guide_2_body"},
	]
	var guide: SortieGuide = SortieGuide.open(self, steps)
	guide.finished.connect(_on_guide_finished)


func _on_guide_finished() -> void:
	GameManager.mark_guide_seen(GameManager.GUIDE_SORTIE)


func _on_back_pressed() -> void:
	# 履歴に依存せず明示的に帰る（base_screen.gd と同じ流儀）。
	# ⚠ 10-06（`NAV-19`）：⚠ 入手先の窓から寄り道で来た（＝戻り先が積んである）なら、窓を開いた画面へ。
	if SceneManager.has_return():
		SceneManager.go_back_or(_return_path)
		return
	# ⚠ 10-19（回SEE29-E）：⚠ 深さを選ぶ画面から来たなら、選んでいた深さのままそこへ（⚠ 難ダンジョンの番号を持って戻る）。
	if _return_path == DepthSelectScreen.SCENE_PATH:
		DepthSelectScreen.open(_dungeon_id, _start_floor)
		return
	SceneManager.change_scene(_return_path)


# 入手先の窓から戻ってきたときの姿（⚠ 同じ依頼・同じ深さの出撃の準備）。
func _source_return_data() -> Dictionary:
	return {
		TransferKeys.RETURN_PATH: _return_path, TransferKeys.SORTIE_STAGE_ID: _stage_id,
		TransferKeys.SORTIE_DUNGEON_ID: _dungeon_id, TransferKeys.SORTIE_START_FLOOR: _start_floor,
	}
