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
@onready var candidates_label: Label = $Margin/Layout/CandidatesLabel
@onready var candidates: VBoxContainer = $Margin/Layout/Scroll/Candidates
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

var _character_id: String = ""
# 次に選んだスキルを入れる枠。既定は0（スキル1＝武器スロット）。
# 状態ではなく画面の都合なのでセーブしない。
var _active_slot: int = 0
# 行き先がスキル枠かパッシブ枠か（EXEC_SKILL_PASSIVE_VARS.md §3-7）。
#
# ⚠ パッシブはスキル枠を消費しない別枠（人間の決定・2026-08-17）。
# ⚠ 枠の番号だけでは足りない。種類と番号の対で「行き先」になる。
# ⚠ 種類ごとに画面をもう1枚作らないこと。枠の仕組みが GameManager 側で
#   1本に一般化してあるので、こちらも1本のまま回す。
var _active_kind: String = GameManager.SLOT_KIND_SKILL


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
	_build_slot_rows(GameManager.SLOT_KIND_SKILL, "ui_skill_select_slot")
	# ⚠ パッシブは枠ではない。レベルで解放されたものが全部効く
	#   （人間の決定・2026-08-25。GAME_DESIGN.md 5-2 / 5-4）。
	# ⚠ _build_slot_rows() に渡さないこと。あちらは「押して行き先にする」器で、
	#   選ぶものが無いのにボタンが出る（押しても何も起きない行が残る）。
	_build_passive_list()


# 解放されたパッシブを、選べない一覧として並べる。
#
# ⚠ ボタンにしない。押して何も起きない器を画面に残さない。
# ⚠ 未解放のものも出す。次に何が増えるかが見えないと、レベルを上げる動機が
#   画面から読めない（候補一覧の _lock_text と同じ判断）。
# ⚠ 並び順は characters.json の "passives" が決める。ここで並べ替えない。
func _build_passive_list() -> void:
	var all_passives: Array = GameManager.get_all_skill_candidates(
		_character_id, GameManager.SLOT_KIND_PASSIVE
	)
	if all_passives.is_empty():
		# パッシブを持たないキャラが居てよい（正常系）。見出しごと出さない。
		return

	var unlocked: Array = GameManager.get_skill_candidates(
		_character_id, GameManager.SLOT_KIND_PASSIVE
	)

	var header: Label = Label.new()
	header.text = tr("ui_skill_select_passive_header")
	slots.add_child(header)

	for entry: Variant in all_passives:
		var passive_id: String = str(entry)
		var is_unlocked: bool = passive_id in unlocked
		var row: Label = Label.new()
		slots.add_child(row)
		# ⚠ 印はスキル候補と同じものを使い回す（画面ごとに記号を作り直さない）。
		#   解放済み＝●（効いている）／未解放＝✕。○（選べる）は使わない。
		row.text = "%s %s%s" % [
			MARK_SELECTED if is_unlocked else MARK_LOCKED,
			_skill_name_text(passive_id),
			"" if is_unlocked else " " + tr("ui_skill_select_passive_locked") % (
				GameManager.get_skill_unlock_level(passive_id)
			),
		]


func _build_slot_rows(kind: String, label_key: String) -> void:
	var selected: Array = GameManager.get_selected_skills(_character_id, kind)
	var count: int = (
		GameManager.get_passive_slot_count() if kind == GameManager.SLOT_KIND_PASSIVE
		else GameManager.get_skill_slot_count()
	)

	for i: int in range(count):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots.add_child(row)

		var skill_id: String = "" if i >= selected.size() else str(selected[i])
		var is_active: bool = (kind == _active_kind and i == _active_slot)

		var slot_button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		row.add_child(slot_button)
		# 枠のほうを広げる。「外す」は文字数ぶんでよい。
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# label_key ではなく text を直接入れる（印・枠の番号・スキル名を1行にまとめるため）。
		slot_button.text = "%s %s : %s" % [
			MARK_ACTIVE if is_active else MARK_INACTIVE,
			tr(label_key) % (i + 1),
			_skill_name_text(skill_id),
		]
		slot_button.pressed.connect(_on_slot_pressed.bind(kind, i))

		var clear_button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		row.add_child(clear_button)
		# 「外す」は装備画面の既存キーを使い回す（AGENTS.md「同じ意味のテキストは既存キーを使い回す」）。
		clear_button.label_key = "ui_equipment_unequip"
		# 空の枠を外しても何も起きないので、押せなくしておく
		# （stat_node_screen の reset_button と同じ判断）。
		clear_button.disabled = skill_id == ""
		clear_button.pressed.connect(_on_clear_pressed.bind(kind, i))


# 候補を縦に並べる。レベル不足のものも灰色で見せる（次に何が解放されるか分かる）。
#
# ⚠ 出すのは「今の行き先の種類」の候補だけ。スキル枠を押していればスキル、
#   パッシブ枠を押していればパッシブ。混ぜて出すと、押した候補がどちらの枠に
#   入るのか画面から読めなくなる。
func _build_candidates() -> void:
	var kind: String = _active_kind
	# ⚠ ここに来る kind は必ずスキル。パッシブは枠を持たなくなったので、
	#   _active_kind がパッシブになる経路が消えた（2026-08-25）。
	# ⚠ 見出しの出し分けを消した。パッシブの一覧は _build_passive_list() が
	#   上に出しており、候補一覧に混ざることはもう無い。
	candidates_label.text = tr("ui_skill_select_candidates_header")
	var all_candidates: Array = GameManager.get_all_skill_candidates(_character_id, kind)
	var unlocked: Array = GameManager.get_skill_candidates(_character_id, kind)
	var selected: Array = GameManager.get_selected_skills(_character_id, kind)

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
		button.disabled = not GameManager.can_select_skill(
			_character_id, _active_slot, skill_id, kind
		)
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
func _on_slot_pressed(kind: String, slot_index: int) -> void:
	if kind == _active_kind and slot_index == _active_slot:
		return
	_active_kind = kind
	_active_slot = slot_index
	notice_label.text = ""
	# ⚠ 種類が変わると候補一覧も入れ替わるので、枠だけでなく全体を描き直す。
	_rebuild()


func _on_candidate_pressed(skill_id: String) -> void:
	if _character_id == "":
		return
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	# 既に別の枠に入っているスキルを選ぶと、2つの枠が入れ替わる（GameManager 側の仕様）。
	GameManager.select_skill(_character_id, _active_slot, skill_id, _active_kind)


func _on_clear_pressed(kind: String, slot_index: int) -> void:
	if _character_id == "":
		return
	GameManager.clear_skill_slot(_character_id, slot_index, kind)


func _on_back_pressed() -> void:
	SceneManager.change_scene(TRAINING_PATH)


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
