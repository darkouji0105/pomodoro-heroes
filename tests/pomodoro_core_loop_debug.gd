extends Control

# ポモドーロ・コアループ検証用デバッグシーン
# 通常のタイマーを極端に短くして、一通りのフローを確認する。

func _ready() -> void:
	# 1. バランスデータのデバッグ用書き換え
	# focus を 5秒、休憩を 2秒にする
	for preset in Balance.pomodoro.presets:
		preset.focus_duration_sec = 5
		preset.short_break_sec = 2
		preset.long_break_sec = 3
	
	# 2. しきい値判定のデバッグ用書き換え（累計作業分が 0 にならないよう）
	# focus = 5秒 = 0.083分 なので、1分くらいを基準にする
	# （実際には int(seconds/60) で計算するため、5秒だと 0 になってしまう）
	# -> Pomodoro.gd の計算式を確認： var focus_min = int(current_preset.focus_duration_sec / 60)
	# あ、0分になりますね。検証用に Pomodoro.gd を書き換えるわけにはいかないので、
	# preset.focus_duration_sec = 60 (1分) にして、しきい値を 1分 に下げる。
	
	for preset in Balance.pomodoro.presets:
		preset.focus_duration_sec = 60
	
	var light = Balance.pomodoro.protection_light
	light.schedule[0].threshold_min = 1 # 45 -> 1
	
	var middle = Balance.pomodoro.protection_middle
	middle.schedule[0].threshold_min = 1
	middle.schedule[1].threshold_min = 2
	
	var hard = Balance.pomodoro.protection_hard
	hard.schedule[0].threshold_min = 1
	hard.schedule[1].threshold_min = 2
	hard.schedule[2].threshold_min = 3
	hard.schedule[3].threshold_min = 4
	
	print("--- POMODORO DEBUG START ---")
	
	# 21. stamina 上限テスト
	print("[Test 21] add_stamina(9999)...")
	GameManager.add_stamina(9999)
	var st = GameManager.get_state().get(GameStateKeys.STAMINA, {})
	print("Stamina: %d / %d" % [st.get(GameStateKeys.STAMINA_CURRENT, 0), st.get(GameStateKeys.STAMINA_MAX, 0)])
	
	# 24. GameDate テスト
	print("[Test 24] GameDate boundary check...")
	# 基準日: 2024-05-24
	# 03:59:59 (unix: 1716519599) -> 2024-05-23 になるべき
	# 04:00:00 (unix: 1716519600) -> 2024-05-24 になるべき
	# 04:01:00 (unix: 1716519660) -> 2024-05-24 になるべき
	var t_359 = 1716519599
	var t_400 = 1716519600
	var t_401 = 1716519660
	print("03:59 -> %s" % GameDate.get_game_date_string(t_359))
	print("04:00 -> %s" % GameDate.get_game_date_string(t_400))
	print("04:01 -> %s" % GameDate.get_game_date_string(t_401))
	
	# 日またぎテスト準備
	print("[Test Day-Cross] Simulating yesterday selection...")
	var yesterday_unix = Time.get_unix_time_from_system() - 24 * 60 * 60
	GameManager.set_protection_type(GameStateKeys.PROTECTION_LIGHT)
	# 手動で LAST_PROTECTION_SELECTED_AT を昨日に書き換える
	var state = GameManager.get_state()
	state[GameStateKeys.LAST_PROTECTION_SELECTED_AT] = str(yesterday_unix)
	state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = 45 # 前日の作業分
	
	# 13. 長休憩テスト準備
	print("[Test 13] Modifying long_break_interval to 2...")
	Balance.pomodoro.presets[0].long_break_interval = 2
	Balance.pomodoro.presets[0].default_total_sets = 3 # 3セットにして2回目で長休憩を確認
	
	print("Presets and thresholds modified for testing.")
	
	# シーン遷移
	SceneManager.change_scene("res://scenes/pomodoro/pomodoro.tscn")
