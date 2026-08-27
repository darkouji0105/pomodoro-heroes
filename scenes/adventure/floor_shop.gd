# res://scenes/adventure/floor_shop.gd
# フロア内ショップ（段階14-e・PLAN_SCENARIO_MAP.md §3-4）。
#
# ⚠ 拠点のショップと共通化しない。通貨は同じゴールドだが、在庫もリフレッシュも
#   持たず、買ったものはフロアを降りると消える（たいまつ）か即座に効く（回復）。
# ⚠ 入店した瞬間に無料ガチャを1回引く（メモ「入店時、無料ガチャ演出で何か1つ当たる」）。
#   ⚠ 引くのは _ready() の1回だけ。ショップのノードは踏破済みになって
#     二度と押せないので、再入店は起きない。
# ⚠ この画面は状態を持たない。正は GameManager。押すたびに引き直して描く。

extends Control

const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"

@onready var gold_label: Label = $Layout/Header/GoldLabel
@onready var gacha_label: Label = $Layout/GachaLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var torch_label: Label = $Layout/TorchRow/TorchLabel
@onready var torch_button: PrimaryButton = $Layout/TorchRow/TorchButton
@onready var heal_label: Label = $Layout/HealRow/HealLabel
@onready var heal_button: PrimaryButton = $Layout/HealRow/HealButton
@onready var leave_button: PrimaryButton = $Layout/Footer/LeaveButton


func _ready() -> void:
	SceneManager.consume_transfer_data()

	if not GameManager.is_in_floor():
		push_warning("[FloorShop] フロアに入っていないので冒険選択へ戻る")
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return

	# 入店時の無料ガチャ。⚠ 恒久資産なので持ち帰れる。
	if GameManager.grant_floor_gacha():
		gacha_label.text = tr("ui_floor_shop_gacha_hit")
	else:
		# 中身が空なら grant_chest() が false を返す。⚠ いまのプールにハズレ枠は無い。
		gacha_label.text = tr("ui_floor_shop_gacha_miss")

	message_label.text = ""
	torch_button.pressed.connect(_on_torch_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	_rebuild()


func _rebuild() -> void:
	var state: Dictionary = GameManager.get_state()
	var gold: int = int(state.get(GameStateKeys.GOLD, 0))
	gold_label.text = tr("ui_res_gold") + ": " + str(gold)

	# たいまつ。⚠ 上限なら買えない。
	var grade: int = GameManager.get_floor_torch_grade()
	var price: int = GameManager.get_floor_torch_next_price()
	if price < 0:
		torch_label.text = "%s %d（%s・%d %s）" % [
			tr("ui_floor_torch"), grade, tr("ui_floor_torch_max"),
			GameManager.get_floor_reveal_layers(), tr("ui_floor_torch_layers"),
		]
		torch_button.disabled = true
	else:
		torch_label.text = "%s %d → %d（%d %s → %d %s） %d G" % [
			tr("ui_floor_torch"), grade, grade + 1,
			GameManager.get_floor_reveal_layers(), tr("ui_floor_torch_layers"),
			_reveal_at(grade + 1), tr("ui_floor_torch_layers"),
			price,
		]
		torch_button.disabled = gold < price

	# 回復。⚠ 全員満タンなら買えない。
	var heal_price: int = int(Balance.adventure.floor_shop_heal_price)
	var heal_pct: int = int(Balance.adventure.floor_shop_heal_pct)
	var hurt: int = GameManager.get_floor_hp_carry().size()
	heal_label.text = "%s +%d%%（%s %d人） %d G" % [
		tr("ui_floor_shop_heal"), heal_pct, tr("ui_floor_shop_hurt"), hurt, heal_price
	]
	heal_button.disabled = gold < heal_price or hurt <= 0


# グレード n のときに何層先まで見えるか。⚠ 表示のためだけ。
func _reveal_at(grade: int) -> int:
	var table: Array[int] = Balance.adventure.floor_torch_reveal_layers
	if table.is_empty():
		return 1
	return int(table[clampi(grade, 0, table.size() - 1)])


func _on_torch_pressed() -> void:
	if GameManager.buy_floor_torch():
		message_label.text = tr("ui_floor_shop_bought")
	else:
		message_label.text = tr("ui_floor_shop_cannot_buy")
	_rebuild()


func _on_heal_pressed() -> void:
	if GameManager.buy_floor_heal():
		message_label.text = tr("ui_floor_shop_healed")
	else:
		message_label.text = tr("ui_floor_shop_cannot_buy")
	_rebuild()


func _on_leave_pressed() -> void:
	SceneManager.change_scene(FLOOR_MAP_PATH)
