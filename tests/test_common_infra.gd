extends Control

# 共通基盤の動作検証用シーン。
# _ready() で GameManager / SignalBus / Balance の各関数を自動テストし、
# 結果を print する。その後 Timer で SceneManager の遷移テストへ自動進行する。

func _ready() -> void:
	print("================================================")
	print("COMMON_INFRA: TEST START")
	print("================================================")
	_test_add_gold()
	_test_chests()
	_test_pomodoro_rewards()
	_test_battle_rewards()
	_test_failure_paths()
	_test_material_signal()
	_test_inventory_type()
	_test_state_snapshot()
	_test_balance_init()
	print("================================================")
	print("COMMON_INFRA: TEST END")
	print("Auto-transitioning to DummySceneA in 2s...")
	print("================================================")
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_go_to_dummy_a)
	add_child(timer)
	timer.start()

func _go_to_dummy_a() -> void:
	print("[TestCommonInfra] change_scene_with_data -> DummySceneA")
	SceneManager.change_scene_with_data("res://tests/dummy_scene_a.tscn", {"test_key": "test_value", "source": "test_common_infra"})

# --- TEST #3: add_gold -> resource_changed ---
func _test_add_gold() -> void:
	print("\n--- TEST #3: add_gold -> resource_changed ---")
	var fired: Array = []
	var callable: Callable = func(rt: String, nv: Variant) -> void: fired.append([rt, nv])
	GameManager.resource_changed.connect(callable)
	GameManager.add_gold(100)
	GameManager.resource_changed.disconnect(callable)
	var state: Dictionary = GameManager.get_state()
	# resource_type が GameStateKeys の定数と一致するか（文字列リテラル混入の検出）
	var type_ok: bool = fired.size() > 0 and str(fired[0][0]) == GameStateKeys.GOLD
	var ok: bool = fired.size() > 0 and type_ok and int(state[GameStateKeys.GOLD]) >= 100
	print("[TEST #3] %s | gold=%d | resource_type==GameStateKeys.GOLD: %s | signals=%s" % [
		"PASS" if ok else "FAIL", int(state[GameStateKeys.GOLD]), type_ok, fired])

# --- TEST #4: add_pending_chest -> open_chest -> pending_chests_changed ---
func _test_chests() -> void:
	print("\n--- TEST #4: add_pending_chest -> open_chest -> pending_chests_changed ---")
	var fired: Array = []
	var callable: Callable = func(count: int) -> void: fired.append(count)
	GameManager.pending_chests_changed.connect(callable)
	GameManager.add_pending_chest({"chest_id": "chest_1", "chest_type": "normal", "source": "test", "opened": false, "rewards": {"gold": 50}})
	GameManager.add_pending_chest({"chest_id": "chest_2", "chest_type": "rare", "source": "test", "opened": false, "rewards": {"gold": 100}})
	var count_before: int = GameManager.get_pending_chest_count()
	GameManager.open_chest("chest_1")
	var count_after: int = GameManager.get_pending_chest_count()
	GameManager.pending_chests_changed.disconnect(callable)
	var ok: bool = count_before == 2 and count_after == 1 and fired.size() >= 3
	print("[TEST #4] %s | before=%d after=%d | signals=%s" % ["PASS" if ok else "FAIL", count_before, count_after, fired])

# --- TEST #5: apply_pomodoro_rewards ---
func _test_pomodoro_rewards() -> void:
	print("\n--- TEST #5: apply_pomodoro_rewards ---")
	var before: Dictionary = GameManager.get_state()
	var gold_before: int = int(before[GameStateKeys.GOLD])
	var stamina_before: int = int(before[GameStateKeys.STAMINA]["current"])
	var total_before: int = int(before[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	var bus_fired: Array = []
	var callable: Callable = func(data: Dictionary) -> void: bus_fired.append(data)
	SignalBus.pomodoro_session_completed.connect(callable)
	GameManager.apply_pomodoro_rewards({"gold": 200, "stamina": 3, "materials": {"construction_material": 5}})
	SignalBus.pomodoro_session_completed.disconnect(callable)
	var after: Dictionary = GameManager.get_state()
	var ok: bool = (
		int(after[GameStateKeys.GOLD]) == gold_before + 200
		and int(after[GameStateKeys.STAMINA]["current"]) == stamina_before + 3
		and int(after[GameStateKeys.TOTAL_POMODORO_COMPLETED]) == total_before + 1
		and bus_fired.size() == 1
	)
	print("[TEST #5] %s | gold %d->%d | stamina %d->%d | total %d->%d | bus_fired=%d" % [
		"PASS" if ok else "FAIL", gold_before, int(after[GameStateKeys.GOLD]),
		stamina_before, int(after[GameStateKeys.STAMINA]["current"]),
		total_before, int(after[GameStateKeys.TOTAL_POMODORO_COMPLETED]), bus_fired.size()])

# --- TEST #6: apply_battle_rewards ---
func _test_battle_rewards() -> void:
	print("\n--- TEST #6: apply_battle_rewards ---")
	var before: Dictionary = GameManager.get_state()
	var gold_before: int = int(before[GameStateKeys.GOLD])
	var mats_before: int = int(before[GameStateKeys.MATERIALS].get("construction_material", 0))
	var bus_fired: Array = []
	var callable: Callable = func(data: Dictionary) -> void: bus_fired.append(data)
	SignalBus.battle_finished.connect(callable)
	GameManager.apply_battle_rewards({"victory": true, "rewards": {"gold": 150, "materials": {"construction_material": 10}}})
	SignalBus.battle_finished.disconnect(callable)
	var after: Dictionary = GameManager.get_state()
	var ok: bool = (
		int(after[GameStateKeys.GOLD]) == gold_before + 150
		and int(after[GameStateKeys.MATERIALS].get("construction_material", 0)) == mats_before + 10
		and bus_fired.size() == 1
	)
	print("[TEST #6] %s | gold %d->%d | mats %d->%d | bus_fired=%d" % [
		"PASS" if ok else "FAIL", gold_before, int(after[GameStateKeys.GOLD]),
		mats_before, int(after[GameStateKeys.MATERIALS].get("construction_material", 0)), bus_fired.size()])

# --- TEST #7: failure paths return false ---
func _test_failure_paths() -> void:
	print("\n--- TEST #7: failure paths return false ---")
	var r1: bool = GameManager.purchase_shop_item("daily", 0)
	var r2: bool = GameManager.level_up_character("char_1")
	var r3: bool = GameManager.unlock_research_node("node_1")
	var r4: bool = GameManager.start_craft("recipe_1")
	var r5: bool = GameManager.collect_craft("queue_1")
	var r6: bool = GameManager.spend_stamina(999999)
	var ok: bool = (not r1) and (not r2) and (not r3) and (not r4) and (not r5) and (not r6)
	print("[TEST #7] %s | shop=%s level=%s research=%s craft=%s collect=%s stamina=%s" % [
		"PASS" if ok else "FAIL", r1, r2, r3, r4, r5, r6])

# --- TEST #12: get_state() snapshot isolation ---
func _test_state_snapshot() -> void:
	print("\n--- TEST #12: get_state() snapshot isolation ---")
	var snapshot: Dictionary = GameManager.get_state()
	var gold_before: int = int(snapshot[GameStateKeys.GOLD])
	snapshot[GameStateKeys.GOLD] = -999999
	var again: Dictionary = GameManager.get_state()
	var ok: bool = int(again[GameStateKeys.GOLD]) == gold_before
	print("[TEST #12] %s | internal gold unchanged after snapshot mutation (%d == %d)" % [
		"PASS" if ok else "FAIL", gold_before, int(again[GameStateKeys.GOLD])])

# --- TEST #13: Balance.initial_state initialization ---
func _test_balance_init() -> void:
	print("\n--- TEST #13: Balance.initial_state initialization ---")
	var state: Dictionary = GameManager.get_state()
	var has_keys: bool = state.has(GameStateKeys.GOLD) and state.has(GameStateKeys.STAMINA) and state.has(GameStateKeys.UNLOCKED_SCREENS)
	var balance_ready: bool = Balance != null and Balance.initial_state != null
	var ok: bool = has_keys and balance_ready
	print("[TEST #13] %s | Balance.initial_state assigned=%s | state has keys=%s" % [
		"PASS" if ok else "FAIL", balance_ready, has_keys])

# --- TEST #15: add_material -> material_changed（素材IDが特定できるか）---
func _test_material_signal() -> void:
	print("\n--- TEST #15: add_material -> material_changed ---")
	var fired: Array = []
	var callable: Callable = func(mat_id: String, amount: int) -> void: fired.append([mat_id, amount])
	GameManager.material_changed.connect(callable)
	var before: int = GameManager.get_material_count("test_material")
	GameManager.add_material("test_material", 7)
	GameManager.material_changed.disconnect(callable)
	var after: int = GameManager.get_material_count("test_material")
	var ok: bool = (
		fired.size() == 1
		and str(fired[0][0]) == "test_material"
		and int(fired[0][1]) == before + 7
		and after == before + 7
	)
	print("[TEST #15] %s | %d->%d | signal=%s" % ["PASS" if ok else "FAIL", before, after, fired])

# --- TEST #16: add_to_inventory の type が勝手に決まらないか ---
func _test_inventory_type() -> void:
	print("\n--- TEST #16: add_to_inventory item_type ---")
	# 種別を省略 -> "" （不明）になること。勝手に "equipment" にしないこと
	GameManager.add_to_inventory("test_item_unknown", 1)
	# 種別を明示 -> その値が入ること
	GameManager.add_to_inventory("test_item_potion", 3, "consumable")
	var inv: Dictionary = GameManager.get_state()[GameStateKeys.INVENTORY]
	var unknown_type: String = str(inv.get("test_item_unknown", {}).get("type", "MISSING"))
	var potion_type: String = str(inv.get("test_item_potion", {}).get("type", "MISSING"))
	# 図鑑にも自動登録されているか
	var codex_ok: bool = bool(GameManager.get_codex_entry("test_item_potion").get("discovered", false))
	var ok: bool = unknown_type == "" and potion_type == "consumable" and codex_ok
	print("[TEST #16] %s | 省略時type='%s'（期待:空） 明示時type='%s'（期待:consumable） codex=%s" % [
		"PASS" if ok else "FAIL", unknown_type, potion_type, codex_ok])
