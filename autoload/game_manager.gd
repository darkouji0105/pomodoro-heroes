extends Node

# GameManager: 全画面のSingle Source of Truth。
# 拠点共通データ＋育成・図鑑・ショップ・研究ツリー・製作キュー等の永続データを保持・更新する。
# 他のAutoloadやシーンは直接データを書き換えず、必ず下記関数を経由すること。

var _state: Dictionary = {}

# resource_type には GameStateKeys の定数（GOLD / GEMS / STAMINA）を渡す。
# 文字列リテラルを直接渡さないこと（typoしても実行時まで気づけないため）。
signal resource_changed(resource_type: String, new_value: Variant)
# 素材は種類ごとに表示先が分かれるため、辞書全体ではなく
# 「どの素材がいくつになったか」を個別に通知する専用シグナルを分けている。
signal material_changed(material_id: String, new_amount: int)
signal screen_unlocked(screen_id: String)
signal inventory_changed(item_id: String)
signal pending_chests_changed(pending_count: int)
# 育成データの変化。レベル・ステータス・装備・スキルのいずれかが変わったときに発火する。
# 素材の増減は material_changed 側で通知されるため、こちらには含めない。
signal character_growth_changed(character_id: String)
# 研究ノードの解放。素材の増減は material_changed 側で通知されるため、こちらには含めない。
# 実効レベル上限・ステータス上昇は都度計算のため、解放の通知だけで全画面が追従できる。
signal research_node_unlocked(node_id: String)

# get_level_up_cost() が返す Dictionary のキー。
# 呼び出し側が文字列リテラルを書かなくて済むようにここで公開する。
const LEVEL_UP_COST_MATERIAL_ID: String = "material_id"
const LEVEL_UP_COST_AMOUNT: String = "amount"

# get_stat_boost_all() が「全ステータス対象」の加算をまとめるキー。
# 既存の get_stat_boost_all() が target_stat 未指定時に使う値と揃える必要がある。
const STAT_BOOST_ALL_KEY: String = "all"

# get_research_unlock_cost() が返す Dictionary のキー。
# get_level_up_cost() と同じ形にそろえてある。
const RESEARCH_COST_MATERIAL_ID: String = "material_id"
const RESEARCH_COST_AMOUNT: String = "amount"

# research.json 側のキー（状態ではなくマスターデータのため GameStateKeys には置かない）。
const RESEARCH_NODE_COST_MATERIAL_ID: String = "cost_material_id"
const RESEARCH_NODE_COST_AMOUNT: String = "cost_amount"

func _ready() -> void:
	print("[GameManager] _ready() — initializing from Balance.initial_state")
	if Balance != null and Balance.initial_state != null:
		_init_from_config(Balance.initial_state)
	else:
		push_warning("[GameManager] Balance.initial_state is null — using empty defaults")
		_state = _empty_state_template()
	# 研究ツリーを research.json から流し込む。
	# _empty_state_template() の research_tree は {} のため、これが無いと画面に1つも出ない。
	_sync_research_tree_from_master()
	# materials も出す。initial_state に足した素材が届いているかを、
	# セーブファイルを開かずに確認できるようにするため。
	print("[GameManager] init complete. gold=%d stamina=%s materials=%s unlocked_screens=%s" % [
		int(_state.get(GameStateKeys.GOLD, 0)),
		_state.get(GameStateKeys.STAMINA, {}),
		_state.get(GameStateKeys.MATERIALS, {}),
		_state.get(GameStateKeys.UNLOCKED_SCREENS, {}),
	])

# --- 初期化 ---

func _init_from_config(config: InitialStateConfig) -> void:
	_state = _empty_state_template()
	
	var unlocked: Dictionary = {}
	for screen_id: String in config.initially_unlocked_screens:
		unlocked[screen_id] = true
	
	_state[GameStateKeys.GOLD] = config.starting_gold
	_state[GameStateKeys.GEMS] = config.starting_gems
	_state[GameStateKeys.STAMINA] = {
		GameStateKeys.STAMINA_CURRENT: config.starting_stamina_current,
		GameStateKeys.STAMINA_MAX: config.starting_stamina_max
	}
	_state[GameStateKeys.MATERIALS] = config.starting_materials.duplicate(true)
	_state[GameStateKeys.SCENARIO_CHAPTER] = config.starting_scenario_chapter
	_state[GameStateKeys.STORY][GameStateKeys.STORY_CURRENT_CHAPTER] = config.starting_scenario_chapter
	_state[GameStateKeys.SAVE_VERSION] = config.save_version
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked

func _init_empty() -> void:
	_state = _empty_state_template()

func _empty_state_template() -> Dictionary:
	return {
		GameStateKeys.GOLD: 0,
		GameStateKeys.GEMS: 0,
		GameStateKeys.STAMINA: {GameStateKeys.STAMINA_CURRENT: 0, GameStateKeys.STAMINA_MAX: 0},
		GameStateKeys.MATERIALS: {},
		GameStateKeys.INVENTORY: {},
		GameStateKeys.PENDING_CHESTS: [],
		GameStateKeys.UNLOCKED_SCREENS: {},
		GameStateKeys.SCENARIO_CHAPTER: 1,
		GameStateKeys.BOSS_UNLOCKED: false,
		GameStateKeys.PITY_COUNTERS: {},
		GameStateKeys.TOTAL_POMODORO_COMPLETED: 0,
		GameStateKeys.LAST_POMODORO_END_AT: "",
		GameStateKeys.SAVE_VERSION: 1,
		GameStateKeys.LAST_SAVED_AT: "",
		GameStateKeys.STORY: {GameStateKeys.STORY_CURRENT_CHAPTER: 1, GameStateKeys.STORY_STAGES: {}},
		GameStateKeys.TRAINING_MODE_UNLOCKED: false,
		GameStateKeys.CODEX: {},
		GameStateKeys.DAILY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.WEEKLY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.MONTHLY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.CHARACTER_GROWTH: {},
		GameStateKeys.RESEARCH_TREE: {},
		GameStateKeys.RECIPES_UNLOCKED: {},
		GameStateKeys.CRAFTING_QUEUE: [],
		GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY: 0,
		GameStateKeys.REACHED_CHEST_THRESHOLDS: [],
		GameStateKeys.UNCLAIMED_CHESTS: [],
		GameStateKeys.LAST_PROTECTION_SELECTED_AT: "",
		GameStateKeys.SELECTED_PROTECTION_TYPE: "",
		GameStateKeys.POTION_FOCUS_REMAINDER: 0,
	}

# --- 内部ヘルパー ---

# _state 内のネストしたDictionary/Arrayを取り出す。
# GDScriptのDictionary・Arrayは参照渡しのため、.get() で取り出したものを直接書き換えると
# _state へ代入し直す前に内部状態が変わってしまう。
# 必ず複製を返し、呼び出し側が明示的に _state へ代入し直す形にする
# （「変更前の値と比較する」処理を後から足しても壊れないようにするため）。
func _copy_dict(key: String) -> Dictionary:
	var value: Variant = _state.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate()
	return {}

func _copy_array(key: String) -> Array:
	var value: Variant = _state.get(key, [])
	if value is Array:
		return (value as Array).duplicate()
	return []

# --- 基本リソース ---

func get_state() -> Dictionary:
	# 内部Dictionaryそのものではなく、duplicate(true)した読み取り専用スナップショットを返す。
	# 呼び出し側からの直接書き換えを防ぐため（AGENTS.md「状態アクセスのルール」準拠）。
	return _state.duplicate(true)

func add_gold(amount: int) -> void:
	_state[GameStateKeys.GOLD] = int(_state.get(GameStateKeys.GOLD, 0)) + amount
	print("[GameManager] add_gold(%d) -> %d" % [amount, _state[GameStateKeys.GOLD]])
	resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])

func add_gems(amount: int) -> void:
	_state[GameStateKeys.GEMS] = int(_state.get(GameStateKeys.GEMS, 0)) + amount
	print("[GameManager] add_gems(%d) -> %d" % [amount, _state[GameStateKeys.GEMS]])
	resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])

func add_stamina(amount: int) -> void:
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	var max_stamina: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	
	current += amount
	if current > max_stamina:
		current = max_stamina
	
	stamina[GameStateKeys.STAMINA_CURRENT] = current
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] add_stamina(%d) -> current=%d" % [amount, current])
	resource_changed.emit(GameStateKeys.STAMINA, current)

func spend_stamina(amount: int) -> bool:
	# 足りなければ何もせずfalseを返す
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	if current < amount:
		print("[GameManager] spend_stamina(%d) -> false (have %d)" % [amount, current])
		return false
	stamina[GameStateKeys.STAMINA_CURRENT] = current - amount
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] spend_stamina(%d) -> true (current=%d)" % [amount, int(stamina[GameStateKeys.STAMINA_CURRENT])])
	resource_changed.emit(GameStateKeys.STAMINA, stamina[GameStateKeys.STAMINA_CURRENT])
	return true

func add_material(material_id: String, amount: int) -> void:
	var materials: Dictionary = _copy_dict(GameStateKeys.MATERIALS)
	var new_amount: int = int(materials.get(material_id, 0)) + amount
	materials[material_id] = new_amount
	_state[GameStateKeys.MATERIALS] = materials
	print("[GameManager] add_material('%s', %d) -> %d" % [material_id, amount, new_amount])
	# 辞書全体ではなく「どの素材がいくつになったか」を通知する。
	# 拠点画面は素材の種類ごとにラベルを持つため、種類が特定できないと差分更新できない。
	material_changed.emit(material_id, new_amount)

func get_material_count(material_id: String) -> int:
	var materials: Dictionary = _state.get(GameStateKeys.MATERIALS, {})
	return int(materials.get(material_id, 0))

# item_type を省略した場合は "" （種別不明）として登録する。
# 勝手に "equipment" 等を推測すると、消費アイテムまで装備扱いになるため。
# 種別が分かる呼び出し元（ショップ・作業場・宝箱など）は必ず明示的に渡すこと。
func add_to_inventory(item_id: String, count: int, item_type: String = GameStateKeys.ITEM_TYPE_UNKNOWN) -> void:
	# 初出のitem_idであれば、図鑑（codex）のdiscoveredも自動でtrueにする
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	var entry: Dictionary = {}
	if inventory.has(item_id) and inventory[item_id] is Dictionary:
		entry = (inventory[item_id] as Dictionary).duplicate(true)
	entry[GameStateKeys.ITEM_COUNT] = int(entry.get(GameStateKeys.ITEM_COUNT, 0)) + count
	if item_type != GameStateKeys.ITEM_TYPE_UNKNOWN:
		entry[GameStateKeys.ITEM_TYPE] = item_type
	elif not entry.has(GameStateKeys.ITEM_TYPE):
		entry[GameStateKeys.ITEM_TYPE] = GameStateKeys.ITEM_TYPE_UNKNOWN
	if not entry.has(GameStateKeys.ITEM_SLOT_POSITION):
		entry[GameStateKeys.ITEM_SLOT_POSITION] = {GameStateKeys.POS_X: 0, GameStateKeys.POS_Y: 0}
	if not entry.has(GameStateKeys.ITEM_PROPERTIES):
		entry[GameStateKeys.ITEM_PROPERTIES] = {}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory

	var codex: Dictionary = _copy_dict(GameStateKeys.CODEX)
	var newly_discovered: bool = not codex.has(item_id)
	if newly_discovered:
		codex[item_id] = {GameStateKeys.CODEX_DISCOVERED: true, GameStateKeys.CODEX_OBTAINED_AT: str(Time.get_unix_time_from_system())}
		_state[GameStateKeys.CODEX] = codex
	print("[GameManager] add_to_inventory('%s', %d, type='%s') -> count=%d newly_discovered=%s" % [
		item_id, count, str(entry[GameStateKeys.ITEM_TYPE]), int(entry[GameStateKeys.ITEM_COUNT]), newly_discovered])
	inventory_changed.emit(item_id)

# --- 画面アンロック ---

func unlock_screen(screen_id: String) -> void:
	var unlocked: Dictionary = _copy_dict(GameStateKeys.UNLOCKED_SCREENS)
	unlocked[screen_id] = true
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked
	print("[GameManager] unlock_screen('%s')" % screen_id)
	screen_unlocked.emit(screen_id)

func is_screen_unlocked(screen_id: String) -> bool:
	var unlocked: Dictionary = _state.get(GameStateKeys.UNLOCKED_SCREENS, {})
	return bool(unlocked.get(screen_id, false))

# --- 宝箱 ---

func add_pending_chest(chest_data: Dictionary) -> void:
	var chests: Array = _copy_array(GameStateKeys.PENDING_CHESTS)
	chests.append(chest_data.duplicate(true))
	_state[GameStateKeys.PENDING_CHESTS] = chests
	print("[GameManager] add_pending_chest() -> pending_count=%d" % get_pending_chest_count())
	pending_chests_changed.emit(get_pending_chest_count())

func open_chest(chest_id: String) -> bool:
	# 存在しなければ何もせずfalse。存在すればopened=trueにしてrewardsを反映
	var chests: Array = _copy_array(GameStateKeys.PENDING_CHESTS)
	for i: int in range(chests.size()):
		if not (chests[i] is Dictionary):
			continue
		var chest: Dictionary = (chests[i] as Dictionary).duplicate(true)
		if str(chest.get(GameStateKeys.CHEST_ID, "")) != chest_id:
			continue
		if bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			print("[GameManager] open_chest('%s') -> false (already opened)" % chest_id)
			return false
		chest[GameStateKeys.CHEST_OPENED] = true
		chests[i] = chest
		_state[GameStateKeys.PENDING_CHESTS] = chests
		# rewards を反映（既存の add_* 関数を使い回し、重複実装を避ける）
		var rewards: Dictionary = chest.get(GameStateKeys.CHEST_REWARDS, {})
		if rewards.has(GameStateKeys.REWARD_GOLD):
			add_gold(int(rewards[GameStateKeys.REWARD_GOLD]))
		if rewards.has(GameStateKeys.REWARD_GEMS):
			add_gems(int(rewards[GameStateKeys.REWARD_GEMS]))
		if rewards.has(GameStateKeys.REWARD_MATERIALS) and rewards[GameStateKeys.REWARD_MATERIALS] is Dictionary:
			var mats: Dictionary = rewards[GameStateKeys.REWARD_MATERIALS]
			for mat_id: String in mats:
				add_material(mat_id, int(mats[mat_id]))
		if rewards.has(GameStateKeys.REWARD_INVENTORY) and rewards[GameStateKeys.REWARD_INVENTORY] is Dictionary:
			var items: Dictionary = rewards[GameStateKeys.REWARD_INVENTORY]
			for item_id: String in items:
				add_to_inventory(item_id, int(items[item_id]))
		print("[GameManager] open_chest('%s') -> true" % chest_id)
		pending_chests_changed.emit(get_pending_chest_count())
		return true
	print("[GameManager] open_chest('%s') -> false (not found)" % chest_id)
	return false

func get_pending_chest_count() -> int:
	# opened == false の件数
	var chests: Array = _state.get(GameStateKeys.PENDING_CHESTS, [])
	var count: int = 0
	for chest: Dictionary in chests:
		if not bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			count += 1
	return count

# --- ポモドーロ報酬 ---

func apply_pomodoro_rewards(reward_data: Dictionary) -> void:
	# gold/stamina/materialsの反映、total_pomodoro_completedの加算、
	# last_pomodoro_end_atの更新、SignalBus.pomodoro_session_completedの発火までを一括で行う
	print("[GameManager] apply_pomodoro_rewards(%s)" % reward_data)
	if reward_data.has(GameStateKeys.REWARD_GOLD):
		add_gold(int(reward_data[GameStateKeys.REWARD_GOLD]))
	if reward_data.has(GameStateKeys.REWARD_STAMINA):
		add_stamina(int(reward_data[GameStateKeys.REWARD_STAMINA]))
	if reward_data.has(GameStateKeys.REWARD_MATERIALS) and reward_data[GameStateKeys.REWARD_MATERIALS] is Dictionary:
		var mats: Dictionary = reward_data[GameStateKeys.REWARD_MATERIALS]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# total_pomodoro_completed +1
	_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(_state.get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0)) + 1
	# last_pomodoro_end_at 更新
	_state[GameStateKeys.LAST_POMODORO_END_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] total_pomodoro_completed -> %d" % _state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	# 発火元をGameManagerに一本化（呼び出し元のポモドーロ画面側では発火させない・二重発火防止）
	SignalBus.pomodoro_session_completed.emit(reward_data)

# --- ポモドーロ：しきい値と宝箱 ---

# その日の累計作業分を加算する。振り返りが確定したセットのみ呼ばれる想定。
func add_focus_minutes(minutes: int) -> void:
	_refresh_daily_pomodoro_stats_if_needed()
	
	var current: int = int(_state.get(GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY, 0))
	var new_total: int = current + minutes
	_state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = new_total
	print("[GameManager] add_focus_minutes(%d) -> total=%d" % [minutes, new_total])
	# ここでしきい値判定を自動で行わず、PomodoroController 側で明示的に跨ぎを制御できるように口を開けておく
	# (指示書 7-6 は PomodoroController 側で判定する手順になっている)

# その日の累計作業分を取得する
func get_cumulative_focus_minutes() -> int:
	_refresh_daily_pomodoro_stats_if_needed()
	return int(_state.get(GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY, 0))

# しきい値に到達済みか（同じしきい値で二重に宝箱を発生させないため）
func has_reached_threshold(threshold_min: int) -> bool:
	var reached: Array = _state.get(GameStateKeys.REACHED_CHEST_THRESHOLDS, [])
	return int(threshold_min) in reached

# しきい値到達を記録し、受け取り待ちの宝箱を積む。
# この時点では add_pending_chest() を呼ばない（受け取りは拠点帰還時）。
func record_reached_threshold(threshold_min: int, chest_type: String) -> void:
	var reached: Array = _copy_array(GameStateKeys.REACHED_CHEST_THRESHOLDS)
	var unclaimed: Array = _copy_array(GameStateKeys.UNCLAIMED_CHESTS)
	
	if not (int(threshold_min) in reached):
		reached.append(int(threshold_min))
		unclaimed.append(chest_type)
		_state[GameStateKeys.REACHED_CHEST_THRESHOLDS] = reached
		_state[GameStateKeys.UNCLAIMED_CHESTS] = unclaimed
		print("[GameManager] recorded threshold: %d min -> %s" % [threshold_min, chest_type])

# 受け取り待ちの宝箱の一覧を取得する
func get_unclaimed_chests() -> Array:
	return _state.get(GameStateKeys.UNCLAIMED_CHESTS, []).duplicate(true)

# 受け取り待ちの宝箱をすべて pending_chests へ移し、unclaimed_chests を空にする。
# 付与した件数を返す。
func claim_pending_chests() -> int:
	var unclaimed: Array = _copy_array(GameStateKeys.UNCLAIMED_CHESTS)
	if unclaimed.is_empty():
		return 0
	
	var count: int = 0
	for chest_type: String in unclaimed:
		var content_config: ChestContentConfig = null
		for c in Balance.pomodoro.chest_contents:
			if c.chest_type == chest_type:
				content_config = c
				break
		
		if content_config == null:
			push_warning("[GameManager] chest_type not found in config: " + chest_type)
			continue
			
		var chest_data: Dictionary = {
			GameStateKeys.CHEST_ID: str(Time.get_unix_time_from_system()) + "_" + str(randi()),
			GameStateKeys.CHEST_TYPE: chest_type,
			GameStateKeys.CHEST_SOURCE: GameStateKeys.CHEST_SOURCE_POMODORO,
			GameStateKeys.CHEST_OBTAINED_AT: str(Time.get_unix_time_from_system()),
			GameStateKeys.CHEST_OPENED: false,
			GameStateKeys.CHEST_REWARDS: {
				GameStateKeys.REWARD_GOLD: 0,
				GameStateKeys.REWARD_GEMS: 0,
				GameStateKeys.REWARD_STAMINA: 0,
				GameStateKeys.REWARD_MATERIALS: content_config.materials.duplicate(true),
				GameStateKeys.REWARD_INVENTORY: {}
			}
		}
		add_pending_chest(chest_data)
		count += 1
	
	_state[GameStateKeys.UNCLAIMED_CHESTS] = []
	print("[GameManager] claimed %d chests" % count)
	return count

# 加護の選択を記録する（選択時刻も記録し、翌日の再表示判定に使う）
func set_protection_type(protection_id: String) -> void:
	_refresh_daily_pomodoro_stats_if_needed()
	_state[GameStateKeys.SELECTED_PROTECTION_TYPE] = protection_id
	_state[GameStateKeys.LAST_PROTECTION_SELECTED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] set_protection_type('%s')" % protection_id)

# 今日すでに加護を選んでいるか（毎朝4:00基準）
func has_selected_protection_today() -> bool:
	var last_at: String = str(_state.get(GameStateKeys.LAST_PROTECTION_SELECTED_AT, ""))
	if last_at == "":
		return false
	return GameDate.is_same_game_day(float(last_at), Time.get_unix_time_from_system())

# 日付が変わっていれば当日データをリセットする。
func reset_daily_pomodoro_state_if_needed() -> void:
	_refresh_daily_pomodoro_stats_if_needed()

# 日付が変わっていたら累計作業分としきい値をリセットする内部関数
func _refresh_daily_pomodoro_stats_if_needed() -> void:
	var last_at: String = str(_state.get(GameStateKeys.LAST_PROTECTION_SELECTED_AT, ""))
	if last_at != "" and not GameDate.is_same_game_day(float(last_at), Time.get_unix_time_from_system()):
		print("[GameManager] new day detected - resetting daily pomodoro stats")
		_state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = 0
		_state[GameStateKeys.REACHED_CHEST_THRESHOLDS] = []
		_state[GameStateKeys.SELECTED_PROTECTION_TYPE] = ""
		# UNCLAIMED_CHESTS はリセットしない

func _check_chest_thresholds(_old_total: int, new_total: int) -> void:
	pass # PomodoroController 側で呼ぶため不要になったが互換性のために残すか、削除する

func add_cumulative_focus_minutes(minutes: int) -> void:
	add_focus_minutes(minutes)

func claim_unclaimed_chests() -> void:
	var _cnt = claim_pending_chests()

func is_protection_selected_today() -> bool:
	return has_selected_protection_today()

func get_cumulative_focus_minutes_today() -> int:
	return get_cumulative_focus_minutes()

# --- 戦闘報酬 ---

func apply_battle_rewards(result_data: Dictionary) -> void:
	# gold/materialsの反映、SignalBus.battle_finishedの発火までを一括で行う
	# ※ expは扱わない（レベル上げは専用素材消費型。DATA_SCHEMA.md 4-3準拠）
	print("[GameManager] apply_battle_rewards(%s)" % result_data)
	var rewards: Dictionary = result_data.get(GameStateKeys.BATTLE_REWARDS, {})
	if rewards.has(GameStateKeys.REWARD_GOLD):
		add_gold(int(rewards[GameStateKeys.REWARD_GOLD]))
	if rewards.has(GameStateKeys.REWARD_MATERIALS) and rewards[GameStateKeys.REWARD_MATERIALS] is Dictionary:
		var mats: Dictionary = rewards[GameStateKeys.REWARD_MATERIALS]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# 発火元をGameManagerに一本化（呼び出し元の戦闘画面側では発火させない・二重発火防止）
	SignalBus.battle_finished.emit(result_data)

# --- 倉庫：図鑑・インベントリ整理 ---

func get_codex_entry(item_id: String) -> Dictionary:
	var codex: Dictionary = _state.get(GameStateKeys.CODEX, {})
	var entry: Dictionary = codex.get(item_id, {})
	return entry.duplicate(true)

func update_inventory_slot_position(item_id: String, position: Vector2i) -> void:
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	if not inventory.has(item_id):
		print("[GameManager] update_inventory_slot_position('%s') -> item not in inventory" % item_id)
		return
	var entry: Dictionary = (inventory[item_id] as Dictionary).duplicate(true)
	entry[GameStateKeys.ITEM_SLOT_POSITION] = {GameStateKeys.POS_X: position.x, GameStateKeys.POS_Y: position.y}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	print("[GameManager] update_inventory_slot_position('%s', %s)" % [item_id, position])
	inventory_changed.emit(item_id)

# --- ショップ ---

func _shop_key(shop_type: String) -> String:
	match shop_type:
		GameStateKeys.SHOP_TYPE_DAILY:
			return GameStateKeys.DAILY_SHOP
		GameStateKeys.SHOP_TYPE_WEEKLY:
			return GameStateKeys.WEEKLY_SHOP
		GameStateKeys.SHOP_TYPE_MONTHLY:
			return GameStateKeys.MONTHLY_SHOP
	return ""

func get_shop_lineup(shop_type: String) -> Array:
	var key: String = _shop_key(shop_type)
	if key == "":
		print("[GameManager] get_shop_lineup('%s') -> unknown shop_type" % shop_type)
		return []
	var shop: Dictionary = _state.get(key, {})
	var line_up: Variant = shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if line_up is Array:
		return (line_up as Array).duplicate(true)
	return []

func purchase_shop_item(shop_type: String, slot_id: int) -> bool:
	# 残高不足・売り切れなら何もせずfalse（空実装：ラインナップが空のため常にfalse）
	print("[GameManager] purchase_shop_item('%s', %d) -> false (dummy: lineup empty)" % [shop_type, slot_id])
	return false

func refresh_shop_if_needed(shop_type: String) -> void:
	print("[GameManager] refresh_shop_if_needed('%s') (dummy)" % shop_type)

# --- 育成 ---

# 育成データを返す。エントリが無ければ characters.json から既定値（レベル1）を組み立てて返す。
#
# 既定値は _state に書き込まない。理由：
#  - レベル1のキャラはセーブデータに現れず、キャラクターを追加しても移行処理が要らない
#  - 「読んだだけで状態が変わる」getter を作らない
func get_character_growth(character_id: String) -> Dictionary:
	var growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	var entry: Dictionary = growth.get(character_id, {})
	if entry.is_empty():
		return _default_growth_for(character_id)
	return entry.duplicate(true)

# 保存されている素の値に、研究のボーナスを合成した最終値を返す。
# 表示と（将来的には）戦闘がこちらを使う。装備補正は装備実装時にここへ足す。
#
# stats そのものに研究の効果を混ぜないのは、研究ノードの効果値を変えたときに
# 既存セーブの stats が実態とずれるのを避けるため。
func get_effective_stats(character_id: String) -> Dictionary:
	var growth: Dictionary = get_character_growth(character_id)
	var raw: Dictionary = growth.get(GameStateKeys.GROWTH_STATS, {})
	var boosts: Dictionary = get_stat_boost_all()
	var boost_all: int = int(boosts.get(STAT_BOOST_ALL_KEY, 0))

	var result: Dictionary = {}
	for stat_key: String in _stat_keys():
		result[stat_key] = int(raw.get(stat_key, 0)) + int(boosts.get(stat_key, 0)) + boost_all
	return result

# 現在のレベルから1つ上げるのに必要な素材を返す。
# 戻り値: {material_id: String, amount: int}
func get_level_up_cost(character_id: String) -> Dictionary:
	var empty: Dictionary = {LEVEL_UP_COST_MATERIAL_ID: "", LEVEL_UP_COST_AMOUNT: 0}
	if Balance == null or Balance.character == null:
		push_warning("[GameManager] get_level_up_cost: Balance.character is null")
		return empty

	var config: CharacterConfig = Balance.character
	var level: int = int(get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var base: float = float(config.base_level_up_cost)
	var growth: float = config.cost_growth_per_level
	var fallback: float = base + growth * float(level - 1)

	var amount: int = GrowthFormula.evaluate_int(
		config.level_up_cost_formula,
		{"base": base, "growth": growth, "level": float(level)},
		fallback
	)
	if amount < 0:
		amount = 0

	return {
		LEVEL_UP_COST_MATERIAL_ID: config.level_up_material_id,
		LEVEL_UP_COST_AMOUNT: amount,
	}

# レベルを1つ上げる。上限到達・素材不足のときは何もせず false を返す。
# 成功時は素材を消費し、stats を再計算して character_growth_changed を発火する。
func level_up_character(character_id: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		push_warning("[GameManager] level_up_character: unknown character_id: " + character_id)
		return false

	var level: int = int(growth.get(GameStateKeys.GROWTH_LEVEL, 1))
	var cap: int = get_effective_level_cap(character_id)
	if level >= cap:
		print("[GameManager] level_up_character('%s') -> false (level %d >= cap %d)" % [character_id, level, cap])
		return false

	var cost: Dictionary = get_level_up_cost(character_id)
	var material_id: String = str(cost.get(LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(LEVEL_UP_COST_AMOUNT, 0))
	if material_id == "":
		push_warning("[GameManager] level_up_character: level_up_material_id が未設定（character_config.tres）")
		return false

	# add_material() は残高を確認しないため、減算する前に必ずここで確認する。
	var owned: int = get_material_count(material_id)
	if owned < amount:
		print("[GameManager] level_up_character('%s') -> false (material %s: %d < %d)" % [
			character_id, material_id, owned, amount
		])
		return false

	if amount > 0:
		add_material(material_id, -amount)

	var new_level: int = level + 1
	# growth は get_character_growth() が返した複製なので、直接書き換えてよい。
	growth[GameStateKeys.GROWTH_LEVEL] = new_level
	growth[GameStateKeys.GROWTH_STATS] = _recalc_stats(character_id, new_level)

	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	all_growth[character_id] = growth
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth

	print("[GameManager] level_up_character('%s') -> true (level=%d stats=%s)" % [
		character_id, new_level, growth[GameStateKeys.GROWTH_STATS]
	])
	character_growth_changed.emit(character_id)
	return true

# --- 育成：内部ヘルパー ---

# stats のキー4つ。順序を固定したいので配列で持つ。
func _stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_HP,
		GameStateKeys.STAT_ATK,
		GameStateKeys.STAT_DEF,
		GameStateKeys.STAT_SPD,
	]

# characters.json からレベル1の既定値を組み立てる。存在しないIDなら空を返す。
#
# MasterDataLoader は JSON をそのまま返すため、数値は float で来る。
# int() で包まないと、セーブに "hp": 120.0 と書かれる。
func _default_growth_for(character_id: String) -> Dictionary:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	if char_data.is_empty():
		return {}

	var stats: Dictionary = {}
	for stat_key: String in _stat_keys():
		stats[stat_key] = int(char_data.get(stat_key, 0))

	return {
		GameStateKeys.GROWTH_LEVEL: 1,
		GameStateKeys.GROWTH_STATS: stats,
		# skills の中身（slots）はスキル選択の実装時に入れる。
		# 今そこに "slots" と書くと state_keys.gd に無いキーを文字列で書くことになるため空にしておく。
		GameStateKeys.GROWTH_SKILLS: {},
		GameStateKeys.GROWTH_EQUIPMENT: {
			GameStateKeys.EQUIP_WEAPON: null,
			GameStateKeys.EQUIP_ARMOR: null,
			GameStateKeys.EQUIP_ACCESSORY: null,
		},
	}

# 指定レベルにおける stats を、stat_growth_formula で計算し直す。
# 差分を足し込むのではなく毎回レベルから計算するため、式を変えても既存データが追従する。
func _recalc_stats(character_id: String, level: int) -> Dictionary:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	if char_data.is_empty():
		return {}

	var growth_table: Dictionary = char_data.get("growth_per_level", {})
	var formula: String = ""
	if Balance != null and Balance.character != null:
		formula = Balance.character.stat_growth_formula

	var stats: Dictionary = {}
	for stat_key: String in _stat_keys():
		var base: float = float(char_data.get(stat_key, 0))
		# growth_per_level を持たないキャラは 0 として扱う（伸びないだけで、エラーにしない）。
		var growth: float = float(growth_table.get(stat_key, 0))
		var fallback: float = base + growth * float(level - 1)
		stats[stat_key] = GrowthFormula.evaluate_int(
			formula,
			{"base": base, "growth": growth, "level": float(level)},
			fallback
		)
	return stats

func equip_item(character_id: String, slot: String, item_id: String) -> void:
	print("[GameManager] equip_item('%s', '%s', '%s') (dummy)" % [character_id, slot, item_id])

func unequip_item(character_id: String, slot: String) -> void:
	print("[GameManager] unequip_item('%s', '%s') (dummy)" % [character_id, slot])

func select_skill(character_id: String, slot_id: int, skill_id: String) -> void:
	print("[GameManager] select_skill('%s', %d, '%s') (dummy)" % [character_id, slot_id, skill_id])

# --- 研究 ---

func get_research_tree() -> Dictionary:
	return _state.get(GameStateKeys.RESEARCH_TREE, {}).duplicate(true)

# 解放に必要な素材を返す。戻り値: {material_id: String, amount: int}
# コストは research.json 側に持つ（ノードごとに違うため .tres の単一値では表せない）。
func get_research_unlock_cost(node_id: String) -> Dictionary:
	var empty: Dictionary = {RESEARCH_COST_MATERIAL_ID: "", RESEARCH_COST_AMOUNT: 0}
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)
	if definition.is_empty():
		return empty
	# MasterDataLoader は JSON をそのまま返すため cost_amount は float で来る。int() 必須。
	return {
		RESEARCH_COST_MATERIAL_ID: str(definition.get(RESEARCH_NODE_COST_MATERIAL_ID, "")),
		RESEARCH_COST_AMOUNT: int(definition.get(RESEARCH_NODE_COST_AMOUNT, 0)),
	}

# 前提条件を満たしているか（素材は見ない）。
# 画面が「前提未解放」と「素材不足」を区別して表示するために分けてある。
func can_unlock_research_node(node_id: String) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	if not tree.has(node_id) or not (tree[node_id] is Dictionary):
		return false
	var node: Dictionary = tree[node_id]
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		return false
	return _prerequisites_met(node)

# 研究ノードを解放する。存在しない・解放済み・前提未達・素材不足のときは
# 何もせず false を返す。成功時は素材を消費して research_node_unlocked を発火する。
func unlock_research_node(node_id: String) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	if not tree.has(node_id) or not (tree[node_id] is Dictionary):
		push_warning("[GameManager] unlock_research_node: unknown node_id: " + node_id)
		return false

	var node: Dictionary = tree[node_id]
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		print("[GameManager] unlock_research_node('%s') -> false (already unlocked)" % node_id)
		return false

	# 前提の判定を素材の判定より先に行う。順序を入れ替えると、
	# 前提未解放のノードで「素材不足」と表示されて画面の説明と食い違う。
	if not _prerequisites_met(node):
		print("[GameManager] unlock_research_node('%s') -> false (prerequisites not met: %s)" % [
			node_id, node.get(GameStateKeys.NODE_PREREQUISITES, [])
		])
		return false

	var cost: Dictionary = get_research_unlock_cost(node_id)
	var material_id: String = str(cost.get(RESEARCH_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(RESEARCH_COST_AMOUNT, 0))
	if amount > 0 and material_id == "":
		push_warning("[GameManager] unlock_research_node: cost_material_id が未設定（research.json）: " + node_id)
		return false

	# add_material() は残高を確認しないため、減算する前に必ずここで確認する。
	if amount > 0:
		var owned: int = get_material_count(material_id)
		if owned < amount:
			print("[GameManager] unlock_research_node('%s') -> false (material %s: %d < %d)" % [
				node_id, material_id, owned, amount
			])
			return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# _copy_dict() は浅いコピーのため、ノードのDictionaryをもう一段複製してから書き換える。
	# これを飛ばすと _state 内の実体を直接書き換えることになる。
	var new_tree: Dictionary = _copy_dict(GameStateKeys.RESEARCH_TREE)
	var new_node: Dictionary = (new_tree[node_id] as Dictionary).duplicate(true)
	new_node[GameStateKeys.NODE_UNLOCKED] = true
	new_tree[node_id] = new_node
	_state[GameStateKeys.RESEARCH_TREE] = new_tree

	# 素材の減算はツリーを更新したあとに行う。
	# material_changed を受けて再描画する画面が、解放済みの状態を見られるようにするため。
	if amount > 0:
		add_material(material_id, -amount)

	print("[GameManager] unlock_research_node('%s') -> true (cost %s x%d, effect %s +%d)" % [
		node_id, material_id, amount,
		str(new_node.get(GameStateKeys.NODE_EFFECT_TYPE, "")),
		int(new_node.get(GameStateKeys.NODE_EFFECT_VALUE, 0)),
	])
	research_node_unlocked.emit(node_id)
	return true

# --- 研究：内部ヘルパー ---

# prerequisites に並ぶノードが全て unlocked か。空配列なら true。
func _prerequisites_met(node: Dictionary) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var prerequisites: Variant = node.get(GameStateKeys.NODE_PREREQUISITES, [])
	if not (prerequisites is Array):
		return true
	for prerequisite_id: Variant in (prerequisites as Array):
		var required: Variant = tree.get(str(prerequisite_id), null)
		if not (required is Dictionary):
			# research.json に存在しないIDが前提に書かれている。
			# 解放できてしまうより、解放できないほうが安全。
			push_warning("[GameManager] _prerequisites_met: unknown prerequisite: " + str(prerequisite_id))
			return false
		if not bool((required as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			return false
	return true

# research.json の定義を research_tree へ流し込む。
#
# unlocked だけは既存の値を残し、それ以外（effect_type / effect_value /
# target_stat / prerequisites）は毎回マスターデータで上書きする。
# これにより research.json の効果値を調整すると、既存セーブにも次の起動で反映される。
# （initial_state_config.tres がセーブ済みだと反映されない罠を、研究では踏まない形にする）
#
# research.json から消えたノードは research_tree からも消える。
# ノードIDを改名するとその解放状態は失われるため、リリース後は改名しないこと。
func _sync_research_tree_from_master() -> void:
	var master: Dictionary = MasterDataLoader.get_all_research_nodes()
	if master.is_empty():
		push_warning("[GameManager] _sync_research_tree_from_master: research.json が空か読み込めない")
		return

	var current: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var synced: Dictionary = {}
	for node_id: String in master:
		if not (master[node_id] is Dictionary):
			continue
		var definition: Dictionary = master[node_id]

		var was_unlocked: bool = false
		if current.has(node_id) and current[node_id] is Dictionary:
			was_unlocked = bool((current[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false))

		# JSON の配列要素は Variant で来るため str() で包み直す。
		var prerequisites: Array = []
		var raw_prerequisites: Variant = definition.get(GameStateKeys.NODE_PREREQUISITES, [])
		if raw_prerequisites is Array:
			for prerequisite_id: Variant in (raw_prerequisites as Array):
				prerequisites.append(str(prerequisite_id))

		# effect_value は必ず int() で包む。包み忘れるとセーブに 5.0 と書かれ、
		# get_effective_level_cap() の戻り値が 15.0 になる。
		synced[node_id] = {
			GameStateKeys.NODE_UNLOCKED: was_unlocked,
			GameStateKeys.NODE_EFFECT_TYPE: str(definition.get(GameStateKeys.NODE_EFFECT_TYPE, "")),
			GameStateKeys.NODE_EFFECT_VALUE: int(definition.get(GameStateKeys.NODE_EFFECT_VALUE, 0)),
			GameStateKeys.NODE_TARGET_STAT: str(definition.get(GameStateKeys.NODE_TARGET_STAT, STAT_BOOST_ALL_KEY)),
			GameStateKeys.NODE_PREREQUISITES: prerequisites,
		}

	_state[GameStateKeys.RESEARCH_TREE] = synced

	var unlocked_count: int = 0
	for node_id: String in synced:
		if bool((synced[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			unlocked_count += 1
	print("[GameManager] _sync_research_tree_from_master() -> %d nodes (unlocked=%d)" % [synced.size(), unlocked_count])

func get_effective_level_cap(_character_id: String) -> int:
	# 保存された値ではなく、research_treeを都度走査して計算する。
	#
	# 研究ツリーは未実装で常に空のため、走査結果だけだと 0 が返り、
	# レベル1のキャラが即座に上限扱いになって育成画面が操作不能になる。
	# base_level_cap を下駄として先に置く（EXEC_GUILD_TRAINING §5-3）。
	# 研究が入っても、解放ノードの effect_value が加算されるだけで呼び出し側は変わらない。
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var cap: int = 0
	if Balance != null and Balance.character != null:
		cap = int(Balance.character.base_level_cap)
	else:
		push_warning("[GameManager] get_effective_level_cap: Balance.character is null — base_level_cap を 0 として扱う")
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)) and str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) == GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			cap += int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return cap

func get_stat_boost_all() -> Dictionary:
	# 保存された値ではなく、research_treeを都度走査して計算する。
	# 返り値の形は { "hp": 10, "atk": 5, ... }。target_stat未指定のノードは "all" に集約する。
	# TODO: 実際にどのステータスへどう加算するかは PLAN_GUILD_RESEARCH.md 側で未確定。
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var boosts: Dictionary = {}
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)) and str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) == GameStateKeys.EFFECT_STAT_BOOST_ALL:
			var stat: String = str(node.get(GameStateKeys.NODE_TARGET_STAT, "all"))
			boosts[stat] = int(boosts.get(stat, 0)) + int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return boosts

# --- 作業場 ---

func get_crafting_queue() -> Array:
	return _state.get(GameStateKeys.CRAFTING_QUEUE, []).duplicate(true)

func start_craft(recipe_id: String) -> bool:
	# レシピ未解放・素材不足なら何もせずfalse（空実装）
	print("[GameManager] start_craft('%s') -> false (dummy: recipe not unlocked)" % recipe_id)
	return false

func collect_craft(queue_id: String) -> bool:
	# 完了前なら何もせずfalse。完了後は成功しinventoryへ反映（空実装：常にfalse）
	print("[GameManager] collect_craft('%s') -> false (dummy: not completed)" % queue_id)
	return false

# --- セーブ・ロード ---

# セーブデータから状態を復元する。
# SaveManagerからのみ呼ばれることを想定。
func load_state(data: Dictionary) -> bool:
	if data == null or not (data is Dictionary):
		return false
	
	if not data.has(GameStateKeys.SAVE_VERSION):
		push_warning("[GameManager] load_state: missing save_version")
		return false
	
	# テンプレで初期化してから上書き（将来のキー追加対策）
	var new_state: Dictionary = _empty_state_template()
	for key: String in data:
		if new_state.has(key):
			new_state[key] = data[key]
	
	# 数値の int() キャスト（JSON復元時は float になるため）
	# §6-2 の決定事項に従い、対象を限定する。
	if new_state.has(GameStateKeys.GOLD):
		new_state[GameStateKeys.GOLD] = int(new_state[GameStateKeys.GOLD])
	if new_state.has(GameStateKeys.GEMS):
		new_state[GameStateKeys.GEMS] = int(new_state[GameStateKeys.GEMS])
	if new_state.has(GameStateKeys.STAMINA) and new_state[GameStateKeys.STAMINA] is Dictionary:
		var stamina: Dictionary = new_state[GameStateKeys.STAMINA]
		if stamina.has(GameStateKeys.STAMINA_CURRENT):
			stamina[GameStateKeys.STAMINA_CURRENT] = int(stamina[GameStateKeys.STAMINA_CURRENT])
		if stamina.has(GameStateKeys.STAMINA_MAX):
			stamina[GameStateKeys.STAMINA_MAX] = int(stamina[GameStateKeys.STAMINA_MAX])
	if new_state.has(GameStateKeys.TOTAL_POMODORO_COMPLETED):
		new_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(new_state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	if new_state.has(GameStateKeys.SCENARIO_CHAPTER):
		new_state[GameStateKeys.SCENARIO_CHAPTER] = int(new_state[GameStateKeys.SCENARIO_CHAPTER])
	if new_state.has(GameStateKeys.SAVE_VERSION):
		new_state[GameStateKeys.SAVE_VERSION] = int(new_state[GameStateKeys.SAVE_VERSION])
	if new_state.has(GameStateKeys.MATERIALS) and new_state[GameStateKeys.MATERIALS] is Dictionary:
		var mats: Dictionary = new_state[GameStateKeys.MATERIALS]
		for mat_id: String in mats:
			mats[mat_id] = int(mats[mat_id])
	# 育成データ。JSONから戻すと level も stats も float になるため int に戻す。
	# これを飛ばすと、セーブ→ロード後に hp が 128.0 と表示され、レベル比較もずれる。
	if new_state.has(GameStateKeys.CHARACTER_GROWTH) and new_state[GameStateKeys.CHARACTER_GROWTH] is Dictionary:
		var growth_all: Dictionary = new_state[GameStateKeys.CHARACTER_GROWTH]
		for character_id: String in growth_all:
			if not (growth_all[character_id] is Dictionary):
				continue
			var entry: Dictionary = growth_all[character_id]
			if entry.has(GameStateKeys.GROWTH_LEVEL):
				entry[GameStateKeys.GROWTH_LEVEL] = int(entry[GameStateKeys.GROWTH_LEVEL])
			if entry.has(GameStateKeys.GROWTH_STATS) and entry[GameStateKeys.GROWTH_STATS] is Dictionary:
				var entry_stats: Dictionary = entry[GameStateKeys.GROWTH_STATS]
				for stat_key: String in _stat_keys():
					if entry_stats.has(stat_key):
						entry_stats[stat_key] = int(entry_stats[stat_key])
	
	# 状態反映（外部参照を断つため duplicate）
	_state = new_state.duplicate(true)
	# セーブから戻した research_tree を research.json と同期する。
	# unlocked は残り、効果値・前提条件はマスターデータで上書きされる。
	# JSON復元で float になった effect_value も、ここで int() に戻る。
	_sync_research_tree_from_master()
	print("[GameManager] load_state success. version=%d" % int(_state[GameStateKeys.SAVE_VERSION]))
	
	# 主要なシグナルを発火（再描画用）
	resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])
	resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])
	var stamina_dict: Dictionary = _state[GameStateKeys.STAMINA]
	resource_changed.emit(GameStateKeys.STAMINA, int(stamina_dict.get(GameStateKeys.STAMINA_CURRENT, 0)))
	
	var materials: Dictionary = _state[GameStateKeys.MATERIALS]
	for mat_id: String in materials:
		material_changed.emit(mat_id, int(materials[mat_id]))
	
	pending_chests_changed.emit(get_pending_chest_count())
	
	return true

# 保存直前に呼ばれ、last_saved_atを更新する
func mark_saved() -> void:
	_state[GameStateKeys.LAST_SAVED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] mark_saved -> last_saved_at=%s" % _state[GameStateKeys.LAST_SAVED_AT])

func grant_stamina_potions(focus_minutes: int) -> int:
	var unit_per_min: int = int(Balance.pomodoro.potion_focus_minutes_per_unit)
	if unit_per_min <= 0:
		push_warning("[GameManager] invalid potion rate")
		return 0
	var remainder: int = int(_state.get(GameStateKeys.POTION_FOCUS_REMAINDER, 0))
	var total_min: int = focus_minutes + remainder
	var count: int = total_min / unit_per_min
	_state[GameStateKeys.POTION_FOCUS_REMAINDER] = total_min % unit_per_min
	if count > 0:
		add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, count, GameStateKeys.ITEM_TYPE_CONSUMABLE)
	return count

func get_stamina_potion_count() -> int:
	var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
	if not inventory.has(GameStateKeys.ITEM_STAMINA_POTION):
		return 0
	var entry: Dictionary = inventory[GameStateKeys.ITEM_STAMINA_POTION]
	return int(entry.get(GameStateKeys.ITEM_COUNT, 0))

func use_stamina_potion() -> bool:
	var count: int = get_stamina_potion_count()
	if count <= 0:
		return false
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	var entry: Dictionary = (inventory[GameStateKeys.ITEM_STAMINA_POTION] as Dictionary).duplicate(true)
	if count == 1:
		inventory.erase(GameStateKeys.ITEM_STAMINA_POTION)
	else:
		entry[GameStateKeys.ITEM_COUNT] = count - 1
		inventory[GameStateKeys.ITEM_STAMINA_POTION] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	inventory_changed.emit(GameStateKeys.ITEM_STAMINA_POTION)
	_add_stamina_uncapped(int(Balance.pomodoro.stamina_potion_recovery))
	return true

# --- ストーリーステージ ---

# 戦闘勝利時にステージのクリア状態を記録する。
# stars は判定基準が未確定のため、当面は常に 0 が渡される。
# 既存の stars より小さい値で上書きしないよう maxi で比較する。
func mark_stage_cleared(stage_id: String, stars: int = 0) -> void:
	var story: Dictionary = _copy_dict(GameStateKeys.STORY)
	var stages: Dictionary = (story.get(GameStateKeys.STORY_STAGES, {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (stages.get(stage_id, {}) as Dictionary).duplicate(true)
	entry[GameStateKeys.STAGE_CLEARED] = true
	entry[GameStateKeys.STAGE_STARS] = maxi(int(entry.get(GameStateKeys.STAGE_STARS, 0)), stars)
	stages[stage_id] = entry
	story[GameStateKeys.STORY_STAGES] = stages
	_state[GameStateKeys.STORY] = story
	print("[GameManager] mark_stage_cleared('%s', %d)" % [stage_id, stars])

func is_stage_cleared(stage_id: String) -> bool:
	var story: Dictionary = _state.get(GameStateKeys.STORY, {})
	var stages: Dictionary = story.get(GameStateKeys.STORY_STAGES, {})
	var entry: Dictionary = stages.get(stage_id, {})
	return bool(entry.get(GameStateKeys.STAGE_CLEARED, false))


# --- 上限を超えられるスタミナ加算 ---

# max で切り捨てずにスタミナを増やす。
#
# 通常の add_stamina() は max で切り捨てる。上限の意味は
# 「放っておいても max までしか溜まらない」ことであり、
# 自然回復・宝箱・ポモドーロ報酬はすべてそちらを通す。
#
# 上限を超えてよいのは「プレイヤーが能動的に使ったぶん」だけ。
# 現状はスタミナポーションと、戦闘敗北時の返却の2つ。
func _add_stamina_uncapped(amount: int) -> int:
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)) + amount
	stamina[GameStateKeys.STAMINA_CURRENT] = current
	_state[GameStateKeys.STAMINA] = stamina
	resource_changed.emit(GameStateKeys.STAMINA, current)
	return current

# 戦闘に敗北したときのスタミナ返却。
# ポーションで上限を超えている状態から払った場合、add_stamina() では
# max で切り捨てられて戻らないため、上限を超えられる経路を使う。
func refund_stamina(amount: int) -> void:
	if amount <= 0:
		return
	var current: int = _add_stamina_uncapped(amount)
	print("[GameManager] refund_stamina(%d) -> current=%d" % [amount, current])
