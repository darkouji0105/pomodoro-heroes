# res://scenes/guild/skill_select_screen.gd
# スキル選択画面（レベルの役割転換・第2弾。EXEC_SKILL_SELECT.md §8）。
#
# 候補の中から2枠を選んで戦闘に持ち込む（GAME_DESIGN.md 3-2）。
# stat_node_screen と同じく独立画面にし、TransferKeys.CHARACTER_ID で対象を受け取る。
#
# 枠の数は GameManager.get_skill_slot_count() が決める（2 と書かない）。
# 枠は装備スロットに対応しない。スキルはそのまま持ち込むだけで、
# 武器・アクセサリーとの紐づきはルーン側だけの話（2026-08-15に確認）。
# 候補の並び順は characters.json の "skills" が決める。
# どちらもここで決め打ちしないこと（軸を2箇所に書いて片方だけ直す事故の元になる）。
#
# 購読するシグナルは character_growth_changed の1本だけ。
# スキルの選択は素材も所持金も触らないため、material_changed は飛ばない。

class_name SkillSelectScreen
extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

# 操作対象の枠を示す印。押した枠が次に選ぶスキルの行き先になる。
const MARK_ACTIVE: String = "▶"
const MARK_INACTIVE: String = "　"
# 候補の状態。選択済み / 選べる / レベル不足
const MARK_SELECTED: String = "●"
const MARK_AVAILABLE: String = "○"
const MARK_LOCKED: String = "✕"

# --- ノード参照 ---
@onready var name_label: Label = $Margin/Layout/NameLabel
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var slots: VBoxContainer = $Margin/Layout/Slots
@onready var candidates: VBoxContainer = $Margin/Layout/Scroll/Candidates
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

var _character_id: String = ""
# 次に選んだスキルを入れる枠。既定は0（スキル1＝武器スロット）。
# 状態ではなく画面の都合なのでセーブしない。
var _active_slot: int = 0


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	back_button.pressed.connect(_on_back_pressed)
	GameManager.character_growth_changed.connect(_on_character_growth_changed)

	notice_label.text = ""
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[SkillSelectScreen] character_id が渡されていない")
	_rebuild()


# --- 描画 ---

func _rebuild() -> void:
	_clear(slots)
	_clear(candidates)
	if _character_id == "":
		name_label.text = ""
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	name_label.text = tr(str(char_data.get("name_key", "")))

	_build_slots()
	_build_candidates()


# 枠を1行ずつ並べる。行 = [枠を選ぶボタン][外すボタン]。
#
# 枠を押すと「次に選んだスキルの行き先」になる。押しただけでは状態を触らない。
# 解除は「外す」側で、別のボタンに分けてある（枠を押す＝解除だと、
# 行き先を変えるだけのつもりで選択が消える）。
func _build_slots() -> void:
	var selected: Array = GameManager.get_selected_skills(_character_id)

	for i: int in range(GameManager.get_skill_slot_count()):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots.add_child(row)

		var skill_id: String = "" if i >= selected.size() else str(selected[i])

		var slot_button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		row.add_child(slot_button)
		# 枠のほうを広げる。「外す」は文字数ぶんでよい。
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# label_key ではなく text を直接入れる（印・枠の番号・スキル名を1行にまとめるため）。
		slot_button.text = "%s %s : %s" % [
			MARK_ACTIVE if i == _active_slot else MARK_INACTIVE,
			tr("ui_skill_select_slot") % (i + 1),
			_skill_name_text(skill_id),
		]
		slot_button.pressed.connect(_on_slot_pressed.bind(i))

		var clear_button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		row.add_child(clear_button)
		# 「外す」は装備画面の既存キーを使い回す（AGENTS.md「同じ意味のテキストは既存キーを使い回す」）。
		clear_button.label_key = "ui_equipment_unequip"
		# 空の枠を外しても何も起きないので、押せなくしておく
		# （stat_node_screen の reset_button と同じ判断）。
		clear_button.disabled = skill_id == ""
		clear_button.pressed.connect(_on_clear_pressed.bind(i))


# 候補を縦に並べる。レベル不足のものも灰色で見せる（次に何が解放されるか分かる）。
func _build_candidates() -> void:
	var all_candidates: Array = GameManager.get_all_skill_candidates(_character_id)
	var unlocked: Array = GameManager.get_skill_candidates(_character_id)
	var selected: Array = GameManager.get_selected_skills(_character_id)

	for entry: Variant in all_candidates:
		var skill_id: String = str(entry)
		var is_unlocked: bool = skill_id in unlocked
		var is_selected: bool = skill_id in selected

		var mark: String = MARK_LOCKED
		if is_selected:
			mark = MARK_SELECTED
		elif is_unlocked:
			mark = MARK_AVAILABLE

		var button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		candidates.add_child(button)
		# 行いっぱいに広げる。文字数でボタン幅が変わると右端が揃わない。
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s %s%s" % [mark, _skill_name_text(skill_id), _lock_text(skill_id, is_unlocked)]
		# 押せてから失敗するより、押せないほうが分かりやすい。
		# 判定は GameManager 側と同じものを使う（画面で条件を作り直さない）。
		button.disabled = not GameManager.can_select_skill(_character_id, _active_slot, skill_id)
		button.pressed.connect(_on_candidate_pressed.bind(skill_id))


# 未選択の枠は「未選択」と出す。空文字のままだと行が欠けて見える。
func _skill_name_text(skill_id: String) -> String:
	if skill_id == "":
		return tr("ui_skill_select_empty")
	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
	if skill_data.is_empty():
		# skills.json から消えたID。セーブには残るがフォールバックで別のものが出る。
		return skill_id
	return tr(str(skill_data.get("name_key", "")))


# レベル不足の候補にだけ「Lv5 で解放」を添える。
func _lock_text(skill_id: String, is_unlocked: bool) -> String:
	if is_unlocked:
		return ""
	return " " + tr("ui_skill_select_locked") % GameManager.get_skill_unlock_level(skill_id)


# remove_child してから queue_free する。await を挟むと再描画が並走し、行が二重に並ぶ
# （AGENTS.md「再描画は await を持たせない」）。
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


# --- 操作 ---

# 枠を押す。状態は触らず、次にスキルを選んだときの行き先を変えるだけ。
# character_growth_changed は飛ばないので、自分で描き直す。
func _on_slot_pressed(slot_index: int) -> void:
	if slot_index == _active_slot:
		return
	_active_slot = slot_index
	notice_label.text = ""
	_rebuild()


func _on_candidate_pressed(skill_id: String) -> void:
	if _character_id == "":
		return
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	# 既に別の枠に入っているスキルを選ぶと、2つの枠が入れ替わる（GameManager 側の仕様）。
	GameManager.select_skill(_character_id, _active_slot, skill_id)


func _on_clear_pressed(slot_index: int) -> void:
	if _character_id == "":
		return
	GameManager.clear_skill_slot(_character_id, slot_index)


func _on_back_pressed() -> void:
	SceneManager.change_scene(TRAINING_PATH)


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
