extends Node

func _ready() -> void:
	print("========== 共通基盤テスト開始 ==========")

	# --- 項目3：add_gold で resource_changed が発火するか ---
	GameManager.resource_changed.connect(_on_resource_changed)
	print("[3] add_gold(100) を呼ぶ →")
	GameManager.add_gold(100)

	# --- 項目12：get_state がスナップショットか ---
	print("[12] get_state のスナップショット検証 →")
	var snapshot: Dictionary = GameManager.get_state()
	var before = snapshot.get(GameStateKeys.GOLD, null)
	snapshot[GameStateKeys.GOLD] = 999999
	var after = GameManager.get_state().get(GameStateKeys.GOLD, null)
	if after == 999999:
		print("  ❌ 失敗：外から書き換えたら内部状態も変わってしまった")
	else:
		print("  ✅ 成功：内部状態は守られた（前=%s 後=%s）" % [before, after])

	# --- 項目4：宝箱 ---
	print("[4] add_pending_chest → open_chest →")
	GameManager.pending_chests_changed.connect(_on_chests_changed)
	GameManager.add_pending_chest({
		"chest_id": "test_chest_1",
		"chest_type": "normal",
		"source": "pomodoro",
		"opened": false,
		"rewards": {"gold": 50, "gems": 0, "materials": {}, "inventory": {}}
	})
	print("  未開封件数 = %d（期待値: 1）" % GameManager.get_pending_chest_count())
	GameManager.open_chest("test_chest_1")
	print("  開封後の未開封件数 = %d（期待値: 0）" % GameManager.get_pending_chest_count())

	# --- 項目5：ポモドーロ報酬 ---
	print("[5] apply_pomodoro_rewards →")
	SignalBus.pomodoro_session_completed.connect(_on_pomodoro_done)
	GameManager.apply_pomodoro_rewards({
		"gold": 30, "stamina": 2, "materials": {"construction_material": 1}
	})

	# --- 項目6：戦闘報酬 ---
	print("[6] apply_battle_rewards →")
	SignalBus.battle_finished.connect(_on_battle_done)
	GameManager.apply_battle_rewards({
		"victory": true, "waves_cleared": 5,
		"rewards": {"gold": 100, "materials": {"construction_material": 3}}
	})

	# --- 項目7：条件を満たさないとき false を返すか ---
	print("[7] 失敗するはずの操作 →")
	print("  purchase_shop_item = %s（期待値: false）" % GameManager.purchase_shop_item("daily", 0))
	print("  level_up_character = %s（期待値: false）" % GameManager.level_up_character("dummy_char"))
	print("  unlock_research_node = %s（期待値: false）" % GameManager.unlock_research_node("dummy_node"))
	print("  start_craft = %s（期待値: false）" % GameManager.start_craft("dummy_recipe"))
	print("  collect_craft = %s（期待値: false）" % GameManager.collect_craft("dummy_queue"))
	print("  spend_stamina(99999) = %s（期待値: false）" % GameManager.spend_stamina(99999))

	# --- 項目13：Balance が読めているか ---
	print("[13] Balance の参照確認 →")
	if Balance == null:
		print("  ❌ Balance が null。Autoloadの登録を確認")
	elif Balance.initial_state == null:
		print("  ⚠️ initial_state が未割り当て。balance.tscn のInspectorで .tres を割り当てる")
	else:
		print("  ✅ Balance.initial_state を参照できた")

	print("========== テスト終了 ==========")


func _on_resource_changed(resource_type: String, new_value) -> void:
	print("  ✅ resource_changed 発火: %s = %s" % [resource_type, new_value])

func _on_chests_changed(pending_count: int) -> void:
	print("  ✅ pending_chests_changed 発火: %d件" % pending_count)

func _on_pomodoro_done(reward_data: Dictionary) -> void:
	print("  ✅ pomodoro_session_completed 発火: %s" % reward_data)

func _on_battle_done(result_data: Dictionary) -> void:
	print("  ✅ battle_finished 発火: %s" % result_data)
