extends SceneTree

func _init() -> void:
	# 1. 加護ごとのスケジュール作成
	var light = ProtectionTypeConfig.new()
	var e1 = ChestScheduleEntry.new()
	e1.threshold_min = 45
	e1.chest_type = "bonus_small"
	light.schedule = [e1]
	ResourceSaver.save(light, "res://resources/balance/protection_light.tres")

	var middle = ProtectionTypeConfig.new()
	var e2 = ChestScheduleEntry.new()
	e2.threshold_min = 45
	e2.chest_type = "generic"
	var e3 = ChestScheduleEntry.new()
	e3.threshold_min = 90
	e3.chest_type = "bonus_medium"
	middle.schedule = [e2, e3]
	ResourceSaver.save(middle, "res://resources/balance/protection_middle.tres")

	var hard = ProtectionTypeConfig.new()
	var e4 = ChestScheduleEntry.new()
	e4.threshold_min = 45
	e4.chest_type = "generic"
	var e5 = ChestScheduleEntry.new()
	e5.threshold_min = 90
	e5.chest_type = "generic"
	var e6 = ChestScheduleEntry.new()
	e6.threshold_min = 135
	e6.chest_type = "generic"
	var e7 = ChestScheduleEntry.new()
	e7.threshold_min = 180
	e7.chest_type = "bonus_large"
	hard.schedule = [e4, e5, e6, e7]
	ResourceSaver.save(hard, "res://resources/balance/protection_hard.tres")

	# 2. PomodoroConfig の作成
	var config = PomodoroConfig.new()
	config.protection_light = load("res://resources/balance/protection_light.tres")
	config.protection_middle = load("res://resources/balance/protection_middle.tres")
	config.protection_hard = load("res://resources/balance/protection_hard.tres")
	config.gold_per_focus_minute = 0.0
	config.stamina_per_focus_minute = 0.2
	config.materials_per_focus_minute = 0.0
	
	# プリセット
	var p1 = PomodoroPreset.new()
	p1.preset_id = "short"
	p1.focus_duration_sec = 900
	p1.short_break_sec = 180
	p1.long_break_sec = 1800
	p1.long_break_interval = 4
	p1.default_total_sets = 4
	
	var p2 = PomodoroPreset.new()
	p2.preset_id = "standard"
	p2.focus_duration_sec = 1500
	p2.short_break_sec = 300
	p2.long_break_sec = 1800
	p2.long_break_interval = 4
	p2.default_total_sets = 4
	
	var p3 = PomodoroPreset.new()
	p3.preset_id = "long"
	p3.focus_duration_sec = 3000
	p3.short_break_sec = 600
	p3.long_break_sec = 1800
	p3.long_break_interval = 4
	p3.default_total_sets = 3
	
	config.presets = [p1, p2, p3]
	config.min_sets = 1
	config.max_sets = 12
	config.min_long_break_minutes = 5
	config.max_long_break_minutes = 60
	config.min_long_break_interval = 2
	config.max_long_break_interval = 8
	
	# 宝箱の中身
	var c1 = ChestContentConfig.new()
	c1.chest_type = "generic"
	c1.materials = {"construction_material": 4}
	
	var c2 = ChestContentConfig.new()
	c2.chest_type = "bonus_small"
	c2.materials = {"construction_material": 10}
	
	var c3 = ChestContentConfig.new()
	c3.chest_type = "bonus_medium"
	c3.materials = {"construction_material": 25}
	
	var c4 = ChestContentConfig.new()
	c4.chest_type = "bonus_large"
	c4.materials = {"construction_material": 30}
	
	config.chest_contents = [c1, c2, c3, c4]
	config.session_title_max_length = 30
	
	ResourceSaver.save(config, "res://resources/balance/pomodoro_config.tres")
	print("Generated pomodoro_config.tres and protection tres files.")

	# 3. InitialStateConfig の更新
	var initial = load("res://resources/balance/initial_state_config.tres")
	if initial:
		initial.starting_stamina_max = 100
		initial.starting_stamina_current = 20
		ResourceSaver.save(initial, "res://resources/balance/initial_state_config.tres")
		print("Updated initial_state_config.tres.")
	else:
		print("Failed to load initial_state_config.tres.")
	
	quit()
