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
# ⚠ キャラごとに「いまどのビルド番号か」（character_id -> int）。⚠ 状態には無い（⚠ 画面の控え）。⚠ 当てたときに合わせる。
var _selected_builds: Dictionary = {}
# ⚠ 名簿から入れる先の枠（⚠ -1 なら選んでいない）／ ⚠ 控えで選んでいる行。
var _pick: int = -1
var _preset_pick: int = 0
var _sort: String = SORT_LEVEL
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
	header.back_pressed.connect(_on_back_pressed)
	if _is_barracks():
		header.set_subtitle_text(tr("ui_sortie_barracks_subtitle"))
		# ⚠ 拠点から来たときだけ施設の帯を出す（⚠ 詰所）。
		if _return_path == BASE_PATH:
			BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.BARRACKS)
	else:
		header.title_key = "ui_sortie_title"
		header.set_subtitle_text(tr("ui_dungeon_section") if _dungeon_id != "" else tr("ui_barracks_sortie"))
	side.custom_minimum_size.x = float(get_theme_constant(&"side_width", THEME_TYPE))
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
	SlotActionPopover.close_in(self)
	_rebuild_strip()
	_rebuild_slots()
	_rebuild_side()
	_rebuild_roster()


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


func _build_of(character_id: String) -> int:
	return int(_selected_builds.get(character_id, 0))


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


# --- 3つの枠 -------------------------------------------------------------

func _rebuild_slots() -> void:
	_clear(slots_box)
	_signatures.clear()
	var members: Array = GameManager.get_party_members()
	var hp_max: int = 1
	for character_id: String in _roster_ids():
		hp_max = maxi(hp_max, int(GameManager.get_effective_stats(character_id).get(GameStateKeys.STAT_HP, 0)))
	for slot_index: int in range(members.size()):
		slots_box.add_child(_make_slot(slot_index, str(members[slot_index]), hp_max))


func _make_slot(slot_index: int, character_id: String, hp_max: int) -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(slot_index)
	holder.name = "Slot_%d" % slot_index
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 余白を詰めた紙（⚠ 縦 720 に名簿まで収める）。
	holder.sheet.theme_type_variation = &"SortiePaperChosenPanel" if slot_index == _pick else &"SortiePaperPanel"
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	holder.sheet.add_child(body)

	# 番号（⚠ 1番＝いちばん前は赤）・写真・名前・役割・位置・Lv を1行に（⚠ 縦を詰める）。
	var hero: HBoxContainer = HBoxContainer.new()
	var number: Label = Label.new()
	number.theme_type_variation = &"SortieFrontNumberLabel" if slot_index == 0 else &"SortieNumberLabel"
	number.text = str(slot_index + 1)
	number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero.add_child(number)
	hero.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"photo", THEME_TYPE)))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(column)
	var position_label: Label = Label.new()
	position_label.name = "PositionLabel"
	position_label.theme_type_variation = &"CaptionLabel"
	position_label.text = tr(POSITION_KEYS[mini(slot_index, POSITION_KEYS.size() - 1)])
	column.add_child(position_label)
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

	var stats: Dictionary = GameManager.get_effective_stats(character_id)
	var hp: int = int(stats.get(GameStateKeys.STAT_HP, 0))
	body.add_child(_stat_line(tr("ui_training_stat_hp"), str(hp)))
	var bar: ProgressBar = ProgressBar.new()
	bar.theme_type_variation = &"LevelBar"
	bar.show_percentage = false
	bar.max_value = hp_max
	bar.value = hp
	body.add_child(bar)
	var main_key: String = GameStateKeys.STAT_MAG if int(stats.get(GameStateKeys.STAT_MAG, 0)) > int(stats.get(GameStateKeys.STAT_ATK, 0)) else GameStateKeys.STAT_ATK
	body.add_child(_stat_line(tr("ui_training_stat_" + main_key), str(int(stats.get(main_key, 0)))))

	# ビルド（⚠ 押すと吹き出しで1〜3を選ぶ＝当てる）。
	var build: Button = UiButton.create_paper_choice("")
	build.name = "Build_" + character_id
	build.text = _build_text(character_id) + " " + tr("ui_sortie_dropdown")
	build.alignment = HORIZONTAL_ALIGNMENT_LEFT
	build.pressed.connect(_on_build_pressed.bind(character_id, build))
	body.add_child(build)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)
	# ⚠ 署名の行（⚠ 出撃の準備だけ・人間「⚠ 2い」＝枠の中で書く）。⚠ 「出撃する」を押すと1番から順に書く。
	if not _is_barracks():
		var signature: SortieSignature = SortieSignature.create(character_id)
		signature.name = "Signature_%d" % slot_index
		body.add_child(signature)
		_signatures.append(signature)
	# ⚠ 下の段：「◀」隣と入れ替え ／ 案内 ／ 「▶」隣と入れ替え（⚠ 09-28 人間「⚠ 入れ替えは、上側でできるように　⚠ 右と左にボタンを作ってそこと入れ替え」）。
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	var left: Button = UiButton.create_paper_choice("ui_sortie_move_left")
	left.name = "MoveLeft_%d" % slot_index
	left.disabled = slot_index <= 0
	left.tooltip_text = tr("ui_sortie_move_left_hint")
	left.pressed.connect(_on_move_pressed.bind(slot_index, -1))
	foot.add_child(left)
	var hint: Label = Label.new()
	hint.name = "SwapHint"
	hint.theme_type_variation = &"AccentLabel" if slot_index == _pick else &"CaptionLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 折り返す（⚠ 選んだ枠の案内は長い＝1行のままだと枠が横に広がり、画面ごと左へずれた）。
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("ui_sortie_pick_hint") if slot_index == _pick else tr("ui_sortie_swap_hint")
	foot.add_child(hint)
	var right: Button = UiButton.create_paper_choice("ui_sortie_move_right")
	right.name = "MoveRight_%d" % slot_index
	right.disabled = slot_index >= GameStateKeys.PARTY_SLOT_COUNT - 1
	right.tooltip_text = tr("ui_sortie_move_right_hint")
	right.pressed.connect(_on_move_pressed.bind(slot_index, 1))
	foot.add_child(right)
	body.add_child(foot)
	# ⚠ 面ぜんぶを押せる（⚠ 中の「ビルド」「◀」「▶」は本物のボタンのまま生きる）。
	UiButton.attach_hit(holder.sheet, _on_slot_pressed.bind(slot_index))
	# ⚠ 脈打つ枠は**入れ替え元（押して選んだ枠）だけ**（⚠ 09-28 人間「⚠ ハイライトするのは入れ替えもとだけでいい」）。
	if slot_index == _pick:
		PulseFrame.attach(holder, PulseFrame.Strength.STRONG)
	return holder


# 「◀」「▶」：隣の枠と入れ替える（⚠ `set_party_member()` の1本＝別の枠にいる人を置くと交換になる）。
func _on_move_pressed(slot_index: int, step: int) -> void:
	var members: Array = GameManager.get_party_members()
	var other: int = slot_index + step
	if other < 0 or other >= members.size():
		return
	GameManager.set_party_member(other, str(members[slot_index]))
	_pick = -1
	_message = ""
	_rebuild()


func _stat_line(caption_text: String, value_text: String) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var value: Label = Label.new()
	value.text = value_text
	line.add_child(value)
	return line


func _build_text(character_id: String) -> String:
	var index: int = _build_of(character_id)
	var text: String = tr("ui_party_preset_build") % (index + 1)
	if not bool(GameManager.get_character_preset(character_id, index).get(GameStateKeys.PRESET_SAVED, false)):
		text += "（%s）" % tr("ui_party_preset_empty")
	return text


# 枠を押す＝名簿から入れる先にする（⚠ もう1回で取り消す）。
func _on_slot_pressed(slot_index: int) -> void:
	_pick = -1 if _pick == slot_index else slot_index
	_message = ""
	_rebuild()


# ビルドの吹き出し（⚠ 中身の無いビルドは押せない）。⚠ 選ぶと当てる（`apply_character_preset()`）。
func _on_build_pressed(character_id: String, anchor: Button) -> void:
	var pop: SlotActionPopover = SlotActionPopover.open(self, anchor.get_global_rect(), _name_of(character_id), tr("ui_sortie_build_note"))
	var presets: Array = GameManager.get_character_presets(character_id)
	for index: int in range(GameManager.get_character_preset_count()):
		var saved: bool = index < presets.size() and bool((presets[index] as Dictionary).get(GameStateKeys.PRESET_SAVED, false))
		var label: String = tr("ui_party_preset_build") % (index + 1)
		if not saved:
			label += "（%s）" % tr("ui_party_preset_empty")
		var button: UiButton = pop.add_action(label, UiButton.Variant.SECONDARY, _on_build_chosen.bind(character_id, index), not saved)
		button.name = "BuildChoice_%d" % index


func _on_build_chosen(character_id: String, index: int) -> void:
	var report: Dictionary = GameManager.apply_character_preset(character_id, index)
	if bool(report.get(GameManager.APPLY_OK, false)):
		_selected_builds[character_id] = index
	_message = GameManager.format_apply_report(report)
	_message_error = not bool(report.get(GameManager.APPLY_OK, false))
	_rebuild()


# --- 右：編成の控え ---------------------------------------------------------

func _rebuild_side() -> void:
	_clear(side)
	# ⚠ 潜る深さ（2026-10-03・決定49・モック Q8 A案「難ダンジョンを1枚にまとめる」）。⚠ 新しく入るときだけ（⚠ 続きからは出さない）。
	if _is_new_dungeon_entry():
		side.add_child(_build_depth_sheet())
	var holder: TiltedSheet = TiltedSheet.create(2)
	holder.name = "Reserve"
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.sheet.theme_type_variation = &"SortiePaperPanel"
	side.add_child(holder)
	var body: VBoxContainer = VBoxContainer.new()
	holder.sheet.add_child(body)
	var presets: Array = GameManager.get_party_presets()
	# ⚠ 潜る深さを出すときは控えを ▼ の1行に縮める（⚠ モック Q8 A案「控え1 いまと同じ ▼」・縦 720 に収めるため）。
	if _is_new_dungeon_entry():
		holder.size_flags_vertical = Control.SIZE_SHRINK_END
		body.add_child(_build_preset_picker(presets))
		_add_preset_buttons(body, presets)
		return
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_barracks_reserve"
	heading.right_text = tr("ui_sortie_reserve_count") % GameManager.get_party_preset_count()
	body.add_child(heading)
	var face: int = get_theme_constant(&"mini_photo", THEME_TYPE)
	# ⚠ 8行は縦に長い（⚠ 詰所は下に施設の帯がある＝1枚目の絵で名簿が帯の裏に隠れた）＝⚠ 一覧だけ縦に流す。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PresetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "PresetRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for index: int in range(GameManager.get_party_preset_count()):
		var preset: Variant = presets[index] if index < presets.size() else null
		var row: LedgerRow = LedgerRow.new()
		row.name = "Preset_%d" % index
		row.compact = true
		row.selected = index == _preset_pick
		row.pressed.connect(_on_preset_row_pressed.bind(index))
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)
		var number: Label = Label.new()
		number.theme_type_variation = &"SmallLabel"
		number.text = str(index + 1)
		line.add_child(number)
		if _is_saved(preset):
			for entry: Variant in _preset_slots(preset):
				line.add_child(CharacterAvatar.create(str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, "")), face))
		else:
			var empty: Label = Label.new()
			empty.theme_type_variation = &"CaptionLabel"
			empty.text = tr("ui_party_preset_empty")
			line.add_child(empty)
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(gap)
		if _is_saved(preset) and _matches_now(preset):
			var stamp: Stamp = Stamp.new()
			stamp.name = "SameStamp"
			stamp.label_key = "ui_sortie_same"
			line.add_child(stamp)
		rows.add_child(row)
	_add_preset_buttons(body, presets)


# 「呼ぶ」「いまを残す」（⚠ 一覧のときも ▼ のときも同じ2つ）。
func _add_preset_buttons(body: VBoxContainer, presets: Array) -> void:
	var buttons: HBoxContainer = HBoxContainer.new()
	body.add_child(buttons)
	var call_button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_barracks_call")
	call_button.name = "CallButton"
	call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_button.disabled = not _is_saved(presets[_preset_pick] if _preset_pick < presets.size() else null)
	call_button.pressed.connect(_on_call_pressed)
	buttons.add_child(call_button)
	var keep_button: Button = UiButton.create_paper_choice("ui_sortie_keep")
	keep_button.name = "KeepButton"
	keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep_button.pressed.connect(_on_keep_pressed)
	buttons.add_child(keep_button)


# 控えを ▼ で選ぶ1行（⚠ モック Q8 A案）。⚠ 選ぶと一覧の行を押したのと同じ（`_on_preset_row_pressed()`）。
func _build_preset_picker(presets: Array) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "PresetPickerLine"
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_barracks_reserve")
	line.add_child(caption)
	var picker: MenuButton = MenuButton.new()
	picker.name = "PresetPicker"
	picker.theme_type_variation = &"PaperChoice"
	picker.flat = false
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.text = "%s ▼" % _preset_label(_preset_pick, presets)
	var popup: PopupMenu = picker.get_popup()
	for index: int in range(GameManager.get_party_preset_count()):
		popup.add_item(_preset_label(index, presets), index)
	popup.id_pressed.connect(_on_preset_picked)
	line.add_child(picker)
	return line


# ⚠ 窓（PopupMenu）の合図の中で作り直さない（⚠ 次のフレームで）。
func _on_preset_picked(index: int) -> void:
	_preset_pick = index
	_rebuild_side.call_deferred()


# 「控え1 いまと同じ」／「控え2 空き」。
func _preset_label(index: int, presets: Array) -> String:
	var preset: Variant = presets[index] if index < presets.size() else null
	var state: String = tr("ui_party_preset_empty")
	if _is_saved(preset):
		state = tr("ui_sortie_same") if _matches_now(preset) else ""
	return ("%s%d %s" % [tr("ui_sortie_preset_short"), index + 1, state]).strip_edges()


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
	var options: Array[int] = GameManager.get_dungeon_start_floor_options(_dungeon_id)
	var chosen: int = _chosen_start_floor()
	var per_floor: int = GameManager.get_dungeon_layers_per_floor(_dungeon_id)
	var first_layer: int = (chosen - 1) * per_floor + 1
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "Depth"
	holder.sheet.theme_type_variation = &"SortiePaperPanel"
	var body: VBoxContainer = VBoxContainer.new()
	holder.sheet.add_child(body)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_depth_title"
	heading.right_text = tr("ui_depth_step") % per_floor
	body.add_child(heading)
	var row: HBoxContainer = HBoxContainer.new()
	body.add_child(row)
	var gauge: DepthGauge = DepthGauge.new()
	gauge.name = "DepthGauge"
	gauge.max_floors = GameManager.get_dungeon_max_floors()
	gauge.layers_per_floor = per_floor
	gauge.best_floor = GameManager.get_dungeon_best_floors(_dungeon_id)
	gauge.deepest_start = options[options.size() - 1] if not options.is_empty() else 1
	gauge.start_floor = chosen
	gauge.floor_picked.connect(_on_depth_picked)
	row.add_child(gauge)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var from: Label = Label.new()
	from.name = "FromExitLabel"
	from.theme_type_variation = &"CaptionLabel"
	from.text = tr("ui_depth_from_entrance") if chosen <= 1 else tr("ui_depth_from_exit") % (first_layer - 1)
	info.add_child(from)
	var big_line: HBoxContainer = HBoxContainer.new()
	info.add_child(big_line)
	var big: Label = Label.new()
	big.name = "StartLayerLabel"
	big.theme_type_variation = &"DepthBigLabel"
	big.text = str(first_layer)
	big_line.add_child(big)
	var unit: Label = Label.new()
	unit.text = tr("ui_depth_from")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	big_line.add_child(unit)
	var next_exit: Label = Label.new()
	next_exit.name = "NextExitLabel"
	next_exit.theme_type_variation = &"SmallLabel"
	next_exit.text = tr("ui_depth_next_exit") % (chosen * per_floor)
	info.add_child(next_exit)
	# ⚠ 出るものの下限（2026-10-03・回4-b・手本 DungeonGate「出るものの下限［等級◯以上］」）。⚠ 入る層の帯で決まる。
	var equip_floor: Label = Label.new()
	equip_floor.name = "EquipGradeLabel"
	equip_floor.theme_type_variation = &"SmallLabel"
	equip_floor.text = tr("ui_depth_equip_grade") % GameManager.get_dungeon_equip_grade_range(_dungeon_id, first_layer).x
	info.add_child(equip_floor)
	# −10 ／ +10 ／ 最深へ（⚠ 端は押せない）。
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "DepthButtons"
	body.add_child(buttons)
	var deepest: int = options[options.size() - 1] if not options.is_empty() else 1
	for spec: Array in [
		["DepthMinusButton", tr("ui_depth_minus") % per_floor, chosen - 1, chosen <= 1],
		["DepthPlusButton", tr("ui_depth_plus") % per_floor, chosen + 1, chosen >= deepest],
		["DepthDeepestButton", tr("ui_depth_deepest"), deepest, chosen >= deepest],
	]:
		var button: Button = UiButton.create_paper_choice("")
		button.theme_type_variation = &"DepthStepButton"
		button.name = str(spec[0])
		button.text = str(spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(spec[3])
		button.pressed.connect(_on_depth_picked.bind(int(spec[2])))
		buttons.add_child(button)
	return holder


func _on_depth_picked(start_floor: int) -> void:
	if not (start_floor in GameManager.get_dungeon_start_floor_options(_dungeon_id)):
		return
	_start_floor = start_floor
	# ⚠ 押したボタンを押している最中に作り直さない（⚠ 次のフレームで）。
	_rebuild_side.call_deferred()


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
		if int(entry.get(GameStateKeys.PRESET_INDEX, 0)) != _build_of(str(members[i])):
			return false
	return true


func _on_preset_row_pressed(index: int) -> void:
	_preset_pick = index
	_rebuild_side()


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
	if bool(applied.get(GameManager.APPLY_OK, false)):
		for entry: Variant in _preset_slots(GameManager.get_party_presets()[index]):
			_selected_builds[str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))] = \
				int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
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
		order.add_child(CharacterAvatar.create(str((slots[i] as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, "")), get_theme_constant(&"mini_photo", THEME_TYPE)))
		var n: Label = Label.new()
		n.text = str(i + 1)
		order.add_child(n)
	box.add_child(order)
	var changes: Array[String] = []
	for entry: Variant in slots:
		var character_id: String = str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var to_index: int = int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
		if to_index != _build_of(character_id):
			changes.append("%s %s → %s" % [_name_of(character_id), tr("ui_party_preset_build") % (_build_of(character_id) + 1), tr("ui_party_preset_build") % (to_index + 1)])
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
		slots.append({
			GameStateKeys.PRESET_CHARACTER_ID: str(member),
			GameStateKeys.PRESET_INDEX: _build_of(str(member)),
		})
	if GameManager.save_party_preset(index, slots):
		_say(tr("ui_barracks_kept") % (index + 1))
	_rebuild()


# --- 下：名簿 ＋ 右下のボタン ----------------------------------------------

# ⚠ 本番のキャラ → 検証用（⚠ 検証用はデバッグビルドだけ・薄く＝人間のモック Q10）。
func _roster_ids() -> Array[String]:
	var ids: Array[String] = []
	var debug_ids: Array[String] = []
	for raw: Variant in GameManager.get_party_candidates():
		var id: String = str(raw)
		if GameManager.is_debug_character(id):
			debug_ids.append(id)
		else:
			ids.append(id)
	if _sort == SORT_NAME:
		ids.sort_custom(func(a: String, b: String) -> bool: return _name_of(a) < _name_of(b))
	else:
		ids.sort_custom(func(a: String, b: String) -> bool: return _level_of(a) > _level_of(b))
	ids.append_array(debug_ids)
	return ids


func _rebuild_roster() -> void:
	_clear(roster_body)
	# ⚠ 名簿の板そのものは光らせない（⚠ 09-28 人間「⚠ ハイライトするのは入れ替えもとだけでいい」）。
	#   ⚠ 代わりに**出撃していない人の札**を光らせる（⚠ 同「⚠ 出撃してない人だけハイライトしてわかるようにする」）。
	var title_column: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_sortie_roster")
	title_column.add_child(title)
	var count: Label = Label.new()
	count.name = "RosterHint"
	# ⚠ 選んでいる間の案内は強調の色（⚠ 目に入るように）。
	count.theme_type_variation = &"AccentLabel" if _pick >= 0 else &"CaptionLabel"
	count.text = tr("ui_sortie_roster_for") % [_pick + 1, tr(POSITION_KEYS[_pick])] if _pick >= 0 else tr("ui_sortie_roster_hint")
	title_column.add_child(count)
	var sort_row: HBoxContainer = HBoxContainer.new()
	# ⚠ 暗い板の上なので革のボタン（⚠ 紙の札は字が墨で読めない）。⚠ 選んでいる並びは Secondary・ほかは Ghost。
	for spec: Array in [[SORT_LEVEL, "ui_sortie_sort_level"], [SORT_NAME, "ui_sortie_sort_name"]]:
		var sort: UiButton = UiButton.create(
			UiButton.Variant.SECONDARY if _sort == str(spec[0]) else UiButton.Variant.GHOST, str(spec[1]))
		sort.name = "Sort_" + str(spec[0])
		sort.pressed.connect(_on_sort_pressed.bind(str(spec[0])))
		sort_row.add_child(sort)
	title_column.add_child(sort_row)
	roster_body.add_child(title_column)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "RosterScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_body.add_child(scroll)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.name = "RosterCards"
	scroll.add_child(cards)
	var members: Array = GameManager.get_party_members()
	var debug_alpha: float = float(get_theme_constant(&"chip_debug_alpha_pct", TRAINING_THEME_TYPE)) / 100.0
	for character_id: String in _roster_ids():
		var card: PaperSheet = PaperSheet.new()
		card.name = "Roster_" + character_id
		card.show_corners = false
		card.theme_type_variation = &"SortieTightPaperPanel"
		card.custom_minimum_size.x = float(get_theme_constant(&"roster_card", THEME_TYPE))
		if GameManager.is_debug_character(character_id):
			card.modulate.a = debug_alpha
		var column: VBoxContainer = VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(column)
		var in_slot: int = members.find(character_id)
		var badge: Label = Label.new()
		badge.name = "Badge"
		badge.theme_type_variation = &"AccentLabel"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if in_slot >= 0 and _pick >= 0 and in_slot != _pick:
			badge.text = tr("ui_sortie_swap_with") % (in_slot + 1)
		elif in_slot >= 0:
			badge.text = tr("ui_sortie_in_slot") % (in_slot + 1)
		else:
			badge.text = tr("ui_sortie_not_out")
		column.add_child(badge)
		var avatar: CharacterAvatar = CharacterAvatar.create(character_id, get_theme_constant(&"roster_photo", THEME_TYPE))
		column.add_child(avatar)
		var name_label: Label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text = _name_of(character_id)
		column.add_child(name_label)
		var level: Label = Label.new()
		level.theme_type_variation = &"CaptionLabel"
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level.text = "%s %d" % [tr("ui_dossier_lv"), _level_of(character_id)]
		column.add_child(level)
		UiButton.attach_hit(card, _on_roster_pressed.bind(character_id))
		# ⚠ 出撃していない人だけ光らせる（⚠ 09-28 人間「⚠ 出撃してない人だけハイライトしてわかるようにする」）。
		#   ⚠ 名簿はスクロールの中＝外へ広げると切れるので内側に引く。
		if in_slot < 0:
			var glow: PulseFrame = PulseFrame.attach(card, PulseFrame.Strength.STRONG)
			glow.inward = true
		cards.add_child(card)

	# 右下のボタン（⚠ 出撃の準備＝出撃する ／ 詰所＝選んだ人を育成で開く）。
	var actions: VBoxContainer = VBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_END
	roster_body.add_child(actions)
	# ⚠ 10-06（`NAV-18`）：⚠ 出撃の準備でも出す（⚠ 前は詰所だけ＝装備を替えるのに依頼を選び直していた）。
	var open: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_sortie_open_training")
	open.name = "OpenTrainingButton"
	open.pressed.connect(_on_open_training_pressed)
	actions.add_child(open)
	if _is_barracks():
		return
	# ⚠ 「周回する」は置かない（⚠ 2026-09-28・人間「⚠ 周回の時は編成画面はいらない」＝周回は掲示板でその場で回す）。
	var go: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_quest_sortie_go")
	go.name = "SortieButton"
	go.pressed.connect(_on_sortie_pressed)
	actions.add_child(go)


func _on_sort_pressed(sort: String) -> void:
	_sort = sort
	_rebuild_roster()


# 名簿の札を押す：⚠ 枠を選んでいれば、そこへ入れる（⚠ 別の枠にいる人なら入れ替わる＝`set_party_member()` の1本）。
#   ⚠ 枠を選んでいなければ、⚠ その人を選ぶだけ（⚠ 詰所の「選んだ人を育成で開く」の相手）。
func _on_roster_pressed(character_id: String) -> void:
	if _pick < 0:
		_roster_pick = character_id
		_say(tr("ui_sortie_roster_picked") % _name_of(character_id))
		return
	GameManager.set_party_member(_pick, character_id)
	_pick = -1
	_message = ""
	_rebuild()


func _on_open_training_pressed() -> void:
	var target: String = _roster_pick
	if target == "":
		var members: Array = GameManager.get_party_members()
		target = str(members[0]) if not members.is_empty() else ""
	# ⚠ 10-06（`NAV-18`）：⚠ 寄り道＝育成の「戻る」で、この画面（⚠ 同じ依頼・同じ深さ）へ戻る。
	SceneManager.open_detour(TRAINING_PATH, {TransferKeys.CHARACTER_ID: target}, PARTY_PRESET_PATH, {
		TransferKeys.RETURN_PATH: _return_path,
		TransferKeys.SORTIE_STAGE_ID: _stage_id,
		TransferKeys.SORTIE_DUNGEON_ID: _dungeon_id,
		TransferKeys.SORTIE_START_FLOOR: _start_floor,
	})


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
	var tween: Tween = create_tween()
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
		{SortieGuide.KEY_TARGETS: [$Margin/Layout/Roster as Control], SortieGuide.KEY_TITLE: "ui_sortie_guide_2_title", SortieGuide.KEY_BODY: "ui_sortie_guide_2_body"},
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
	SceneManager.change_scene(_return_path)


# 入手先の窓から戻ってきたときの姿（⚠ 同じ依頼・同じ深さの出撃の準備）。
func _source_return_data() -> Dictionary:
	return {
		TransferKeys.RETURN_PATH: _return_path, TransferKeys.SORTIE_STAGE_ID: _stage_id,
		TransferKeys.SORTIE_DUNGEON_ID: _dungeon_id, TransferKeys.SORTIE_START_FLOOR: _start_floor,
	}
