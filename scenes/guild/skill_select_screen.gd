# res://scenes/guild/skill_select_screen.gd
# スキル選択画面（レベルの役割転換・第2弾。EXEC_SKILL_SELECT.md §8）。
#
# 候補の中から2枠を選んで戦闘に持ち込む（GAME_DESIGN.md 3-2）。
# stat_node_screen と同じく独立画面にし、TransferKeys.CHARACTER_ID で対象を受け取る。
#
# ⚠⚠ 2026-09-11（人間のモック「ギルド／育成」D）：⚠ **記号をやめて枠と色にした**。
#   ⚠ 前は `▶ ● ○ ✕` の4記号を文字列に混ぜていた。⚠ いまは
#   ⚠ **行き先の枠＝琥珀の枠 ／ 入っている候補＝琥珀の枠＋札 ／ 未解放＝沈める**。
#   ⚠ 候補には**効果文とCD・チャージ**を出す（⚠ 前は名前だけだった）。
#   ⚠ パッシブは右の列に隔離した（⚠ 枠ではないものが枠の近くに並んでいた）。
#
# 枠の数は GameManager.get_skill_slot_count() が決める（2 と書かない）。
# 候補の並び順は characters.json の "skills" が決める。
# 購読するシグナルは character_growth_changed の1本だけ。

class_name SkillSelectScreen
extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"

# ⚠ 効果文の翻訳キーの接頭辞。⚠ アイテム・レリックと同じ形（`ui_desc_<id>`）。
#   ⚠ **無ければ行ごと出さない**（⚠ キー名が画面に出るのを避ける）。
const DESCRIPTION_PREFIX: String = "ui_desc_"
# ⚠ 右のパッシブの列の幅（⚠ モックの 300）。
const SIDE_COLUMN_WIDTH: int = 300

# --- ノード参照 ---
@onready var slots_header: HBoxContainer = $Margin/Layout/Columns/Main/SlotsHeader
@onready var slots: HBoxContainer = $Margin/Layout/Columns/Main/Slots
@onready var candidates_header: HBoxContainer = $Margin/Layout/Columns/Main/CandidatesHeader
@onready var candidates: VBoxContainer = $Margin/Layout/Columns/Main/Scroll/Candidates
@onready var side_column: PanelContainer = $Margin/Layout/Columns/SideColumn
@onready var passives: VBoxContainer = $Margin/Layout/Columns/SideColumn/SideMargin/Passives
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var header: ScreenHeader = $Margin/Layout/Header

var _character_id: String = ""
# 次に選んだスキルを入れる枠。既定は0（スキル1＝武器スロット）。
# 状態ではなく画面の都合なのでセーブしない。
var _active_slot: int = 0


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	side_column.custom_minimum_size = Vector2(SIDE_COLUMN_WIDTH, 0.0)
	header.back_pressed.connect(_on_back_pressed)
	GameManager.character_growth_changed.connect(_on_character_growth_changed)

	notice_label.text = ""
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[SkillSelectScreen] character_id が渡されていない")
	_rebuild()


# --- 描画 ---

# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	_clear(slots_header)
	_clear(slots)
	_clear(candidates_header)
	_clear(candidates)
	_clear(passives)
	if _character_id == "":
		return

	# ⚠ 戻る先はこのキャラの詳細。⚠ 文言もキャラの名前にする（⚠ モック）。
	header.set_back_text(tr(str(MasterDataLoader.get_character(_character_id).get("name_key", ""))))
	# ⚠ 「2つを選ぶ」の 2 は枠の数から入れる（⚠ 文にも数を直書きしない）。
	header.set_subtitle_text(tr("ui_skill_select_lead") % GameManager.get_skill_slot_count())

	_build_slots()
	_build_candidates()
	_build_passives()


# 枠の行。⚠ 押すと「次に選んだスキルの行き先」になる（⚠ 押しただけでは状態を触らない）。
#   ⚠ 解除は「外す」側で、別のボタンに分けてある（⚠ 枠を押す＝解除だと、
#   ⚠ 行き先を変えるだけのつもりで選択が消える）。
func _build_slots() -> void:
	var selected: Array = GameManager.get_selected_skills(_character_id, GameManager.SLOT_KIND_SKILL)
	var count: int = GameManager.get_skill_slot_count()

	slots_header.add_child(_create_section_label("ui_skill_select_slots_header"))
	slots_header.add_child(_create_rule())
	var here: Label = Label.new()
	here.name = "HereLabel"
	here.theme_type_variation = &"AccentLabel"
	here.text = tr("ui_skill_select_goes_to") % (_active_slot + 1)
	slots_header.add_child(here)

	for i: int in range(count):
		slots.add_child(_create_slot_card(i, "" if i >= selected.size() else str(selected[i])))


func _create_slot_card(slot_index: int, skill_id: String) -> PanelContainer:
	var is_active: bool = slot_index == _active_slot

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Slot_%d" % slot_index
	panel.theme_type_variation = &"ActiveRowPanel" if is_active else &"ListRowPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)

	var well: PanelContainer = _create_icon_well(skill_id)
	if well != null:
		row.add_child(well)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)

	var number: Label = Label.new()
	number.name = "NumberLabel"
	number.theme_type_variation = &"AccentLabel" if is_active else &"SectionLabel"
	# ⚠ 行き先の枠だけ「ここに入ります」を足す（⚠ `▶` の1文字をやめた代わり）。
	number.text = tr("ui_skill_select_slot") % (slot_index + 1)
	if is_active:
		number.text += " ／ " + tr("ui_skill_select_here")
	column.add_child(number)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _skill_name_text(skill_id)
	column.add_child(name_label)

	var description: String = _description_of(skill_id) if skill_id != "" else tr("ui_skill_select_pick_below")
	if description != "":
		var caption: Label = Label.new()
		caption.name = "EffectLabel"
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = description
		column.add_child(caption)

	# 空の枠を外しても何も起きないので、ボタンごと出さない。
	if skill_id != "":
		var clear_button: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_equipment_unequip")
		clear_button.name = "ClearButton"
		clear_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clear_button.pressed.connect(_on_clear_pressed.bind(slot_index))
		row.add_child(clear_button)

	# ⚠ 枠そのものを押すと行き先が変わる。⚠ 「外す」は面の中の本物のボタンなので、
	#   ⚠ 当たりは一番下に敷く（`UiButton.attach_hit()` が中身を通す形にする）。
	UiButton.attach_hit(panel, _on_slot_pressed.bind(slot_index))
	return panel


# 候補を縦に並べる。⚠ レベル不足のものも沈めて見せる（⚠ 次に何が解放されるか分かる）。
func _build_candidates() -> void:
	var all_candidates: Array = GameManager.get_all_skill_candidates(
		_character_id, GameManager.SLOT_KIND_SKILL
	)
	var unlocked: Array = GameManager.get_skill_candidates(
		_character_id, GameManager.SLOT_KIND_SKILL
	)

	candidates_header.add_child(_create_section_label("ui_skill_select_candidates_header"))
	candidates_header.add_child(_create_rule())
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.theme_type_variation = &"SectionLabel"
	count_label.text = tr("ui_skill_select_unlocked_count") % [all_candidates.size(), unlocked.size()]
	candidates_header.add_child(count_label)

	var selected: Array = GameManager.get_selected_skills(_character_id, GameManager.SLOT_KIND_SKILL)
	for entry: Variant in all_candidates:
		var skill_id: String = str(entry)
		candidates.add_child(_create_candidate_row(
			skill_id, skill_id in unlocked, selected.find(skill_id)
		))


func _create_candidate_row(skill_id: String, is_unlocked: bool, slot_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Candidate_" + skill_id
	panel.theme_type_variation = &"ActiveRowPanel" if slot_index >= 0 else &"ListRowPanel"
	# ⚠ 未解放は沈める（⚠ `✕` の代わり）。⚠ 消さない＝次に何が来るかは見せる。
	panel.modulate.a = 1.0 if is_unlocked else 0.4

	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)

	var well: PanelContainer = _create_icon_well(skill_id)
	if well != null:
		row.add_child(well)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)

	# 名前の行（名前 ＋ 札）。
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.theme_type_variation = &"ButtonRow"
	column.add_child(title_row)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _skill_name_text(skill_id)
	title_row.add_child(name_label)

	# ⚠ 札は「どの枠に入っているか」か「何レベルで解放されるか」のどちらか。
	var tag_text: String = ""
	if slot_index >= 0:
		tag_text = tr("ui_skill_select_in_slot") % (slot_index + 1)
	elif not is_unlocked:
		tag_text = tr("ui_skill_select_locked") % GameManager.get_skill_unlock_level(skill_id)
	if tag_text != "":
		var tag: Label = Label.new()
		tag.name = "TagLabel"
		tag.theme_type_variation = &"AccentLabel" if slot_index >= 0 else &"SectionLabel"
		tag.text = tag_text
		title_row.add_child(tag)

	var description: String = _description_of(skill_id)
	if description != "":
		var caption: Label = Label.new()
		caption.name = "EffectLabel"
		caption.theme_type_variation = &"CaptionLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.text = description
		column.add_child(caption)

	row.add_child(_create_timing_column(skill_id))

	# 押せてから失敗するより、押せないほうが分かりやすい。
	# 判定は GameManager 側と同じものを使う（画面で条件を作り直さない）。
	if GameManager.can_select_skill(_character_id, _active_slot, skill_id, GameManager.SLOT_KIND_SKILL):
		UiButton.attach_hit(panel, _on_candidate_pressed.bind(skill_id))
	return panel


# 右端の「CD 6.0秒 ／ チャージ 1.0秒」。
#
# ⚠ どちらも `skills.json` の実測値（⚠ 画面で計算しない）。
# ⚠⚠ **チャージは `activation` が `charge` のスキルだけが持つ**。⚠ `instant` には無い
#   （⚠ モックは全候補にチャージを書いていたが、⚠ 無い値は出さない）。
func _create_timing_column(skill_id: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "TimingColumn"
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	var cooldown: Label = Label.new()
	cooldown.name = "CooldownLabel"
	cooldown.theme_type_variation = &"CaptionLabel"
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cooldown.text = tr("ui_skill_select_cooldown") % float(data.get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))
	column.add_child(cooldown)

	if str(data.get(SkillSchema.FIELD_ACTIVATION, "")) != SkillSchema.ACTIVATION_CHARGE:
		return column
	var charge: Variant = data.get(SkillSchema.FIELD_CHARGE, null)
	if not (charge is Dictionary):
		return column
	var just: Label = Label.new()
	just.name = "ChargeLabel"
	just.theme_type_variation = &"SectionLabel"
	just.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	just.text = tr("ui_skill_select_charge") % float((charge as Dictionary).get(SkillSchema.FIELD_JUST_SEC, 0.0))
	column.add_child(just)
	return column


# 右の列。⚠ パッシブは枠ではない（⚠ レベルで解放されたものが全部効く）。
#   ⚠ ボタンにしない。⚠ 押して何も起きない器を画面に残さない。
func _build_passives() -> void:
	var all_passives: Array = GameManager.get_all_skill_candidates(
		_character_id, GameManager.SLOT_KIND_PASSIVE
	)
	if all_passives.is_empty():
		# パッシブを持たないキャラが居てよい（正常系）。見出しごと出さない。
		return

	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(_create_section_label("ui_skill_select_passive_header"))
	head.add_child(_create_rule())
	passives.add_child(head)

	var note: Label = Label.new()
	note.name = "PassiveNote"
	note.theme_type_variation = &"SectionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("ui_skill_select_passive_note")
	passives.add_child(note)

	var unlocked: Array = GameManager.get_skill_candidates(
		_character_id, GameManager.SLOT_KIND_PASSIVE
	)
	for entry: Variant in all_passives:
		var passive_id: String = str(entry)
		passives.add_child(_create_passive_row(passive_id, passive_id in unlocked))


# ⚠⚠ 2026-09-14：⚠ 左に絵の枠を足した（人間の指示「⚠ svg に関してはあなたが作って」）。
#   ⚠ 前は**絵の枠そのものが無かった**（⚠ 台帳の「絵が無ければ枠ごと出ない」は誤り）。
#   ⚠ 枠はスキルの候補と同じ `_create_icon_well()`。⚠ 絵が無いパッシブは枠ごと出ない。
func _create_passive_row(passive_id: String, is_unlocked: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Passive_" + passive_id
	# ⚠ 解放済みは通常の濃さ、⚠ 未解放は沈める（⚠ 候補と同じ落とし方）。
	row.modulate.a = 1.0 if is_unlocked else 0.45
	var well: PanelContainer = _create_icon_well(passive_id)
	if well != null:
		row.add_child(well)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"GainLabel" if is_unlocked else &""
	name_label.text = _skill_name_text(passive_id)
	column.add_child(name_label)

	var parts: Array[String] = []
	var description: String = _description_of(passive_id)
	if description != "":
		parts.append(description)
	if not is_unlocked:
		parts.append(tr("ui_skill_select_passive_locked") % GameManager.get_skill_unlock_level(passive_id))
	if parts.is_empty():
		return row
	var caption: Label = Label.new()
	caption.name = "EffectLabel"
	caption.theme_type_variation = &"CaptionLabel"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = "　".join(parts)
	column.add_child(caption)
	return row


# --- 小さい器 ---

# スキルの絵の枠。⚠ 絵が無いスキルは枠ごと出さない（⚠ 空の四角を並べない）。
#
# ⚠ 大きさは Theme が持つ（`IconWell`）。⚠ ここに px を書かない。
# ⚠ 線画は 48px で読み込まれるので、⚠ 器は必ず `EXPAND_IGNORE_SIZE`（§0-UI-B-1）。
func _create_icon_well(skill_id: String) -> PanelContainer:
	if skill_id == "":
		return null
	var texture: Texture2D = IconTextures.for_skill(skill_id)
	if texture == null:
		return null

	var well: PanelContainer = PanelContainer.new()
	well.name = "IconWell"
	well.theme_type_variation = &"IconWell"
	var box: int = well.get_theme_constant(&"size", &"IconWell")
	well.custom_minimum_size = Vector2(box, box)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inner: int = well.get_theme_constant(&"icon", &"IconWell")
	rect.custom_minimum_size = Vector2(inner, inner)
	well.add_child(rect)
	return well


func _create_section_label(key: String) -> Label:
	var label: Label = Label.new()
	label.name = "SectionLabel"
	label.theme_type_variation = &"SectionLabel"
	label.text = tr(key)
	return label


func _create_rule() -> HSeparator:
	var rule: HSeparator = HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rule


# 未選択の枠は「未選択」と出す。空文字のままだと行が欠けて見える。
func _skill_name_text(skill_id: String) -> String:
	if skill_id == "":
		return tr("ui_skill_select_empty")
	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
	if skill_data.is_empty():
		# skills.json から消えたID。セーブには残るがフォールバックで別のものが出る。
		return skill_id
	return tr(str(skill_data.get("name_key", "")))


# ⚠ 効果文は `ui_desc_<skill_id>`。⚠ 無ければ空（⚠ 行ごと出さない）。
#   ⚠ `tr()` は表に無いキーをそのまま返すので、⚠ 返り値がキーと同じなら「無い」。
#   ⚠ アイテム・レリックの説明文と同じ落とし方（`ItemDetail._add_description()`）。
func _description_of(skill_id: String) -> String:
	if skill_id == "":
		return ""
	var key: String = DESCRIPTION_PREFIX + skill_id
	var text: String = tr(key)
	return "" if text == key else text


# --- 操作 ---

# 枠を押す。状態は触らず、次にスキルを選んだときの行き先を変えるだけ。
# character_growth_changed は飛ばないので、自分で描き直す。
func _on_slot_pressed(slot_index: int) -> void:
	if slot_index == _active_slot:
		return
	_active_slot = slot_index
	notice_label.text = ""
	# ⚠ 行き先が変わると候補の押せる／押せないも変わるので、⚠ 全体を描き直す。
	_rebuild()


func _on_candidate_pressed(skill_id: String) -> void:
	if _character_id == "":
		return
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	# 既に別の枠に入っているスキルを選ぶと、2つの枠が入れ替わる（GameManager 側の仕様）。
	GameManager.select_skill(_character_id, _active_slot, skill_id, GameManager.SLOT_KIND_SKILL)


func _on_clear_pressed(slot_index: int) -> void:
	if _character_id == "":
		return
	GameManager.clear_skill_slot(_character_id, slot_index, GameManager.SLOT_KIND_SKILL)


# ⚠ 誰のスキルを見ていたかを渡して戻る（2026-09-11）。⚠ 渡さないと一覧に落ちる。
func _on_back_pressed() -> void:
	SceneManager.change_scene_with_data(TRAINING_PATH, {TransferKeys.CHARACTER_ID: _character_id})


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
