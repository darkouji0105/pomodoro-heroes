# res://scenes/adventure/party_preset_screen.gd
# 詰所（編成）。⚠ ファイル名はパーティ選択のまま（⚠ 入口が2つ＝施設の帯と冒険の選択）。
#
# ⚠⚠ 2026-09-27（回UI-組 詰所・手本 Barracks・決定 `NAV-11`）：⚠ **作り替えた**。
#   ⚠ 上に傾いた身上書カード3枚（⚠ 名前・役割・Lv・HP・主な値・スキル・ビルド ／ 上がれるなら「昇級できる」の判 ／ 「開く ›」で育成へ）。
#   ⚠ 下の紙の左に出撃届（⚠ 並びの順に前へ出る）・右に編成の控え（⚠ 8件の札）。
#   ⚠ 人間「⚠ 1い」＝出撃届は「並べ替える」を押してから2つの枠を押すと入れ替わる。⚠ **候補の差し替えは無い**
#     （⚠ 前のキャラのプルダウンはやめた＝検証用キャラは入れられない）。
#   ⚠ 人間「⚠ 2あ」＝カードの「ビルド」の行を押すと番号が1つ進む（⚠ 控えに残すときの参照先。⚠ 状態は変えない）。
#     ⚠ 「焼く」は詰所から外した（⚠ 育成の概要にある）。
#   ⚠ 人間「⚠ 3い」＝控えは8件の札。⚠ 札を押すと吹き出しで「呼ぶ／残す／消す」。
#   ⚠ 入れていない：写真（⚠ 顔の絵待ち＝`CharacterAvatar`）／ 3人のひとこと（⚠ 台詞のデータが無い）／ 留め針。
#
# ⚠ 装備を選ぶ欄は作らない（GAME_DESIGN 13章「装備の変更はできない。ギルドで行う」）。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。remove_child() してから queue_free()。

extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const THEME_TYPE: StringName = &"Barracks"
# ⚠ 写真の大きさは育成の身上書と同じ値を引く（⚠ 2つ目の値を作らない）。
const TRAINING_THEME_TYPE: StringName = &"Training"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var cards_box: HBoxContainer = $Margin/Layout/Cards
@onready var bottom_body: HBoxContainer = $Margin/Layout/Bottom/Body

# 「戻る」で帰る先。入口が2つあるので来た側が渡す（TransferKeys.RETURN_PATH）。
var _return_path: String = BASE_PATH

# ⚠ キャラごとに「いまどのビルド番号を指しているか」（character_id -> int）。
#   ⚠ 押しただけでは状態を触らない（EXEC_SKILL_SELECT.md §8-1 と同じ形）。控えに残すときの参照先を決めるだけ。
var _selected_builds: Dictionary = {}

# ⚠ 並べ替えの途中か ／ 1つ目に押した枠（⚠ -1 なら未選択）。
var _reordering: bool = false
var _pick: int = -1

# ⚠ 吹き出しを開いている控えの番号（⚠ -1 なら閉じている）。
var _open_preset: int = -1
# ⚠ 控えの見出しの右に出す結果の1行（⚠ 空なら案内の文）。
var _message: String = ""

var _sortie_box: VBoxContainer = null
var _reserve_box: VBoxContainer = null


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	var path: String = str(data.get(TransferKeys.RETURN_PATH, ""))
	if path != "":
		_return_path = path

	header.back_pressed.connect(_on_back_pressed)
	# ⚠ 2026-09-26（回UI-3）：⚠ 拠点から来たときだけ施設の帯を出す（⚠ 詰所）。
	#   ⚠ 冒険の選択から来たとき（⚠ 出撃の直前）は出さない＝行き来の途中に入口を増やさない。
	if _return_path == BASE_PATH:
		BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.BARRACKS)

	_sortie_box = VBoxContainer.new()
	_sortie_box.name = "Sortie"
	_sortie_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_body.add_child(_sortie_box)
	bottom_body.add_child(VSeparator.new())
	_reserve_box = VBoxContainer.new()
	_reserve_box.name = "Reserve"
	_reserve_box.custom_minimum_size.x = float(get_theme_constant(&"reserve_width", THEME_TYPE))
	bottom_body.add_child(_reserve_box)

	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	_rebuild()


func _rebuild() -> void:
	SlotActionPopover.close_in(self)
	_open_preset = -1
	_rebuild_cards()
	_rebuild_sortie()
	_rebuild_reserve()


func _clear(box: Node) -> void:
	# ⚠ queue_free() だけだと、同じフレームに2本作ると行が二重に並ぶ（AGENTS.md）。
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _name_of(character_id: String) -> String:
	return tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))


func _build_of(character_id: String) -> int:
	return int(_selected_builds.get(character_id, 0))


# --- 身上書カード（上の3枚） ------------------------------------------

# ⚠ カードの並びは characters.json の順（⚠ 出撃届を並べ替えてもカードは動かない＝手本と同じ）。
func _card_order() -> Array[String]:
	var members: Array = GameManager.get_party_members()
	var ids: Array[String] = []
	for raw: Variant in MasterDataLoader.get_all_characters():
		if str(raw) in members:
			ids.append(str(raw))
	return ids


func _rebuild_cards() -> void:
	_clear(cards_box)
	var index: int = 0
	for character_id: String in _card_order():
		cards_box.add_child(_make_card(index, character_id))
		index += 1


func _make_card(index: int, character_id: String) -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(index)
	holder.name = "Card_" + character_id
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	holder.sheet.add_child(body)

	body.add_child(_make_card_hero(character_id))
	body.add_child(HSeparator.new())

	var stats: Dictionary = GameManager.get_effective_stats(character_id)
	body.add_child(_make_stat_row(GameStateKeys.STAT_HP, stats))
	body.add_child(_make_stat_row(_main_stat_of(stats), stats))
	body.add_child(_make_text_row("Skills", tr("ui_training_skill"), _skills_text(character_id)))

	# ⚠ ビルドの行だけ押せる（人間「⚠ 2あ」＝番号が1つ進む・状態は変えない）。
	var build: LedgerRow = _make_text_row("Build_" + character_id, tr("ui_training_build"), _build_text(character_id))
	build.mouse_filter = Control.MOUSE_FILTER_STOP
	build.show_rule = false
	build.tooltip_text = tr("ui_barracks_build_hint")
	build.pressed.connect(_on_build_pressed.bind(character_id))
	body.add_child(build)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)

	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	if _can_level_up(character_id):
		var stamp: Stamp = Stamp.new()
		stamp.name = "LevelUpStamp"
		stamp.label_key = "ui_barracks_can_level_up"
		foot.add_child(stamp)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(gap)
	var open: Button = UiButton.create_paper_choice("ui_barracks_open")
	open.name = "OpenButton"
	open.size_flags_vertical = Control.SIZE_SHRINK_END
	open.pressed.connect(_on_open_pressed.bind(character_id))
	foot.add_child(open)
	body.add_child(foot)
	return holder


# 写真・「身上書」・名前・役割・Lv。⚠ 育成の身上書（`CharacterDossier`）と同じ型の字を使う。
func _make_card_hero(character_id: String) -> HBoxContainer:
	var hero: HBoxContainer = HBoxContainer.new()
	hero.name = "Hero"
	hero.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"dossier_photo", TRAINING_THEME_TYPE)))

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(column)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_dossier_title")
	column.add_child(caption)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"DossierNameLabel"
	name_label.text = _name_of(character_id)
	column.add_child(name_label)
	var role: Label = Label.new()
	role.theme_type_variation = &"CaptionLabel"
	# ⚠ 役割は `characters.json` に欄が無い。⚠ 検証用はIDをそのまま出す（⚠ 身上書と同じ）。
	role.text = character_id if GameManager.is_debug_character(character_id) else tr("ui_role_" + character_id)
	column.add_child(role)

	var level_row: HBoxContainer = HBoxContainer.new()
	level_row.name = "LevelRow"
	var lv: Label = Label.new()
	lv.theme_type_variation = &"CaptionLabel"
	lv.text = tr("ui_dossier_lv")
	lv.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(lv)
	var value: Label = Label.new()
	value.name = "LevelLabel"
	value.theme_type_variation = &"DossierLevelLabel"
	value.text = str(_level_of(character_id))
	level_row.add_child(value)
	var of_cap: Label = Label.new()
	of_cap.theme_type_variation = &"CaptionLabel"
	of_cap.text = "/ %d" % GameManager.get_effective_level_cap(character_id)
	of_cap.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(of_cap)
	column.add_child(level_row)
	return hero


# 「HP ………… 120」。⚠ 押せない台帳の行（⚠ 罫だけ借りる）。
func _make_stat_row(stat_key: String, stats: Dictionary) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Stat_" + stat_key
	row.compact = true
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var label: Label = Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.text = tr("ui_training_stat_" + stat_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	var amount: int = int(stats.get(stat_key, 0))
	value.text = "%d%%" % amount if GameManager.is_percent_stat(stat_key) else str(amount)
	line.add_child(value)
	return row


# 「スキル  強撃・［空き］」の形。⚠ 左の小さな見出し ＋ 中身。
func _make_text_row(row_name: String, caption_text: String, value_text: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.compact = true
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.custom_minimum_size.x = float(get_theme_constant(&"dossier_photo", TRAINING_THEME_TYPE)) * 0.66
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.theme_type_variation = &"SmallLabel"
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(value)
	return row


# ⚠ 主な値は「攻撃」か「魔力」の大きいほう（⚠ 手本は HP と攻撃。⚠ 僧侶の手本は「[攻]」の仮のまま）。
func _main_stat_of(stats: Dictionary) -> String:
	if int(stats.get(GameStateKeys.STAT_MAG, 0)) > int(stats.get(GameStateKeys.STAT_ATK, 0)):
		return GameStateKeys.STAT_MAG
	return GameStateKeys.STAT_ATK


func _skills_text(character_id: String) -> String:
	var parts: Array[String] = []
	var selected: Array = GameManager.get_selected_skills(character_id, GameManager.SLOT_KIND_SKILL)
	for i: int in range(GameManager.get_skill_slot_count()):
		var skill_id: String = str(selected[i]) if i < selected.size() else ""
		if skill_id == "":
			parts.append(tr("ui_barracks_skill_empty"))
		else:
			parts.append(tr(str(MasterDataLoader.get_skill(skill_id).get("name_key", skill_id))))
	return tr("ui_barracks_skill_separator").join(parts)


func _build_text(character_id: String) -> String:
	var index: int = _build_of(character_id)
	var text: String = tr("ui_party_preset_build") % (index + 1)
	if not bool(GameManager.get_character_preset(character_id, index).get(GameStateKeys.PRESET_SAVED, false)):
		text += "（%s）" % tr("ui_party_preset_empty")
	return text


# ⚠ 判定は育成の概要の「昇級させる」と同じ2つ（⚠ 上限 ／ 素材）。
func _can_level_up(character_id: String) -> bool:
	if _level_of(character_id) >= GameManager.get_effective_level_cap(character_id):
		return false
	var cost: Dictionary = GameManager.get_level_up_cost(character_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	return material_id != "" and GameManager.get_material_count(material_id) >= amount


func _level_of(character_id: String) -> int:
	return int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))


func _on_build_pressed(character_id: String) -> void:
	# ⚠ ここでは状態を触らない。控えに残すときの参照先が変わるだけ。
	_selected_builds[character_id] = (_build_of(character_id) + 1) % GameManager.get_character_preset_count()
	_message = ""
	_rebuild()


func _on_open_pressed(character_id: String) -> void:
	SceneManager.change_scene_with_data(TRAINING_PATH, {TransferKeys.CHARACTER_ID: character_id})


# --- 出撃届（下の左） --------------------------------------------------

func _rebuild_sortie() -> void:
	_clear(_sortie_box)
	_sortie_box.add_child(_make_block_head("ui_barracks_sortie",
		"ui_barracks_reorder_hint" if _reordering else "ui_barracks_sortie_hint", "SortieHint"))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SortieRow"
	row.theme_type_variation = &"BarracksSortieRow"
	_sortie_box.add_child(row)
	var members: Array = GameManager.get_party_members()
	var photo: int = get_theme_constant(&"sortie_photo", THEME_TYPE)
	for slot_index: int in range(members.size()):
		var character_id: String = str(members[slot_index])
		var slot: LedgerRow = LedgerRow.new()
		slot.name = "Sortie_%d" % slot_index
		slot.compact = true
		slot.show_rule = false
		slot.selected = slot_index == _pick
		# ⚠ 並べ替えの途中だけ押せる（⚠ 押しても `_on_sortie_pressed()` が弾く）。
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if _reordering else Control.MOUSE_FILTER_IGNORE
		slot.pressed.connect(_on_sortie_pressed.bind(slot_index))
		var line: HBoxContainer = HBoxContainer.new()
		slot.add_child(line)
		var number: Label = Label.new()
		number.theme_type_variation = &"MutedLabel"
		number.text = str(slot_index + 1)
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(number)
		line.add_child(CharacterAvatar.create(character_id, photo))
		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = _name_of(character_id)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name_label)
		row.add_child(slot)

	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var reorder: UiButton = UiButton.create(UiButton.Variant.SECONDARY,
		"ui_barracks_reorder_done" if _reordering else "ui_barracks_reorder")
	reorder.name = "ReorderButton"
	reorder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reorder.pressed.connect(_on_reorder_pressed)
	row.add_child(reorder)


# 「出撃届 ………… 並びの順に前へ出る」の形の見出し。
func _make_block_head(title_key: String, hint_key: String, hint_name: String) -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr(title_key)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hint: Label = Label.new()
	hint.name = hint_name
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr(hint_key)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(hint)
	return head


func _on_reorder_pressed() -> void:
	_reordering = not _reordering
	_pick = -1
	_message = ""
	_rebuild()


# ⚠ 1つ目を押すと選ぶ ／ 同じ枠をもう1回で取り消す ／ 2つ目で入れ替える（人間「⚠ 1い」）。
# ⚠ 入れ替えは `set_party_member()` の1本（⚠ 別の枠に居るキャラを置くと交換になる＝空き枠を作らない）。
func _on_sortie_pressed(slot_index: int) -> void:
	if not _reordering:
		return
	if _pick < 0:
		_pick = slot_index
	elif _pick == slot_index:
		_pick = -1
	else:
		var members: Array = GameManager.get_party_members()
		GameManager.set_party_member(_pick, str(members[slot_index]))
		_pick = -1
	_rebuild()


# --- 編成の控え（下の右・8件の札） -------------------------------------

func _rebuild_reserve() -> void:
	_clear(_reserve_box)
	var head: HBoxContainer = _make_block_head("ui_barracks_reserve", "ui_barracks_reserve_hint", "MessageLabel")
	if _message != "":
		var message: Label = head.get_node("MessageLabel") as Label
		message.theme_type_variation = &"AccentLabel"
		message.text = _message
		message.tooltip_text = _message
		message.mouse_filter = Control.MOUSE_FILTER_PASS
		message.clip_text = true
		message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reserve_box.add_child(head)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reserve_box.add_child(spacer)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PresetRow"
	row.theme_type_variation = &"BarracksPresetRow"
	_reserve_box.add_child(row)
	var presets: Array = GameManager.get_party_presets()
	# ⚠ 8 と書かない。件数は GameManager から引く。
	for index: int in range(GameManager.get_party_preset_count()):
		var preset: Variant = presets[index] if index < presets.size() else null
		row.add_child(_make_preset_tab(index, preset))


# 控えの札1枚：番号 ／ 「僧弓剣」か「空き」。⚠ 札は素の `Button`（`PaperChoice`）に字を2段で重ねる。
func _make_preset_tab(index: int, preset: Variant) -> Button:
	var saved: bool = _is_saved(preset)
	var tab: Button = UiButton.create_paper_choice("")
	tab.name = "Preset_%d" % index
	tab.theme_type_variation = &"PaperChoiceSelected" if index == _open_preset else &"PaperChoice"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.custom_minimum_size.y = float(get_theme_constant(&"preset_height", THEME_TYPE))
	tab.tooltip_text = _summarize(preset) if saved else tr("ui_party_preset_empty")
	if not saved:
		tab.modulate.a = float(get_theme_constant(&"preset_empty_alpha_pct", THEME_TYPE)) / 100.0
	tab.pressed.connect(_on_preset_pressed.bind(index))

	var stack: VBoxContainer = VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(stack)
	var number: Label = Label.new()
	number.text = str(index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(number)
	var short: Label = Label.new()
	short.name = "ShortLabel"
	short.theme_type_variation = &"CaptionLabel"
	short.text = _short(preset) if saved else tr("ui_party_preset_empty")
	short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(short)
	return tab


func _is_saved(preset: Variant) -> bool:
	return preset is Dictionary and bool((preset as Dictionary).get(GameStateKeys.PRESET_SAVED, false))


func _preset_slots(preset: Variant) -> Array:
	if not (preset is Dictionary):
		return []
	var slots: Variant = (preset as Dictionary).get(GameStateKeys.PRESET_SLOTS, [])
	return slots as Array if slots is Array else []


# 札の2段目：名前の頭の1字を並びの順に（「僧弓剣」）。
func _short(preset: Variant) -> String:
	var text: String = ""
	for entry: Variant in _preset_slots(preset):
		if entry is Dictionary:
			text += _name_of(str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))).left(1)
	return text


# 「僧侶 ビルド1 / 弓兵 ビルド3 / 剣士 ビルド1」の形。
#
# ⚠ 中身は複製せず、参照先を読んで組み立てる（参照方式なので、キャラ側のビルドを
#   直すとここの表示も次の再描画で追従する）。
# ⚠ 当初は「僧侶(1)」と括弧の数字だけにしていたが、⚠ 何番のビルドか読めなかった
#   （人間の指摘・2026-08-23）。⚠ カードの「ビルド」の行と同じ ui_party_preset_build を使うこと。
func _summarize(preset: Variant) -> String:
	var parts: Array[String] = []
	for entry: Variant in _preset_slots(preset):
		if not (entry is Dictionary):
			continue
		var character_id: String = str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var preset_index: int = int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
		parts.append("%s %s" % [_name_of(character_id), tr("ui_party_preset_build") % (preset_index + 1)])
	return " / ".join(parts)


# 札を押すと吹き出し（「呼ぶ／残す／消す」）。⚠ 同じ札をもう1回で閉じる。
# ⚠ ここでは札を作り直さない（⚠ 作ったばかりの札は並べ終わる前で、⚠ 位置が取れない＝吹き出しが左上に出る）。
func _on_preset_pressed(index: int) -> void:
	SlotActionPopover.close_in(self)
	_open_preset = -1 if _open_preset == index else index
	var tab: Button = null
	for i: int in range(GameManager.get_party_preset_count()):
		var each: Button = _reserve_box.find_child("Preset_%d" % i, true, false) as Button
		if each == null:
			continue
		each.theme_type_variation = &"PaperChoiceSelected" if i == _open_preset else &"PaperChoice"
		if i == index:
			tab = each
	if _open_preset < 0 or tab == null:
		return
	var presets: Array = GameManager.get_party_presets()
	var preset: Variant = presets[index] if index < presets.size() else null
	var saved: bool = _is_saved(preset)
	var pop: SlotActionPopover = SlotActionPopover.open(
		self, tab.get_global_rect(), tr("ui_party_preset_slot") % (index + 1),
		_summarize(preset) if saved else tr("ui_party_preset_empty")
	)
	# ⚠ 押せないものは disabled で出す（⚠ 押してから弾かない）。
	var call_button: UiButton = pop.add_action(tr("ui_barracks_call"), UiButton.Variant.PRIMARY, _on_call_pressed.bind(index), not saved)
	call_button.name = "CallButton"
	var keep_button: UiButton = pop.add_action(tr("ui_barracks_keep"), UiButton.Variant.SECONDARY, _on_keep_pressed.bind(index))
	keep_button.name = "KeepButton"
	var clear_button: UiButton = pop.add_action(tr("ui_party_preset_clear"), UiButton.Variant.DANGER, _on_clear_pressed.bind(index), not saved)
	clear_button.name = "ClearButton"


# 呼ぶ＝その控えを編成に当てる。⚠ 文面は GameManager が組む（⚠ 適用の口が3つあるため）。
func _on_call_pressed(index: int) -> void:
	var report: Dictionary = GameManager.apply_party_preset(index)
	_message = GameManager.format_apply_report(report)
	# ⚠ カードの「ビルド」の番号も、呼んだ控えの参照先に合わせる。
	if bool(report.get(GameManager.APPLY_OK, false)):
		for entry: Variant in _preset_slots(GameManager.get_party_presets()[index]):
			if entry is Dictionary:
				_selected_builds[str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))] = \
					int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
	_reordering = false
	_pick = -1
	_rebuild()


# 残す＝いまの出撃届の並び ＋ 各カードのビルド番号を控えに焼く（⚠ 参照だけ・`GR-4`）。
func _on_keep_pressed(index: int) -> void:
	var members: Array = GameManager.get_party_members()
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		return
	var slots: Array = []
	for member: Variant in members:
		slots.append({
			GameStateKeys.PRESET_CHARACTER_ID: str(member),
			GameStateKeys.PRESET_INDEX: _build_of(str(member)),
		})
	if GameManager.save_party_preset(index, slots):
		_message = tr("ui_barracks_kept") % (index + 1)
	_rebuild()


func _on_clear_pressed(index: int) -> void:
	GameManager.clear_party_preset(index)
	_message = ""
	_rebuild()


# ⚠ 育成で値が変わったら（⚠ 画面の外からは来ないが、⚠ 呼ぶで装備が動く）カードを描き直す。
func _on_character_growth_changed(_character_id: String) -> void:
	_rebuild_cards()


func _on_back_pressed() -> void:
	# 履歴に依存せず明示的に帰る（base_screen.gd と同じ流儀）。
	SceneManager.change_scene(_return_path)
