class_name GoalRunner
extends Node

# おまかせで集める（2026-10-09・回AUTO-3・`EXEC_GOAL.md` §7・人間「⚠ １あ　２戦闘関連はまだ作らない　３あ　４あ　５あ」）。
#
# ⚠ 目標の紙の「おまかせで集める」から始まる。⚠ 足りない品ごとに、⚠ 画面を順に開いて見せながら（「⚠ １あ」）：
#   ① 届いた宝箱を開ける（⚠ その品が出うる宝箱だけ）
#   ② ショップで買う（⚠ 金貨で買える棚だけ・⚠ ジェムは使わない）
#   ③ 踏破済みの依頼を周回する（⚠ 今ある口 `run_floor_auto()`＝戦闘画面は開かない・「⚠ ５あ」）
#   ⚠ 1巡して何も増えなければ止まる。⚠ まだの依頼・難ダンジョンには行かない（「⚠ ２戦闘関連はまだ作らない」）
#   ⚠ 止まったら画面の上に何をしたかと理由。⚠ まだ足りなければその品の入手先の窓を出す（⚠ 行き先は人が選ぶ）。
# ⚠ 届いたら目標は GameManager が消し、知らせは `Toast` が出す（「⚠ ４あ」＝元の操作はしない）。
# ⚠ 遊ぶ人が途中で別の画面へ移ったら止める（⚠ おまかせが画面を取り合わない）。
# ⚠ 状態を変えるのは GameManager の口だけ（⚠ どれも全部の判定を先に終える形＝CLAUDE.md 6番）。
# ⚠ root に1つだけ置く（⚠ 画面が入れ替わっても続く）。

const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
const BOARD_PATH: String = "res://scenes/adventure/adventure_select.tscn"
# ⚠ 1回のおまかせで行う操作の上限（⚠ 届かない目標で回り続けないための安全弁）。
const MAX_ACTIONS: int = 200

static var _running: GoalRunner = null

var _opened_path: String = ""
var _chests: int = 0
var _bought: int = 0
var _runs: int = 0
var _actions: int = 0
var _reason_key: String = ""


static func is_running() -> bool:
	return _running != null and is_instance_valid(_running)


static func start(caller: Node) -> GoalRunner:
	if is_running() or not GameManager.has_goal():
		return null
	var runner: GoalRunner = GoalRunner.new()
	runner.name = "GoalRunner"
	caller.get_tree().root.add_child.call_deferred(runner)
	_running = runner
	return runner


func _ready() -> void:
	await _run()
	_finish()
	_running = null
	queue_free()


func _run() -> void:
	for line: Dictionary in GameManager.get_goal_progress():
		var item_id: String = str(line.get(GameManager.GOAL_LINE_ITEM_ID, ""))
		var target: int = int(line.get(GameManager.GOAL_LINE_TARGET, 0))
		while GameManager.has_goal() and GameManager.get_resource_amount(item_id) < target:
			var before: int = GameManager.get_resource_amount(item_id)
			if not await _round(item_id, target):
				return
			if GameManager.get_resource_amount(item_id) <= before:
				if _reason_key == "":
					_reason_key = "ui_goal_auto_stop_nothing"
				return
		if not GameManager.has_goal():
			return


# 1巡（宝箱 → ショップ → 周回）。⚠ false＝もう続けない（⚠ 人が画面を移った・上限）。
func _round(item_id: String, target: int) -> bool:
	# ① 届いた宝箱。
	var chest_ids: Array[String] = _pending_chests_for(item_id)
	if not chest_ids.is_empty():
		if not await _show(CHEST_PATH):
			return false
		for instance_id: String in chest_ids:
			if not _still_short(item_id, target):
				return true
			if GameManager.open_chest(instance_id):
				_chests += 1
				if not await _step():
					return false
	# ② ショップ（⚠ 金貨の棚だけ）。
	if _still_short(item_id, target) and not _shop_slots_for(item_id).is_empty():
		if not await _show(SHOP_PATH):
			return false
		var short_of_gold: bool = false
		for slot: Dictionary in _shop_slots_for(item_id):
			while _still_short(item_id, target):
				if not GameManager.purchase_shop_item(str(slot["shop_type"]), int(slot["slot_id"])):
					short_of_gold = short_of_gold or GameManager.get_resource_amount(GameStateKeys.GOLD) < int(slot["amount"])
					break
				_bought += 1
				if not await _step():
					return false
		if short_of_gold and _still_short(item_id, target):
			_reason_key = "ui_goal_auto_stop_gold"
	# ③ 踏破済みの依頼の周回。
	var floors: Array[String] = _cleared_floors_for(item_id)
	if _still_short(item_id, target) and not floors.is_empty():
		if not await _show(BOARD_PATH):
			return false
		for floor_id: String in floors:
			while _still_short(item_id, target):
				var reason: String = GameManager.get_floor_auto_reject_reason(floor_id)
				if reason != "":
					if reason == "stamina":
						_reason_key = "ui_goal_auto_stop_stamina"
					break
				var _result: Dictionary = GameManager.run_floor_auto(floor_id)
				_runs += 1
				if not await _step():
					return false
	return true


func _still_short(item_id: String, target: int) -> bool:
	return GameManager.has_goal() and GameManager.get_resource_amount(item_id) < target and _actions < MAX_ACTIONS


# 画面を開いて少し見せる。⚠ false＝人が別の画面へ移っていた。
func _show(path: String) -> bool:
	if not _player_stayed():
		return false
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != path:
		SceneManager.change_scene(path)
		await get_tree().process_frame
		await get_tree().process_frame
	_opened_path = path
	return await _wait()


# 1つ操作したあと：⚠ 画面を描き直して少し見せる。
func _step() -> bool:
	_actions += 1
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("_rebuild"):
		scene.call("_rebuild")
	return await _wait()


func _wait() -> bool:
	var ms: float = float(ThemeDB.get_project_theme().get_constant(&"step_ms", &"GoalRunner"))
	await get_tree().create_timer(ms / 1000.0 / maxf(GameSettings.effect_speed(), 1.0)).timeout
	return _player_stayed()


# ⚠ おまかせが開いた画面のままか（⚠ まだ何も開いていなければ true）。
func _player_stayed() -> bool:
	if _opened_path == "":
		return true
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != _opened_path:
		_reason_key = "ui_goal_auto_stop_moved"
		return false
	return true


func _finish() -> void:
	var toast: Toast = Toast.get_instance()
	if toast != null:
		toast.show_message(tr("ui_goal_auto_done") % [_chests, _bought, _runs])
		if _reason_key != "" and GameManager.has_goal():
			toast.show_message(tr(_reason_key))
	# ⚠ まだ足りない品があれば、その入手先の窓（⚠ 人が画面を移ったときは出さない）。
	if not GameManager.has_goal() or _reason_key == "ui_goal_auto_stop_moved":
		return
	for line: Dictionary in GameManager.get_goal_progress():
		if int(line.get(GameManager.GOAL_LINE_OWNED, 0)) < int(line.get(GameManager.GOAL_LINE_TARGET, 0)):
			var scene: Node = get_tree().current_scene
			if scene != null:
				var _window: ModalDialog = ItemSourceWindow.open(scene, str(line.get(GameManager.GOAL_LINE_ITEM_ID, "")), int(line.get(GameManager.GOAL_LINE_TARGET, 0)))
			return


# --- 品ごとの行き先（⚠ 入手先の口 `get_item_sources()` から引く＝⚠ 表を別に持たない） ---

func _pending_chests_for(item_id: String) -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		var chest: Dictionary = raw as Dictionary
		if not bool(chest.get(GameStateKeys.CHEST_OPENED, false)) and GameManager.chest_can_give(str(chest.get(GameStateKeys.CHEST_ID, "")), item_id):
			ids.append(str(chest.get(GameStateKeys.CHEST_INSTANCE_ID, "")))
	return ids


# ⚠ 今の棚（⚠ 状態の line_up）で、その品を金貨で売っている枠。
func _shop_slots_for(item_id: String) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for source: Dictionary in GameManager.get_item_sources(item_id):
		if str(source.get(GameManager.ITEM_SOURCE_KIND, "")) != GameManager.ITEM_SOURCE_SHOP:
			continue
		var shop_type: String = str(source.get(GameManager.ITEM_SOURCE_REF, ""))
		# ⚠ 棚は日付で入れ替わる（⚠ ショップの画面も開くときにこれを呼ぶ）。
		GameManager.refresh_shop_if_needed(shop_type)
		for raw: Variant in GameManager.get_shop_lineup(shop_type):
			var slot: Dictionary = raw as Dictionary
			var cost: Dictionary = slot.get(GameStateKeys.SHOP_COST, {})
			if str(slot.get(GameStateKeys.SHOP_ITEM_ID, "")) == item_id and str(cost.get(GameStateKeys.COST_CURRENCY_TYPE, "")) == GameStateKeys.GOLD:
				slots.append({"shop_type": shop_type, "slot_id": int(slot.get(GameStateKeys.SHOP_SLOT_ID, 0)), "amount": int(cost.get(GameStateKeys.COST_AMOUNT, 0))})
	return slots


func _cleared_floors_for(item_id: String) -> Array[String]:
	var floors: Array[String] = []
	for source: Dictionary in GameManager.get_item_sources(item_id):
		var stage_id: String = str(source.get(GameManager.ITEM_SOURCE_REF, ""))
		if str(source.get(GameManager.ITEM_SOURCE_KIND, "")) == GameManager.ITEM_SOURCE_STAGE and GameManager.is_stage_cleared(stage_id):
			floors.append(stage_id)
	return floors
