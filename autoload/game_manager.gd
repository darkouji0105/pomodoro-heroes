extends Node

# GameManager: 全画面のSingle Source of Truth。
# 拠点共通データ＋育成・図鑑・ショップ・研究ツリー・製作キュー等の永続データを保持・更新する。
# 他のAutoloadやシーンは直接データを書き換えず、必ず下記関数を経由すること。

var _state: Dictionary = {}

signal resource_changed(resource_type: String, new_value: Variant)
signal screen_unlocked(screen_id: String)
signal inventory_changed(item_id: String)
signal pending_chests_changed(pending_count: int)

func _ready() -> void:
	print("[GameManager] _ready() — initializing from Balance.initial_state")
	if Balance != null and Balance.initial_state != null:
		_init_from_config(Balance.initial_state)
	else:
		push_warning("[GameManager] Balance.initial_state is null — using empty defaults")
		_init_empty()
	print("[GameManager] init complete. gold=%d stamina=%s unlocked_screens=%s" % [
		int(_state.get(GameStateKeys.GOLD, 0)),
		_state.get(GameStateKeys.STAMINA, {}),
		_state.get(GameStateKeys.UNLOCKED_SCREENS, {}),
	])

# --- 初期化 ---

func _init_from_config(config: InitialStateConfig) -> void:
	var unlocked: Dictionary = {}
	for screen_id: String in config.initially_unlocked_screens:
		unlocked[screen_id] = true
	_state = {
		GameStateKeys.GOLD: config.starting_gold,
		GameStateKeys.GEMS: config.starting_gems,
		GameStateKeys.STAMINA: {"current": config.starting_stamina_current, "max": config.starting_stamina_max},
		GameStateKeys.MATERIALS: config.starting_materials.duplicate(true),
		GameStateKeys.INVENTORY: {},
		GameStateKeys.PENDING_CHESTS: [],
		GameStateKeys.UNLOCKED_SCREENS: unlocked,
		GameStateKeys.SCENARIO_CHAPTER: config.starting_scenario_chapter,
		GameStateKeys.BOSS_UNLOCKED: false,
		GameStateKeys.PITY_COUNTERS: {},
		GameStateKeys.TOTAL_POMODORO_COMPLETED: 0,
		GameStateKeys.LAST_POMODORO_END_AT: "",
		GameStateKeys.SAVE_VERSION: config.save_version,
		GameStateKeys.LAST_SAVED_AT: "",
		GameStateKeys.STORY: {"current_chapter": config.starting_scenario_chapter, "stages": {}},
		GameStateKeys.TRAINING_MODE_UNLOCKED: false,
		GameStateKeys.CODEX: {},
		GameStateKeys.DAILY_SHOP: {"refresh_at": "", "line_up": []},
		GameStateKeys.WEEKLY_SHOP: {"refresh_at": "", "line_up": []},
		GameStateKeys.MONTHLY_SHOP: {"refresh_at": "", "line_up": []},
		GameStateKeys.CHARACTER_GROWTH: {},
		GameStateKeys.RESEARCH_TREE: {},
		GameStateKeys.RECIPES_UNLOCKED: {},
		GameStateKeys.CRAFTING_QUEUE: [],
	}

func _init_empty() -> void:
	_state = {
		GameStateKeys.GOLD: 0,
		GameStateKeys.GEMS: 0,
		GameStateKeys.STAMINA: {"current": 0, "max": 0},
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
		GameStateKeys.STORY: {"current_chapter": 1, "stages": {}},
		GameStateKeys.TRAINING_MODE_UNLOCKED: false,
		GameStateKeys.CODEX: {},
		GameStateKeys.DAILY_SHOP: {"refresh_at": "", "line_up": []},
		GameStateKeys.WEEKLY_SHOP: {"refresh_at": "", "line_up": []},
		GameStateKeys.MONTHLY_SHOP: {"refresh_at": "", "line_up": []},
		GameStateKeys.CHARACTER_GROWTH: {},
		GameStateKeys.RESEARCH_TREE: {},
		GameStateKeys.RECIPES_UNLOCKED: {},
		GameStateKeys.CRAFTING_QUEUE: [],
	}

# --- 基本リソース ---

func get_state() -> Dictionary:
	# 内部Dictionaryそのものではなく、duplicate(true)した読み取り専用スナップショットを返す。
	# 呼び出し側からの直接書き換えを防ぐため（AGENTS.md「状態アクセスのルール」準拠）。
	return _state.duplicate(true)

func add_gold(amount: int) -> void:
	_state[GameStateKeys.GOLD] = int(_state.get(GameStateKeys.GOLD, 0)) + amount
	print("[GameManager] add_gold(%d) -> %d" % [amount, _state[GameStateKeys.GOLD]])
	resource_changed.emit("gold", _state[GameStateKeys.GOLD])

func add_stamina(amount: int) -> void:
	var stamina: Dictionary = _state.get(GameStateKeys.STAMINA, {"current": 0, "max": 0})
	stamina["current"] = int(stamina.get("current", 0)) + amount
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] add_stamina(%d) -> current=%d" % [amount, stamina["current"]])
	resource_changed.emit("stamina", stamina["current"])

func spend_stamina(amount: int) -> bool:
	# 足りなければ何もせずfalseを返す
	var stamina: Dictionary = _state.get(GameStateKeys.STAMINA, {"current": 0, "max": 0})
	var current: int = int(stamina.get("current", 0))
	if current < amount:
		print("[GameManager] spend_stamina(%d) -> false (have %d)" % [amount, current])
		return false
	stamina["current"] = current - amount
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] spend_stamina(%d) -> true (current=%d)" % [amount, stamina["current"]])
	resource_changed.emit("stamina", stamina["current"])
	return true

func add_material(material_id: String, amount: int) -> void:
	var materials: Dictionary = _state.get(GameStateKeys.MATERIALS, {})
	materials[material_id] = int(materials.get(material_id, 0)) + amount
	_state[GameStateKeys.MATERIALS] = materials
	print("[GameManager] add_material('%s', %d) -> %d" % [material_id, amount, materials[material_id]])
	resource_changed.emit("materials", materials)

func add_to_inventory(item_id: String, count: int) -> void:
	# 初出のitem_idであれば、図鑑（codex）のdiscoveredも自動でtrueにする
	var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
	var entry: Dictionary = inventory.get(item_id, {})
	entry["count"] = int(entry.get("count", 0)) + count
	if not entry.has("type"):
		entry["type"] = "equipment"
	if not entry.has("slot_position"):
		entry["slot_position"] = {"x": 0, "y": 0}
	if not entry.has("properties"):
		entry["properties"] = {}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	var codex: Dictionary = _state.get(GameStateKeys.CODEX, {})
	if not codex.has(item_id):
		codex[item_id] = {"discovered": true, "obtained_at": ""}
		_state[GameStateKeys.CODEX] = codex
	print("[GameManager] add_to_inventory('%s', %d) -> count=%d codex_discovered=%s" % [item_id, count, entry["count"], codex.has(item_id)])
	inventory_changed.emit(item_id)

# --- 画面アンロック ---

func unlock_screen(screen_id: String) -> void:
	var unlocked: Dictionary = _state.get(GameStateKeys.UNLOCKED_SCREENS, {})
	unlocked[screen_id] = true
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked
	print("[GameManager] unlock_screen('%s')" % screen_id)
	screen_unlocked.emit(screen_id)

func is_screen_unlocked(screen_id: String) -> bool:
	var unlocked: Dictionary = _state.get(GameStateKeys.UNLOCKED_SCREENS, {})
	return bool(unlocked.get(screen_id, false))

# --- 宝箱 ---

func add_pending_chest(chest_data: Dictionary) -> void:
	var chests: Array = _state.get(GameStateKeys.PENDING_CHESTS, [])
	chests.append(chest_data.duplicate(true))
	_state[GameStateKeys.PENDING_CHESTS] = chests
	print("[GameManager] add_pending_chest() -> pending_count=%d" % get_pending_chest_count())
	pending_chests_changed.emit(get_pending_chest_count())

func open_chest(chest_id: String) -> bool:
	# 存在しなければ何もせずfalse。存在すればopened=trueにしてrewardsを反映
	var chests: Array = _state.get(GameStateKeys.PENDING_CHESTS, [])
	for i: int in range(chests.size()):
		var chest: Dictionary = chests[i]
		if str(chest.get("chest_id", "")) == chest_id:
			if bool(chest.get("opened", false)):
				print("[GameManager] open_chest('%s') -> false (already opened)" % chest_id)
				return false
			chest["opened"] = true
			chests[i] = chest
			_state[GameStateKeys.PENDING_CHESTS] = chests
			# rewards を反映（既存の add_* 関数を使い回し、重複実装を避ける）
			var rewards: Dictionary = chest.get("rewards", {})
			if rewards.has("gold"):
				add_gold(int(rewards["gold"]))
			if rewards.has("gems"):
				_state[GameStateKeys.GEMS] = int(_state.get(GameStateKeys.GEMS, 0)) + int(rewards["gems"])
				resource_changed.emit("gems", _state[GameStateKeys.GEMS])
			if rewards.has("materials") and rewards["materials"] is Dictionary:
				var mats: Dictionary = rewards["materials"]
				for mat_id: String in mats:
					add_material(mat_id, int(mats[mat_id]))
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
		if not bool(chest.get("opened", false)):
			count += 1
	return count

# --- ポモドーロ報酬 ---

func apply_pomodoro_rewards(reward_data: Dictionary) -> void:
	# gold/stamina/materialsの反映、total_pomodoro_completedの加算、
	# last_pomodoro_end_atの更新、SignalBus.pomodoro_session_completedの発火までを一括で行う
	print("[GameManager] apply_pomodoro_rewards(%s)" % reward_data)
	if reward_data.has("gold"):
		add_gold(int(reward_data["gold"]))
	if reward_data.has("stamina"):
		add_stamina(int(reward_data["stamina"]))
	if reward_data.has("materials") and reward_data["materials"] is Dictionary:
		var mats: Dictionary = reward_data["materials"]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# total_pomodoro_completed +1
	_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(_state.get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0)) + 1
	# last_pomodoro_end_at 更新
	_state[GameStateKeys.LAST_POMODORO_END_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] total_pomodoro_completed -> %d" % _state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	# 発火元をGameManagerに一本化（呼び出し元のポモドーロ画面側では発火させない・二重発火防止）
	SignalBus.pomodoro_session_completed.emit(reward_data)

# --- 戦闘報酬 ---

func apply_battle_rewards(result_data: Dictionary) -> void:
	# gold/materialsの反映、SignalBus.battle_finishedの発火までを一括で行う
	# ※ expは扱わない（レベル上げは専用素材消費型。DATA_SCHEMA.md 4-3準拠）
	print("[GameManager] apply_battle_rewards(%s)" % result_data)
	var rewards: Dictionary = result_data.get("rewards", {})
	if rewards.has("gold"):
		add_gold(int(rewards["gold"]))
	if rewards.has("materials") and rewards["materials"] is Dictionary:
		var mats: Dictionary = rewards["materials"]
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
	var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
	if inventory.has(item_id):
		var entry: Dictionary = inventory[item_id]
		entry["slot_position"] = {"x": position.x, "y": position.y}
		inventory[item_id] = entry
		_state[GameStateKeys.INVENTORY] = inventory
		print("[GameManager] update_inventory_slot_position('%s', %s)" % [item_id, position])
	else:
		print("[GameManager] update_inventory_slot_position('%s') -> item not in inventory" % item_id)

# --- ショップ ---

func get_shop_lineup(shop_type: String) -> Array:
	var key: String = ""
	match shop_type:
		"daily":
			key = GameStateKeys.DAILY_SHOP
		"weekly":
			key = GameStateKeys.WEEKLY_SHOP
		"monthly":
			key = GameStateKeys.MONTHLY_SHOP
		_:
			print("[GameManager] get_shop_lineup('%s') -> unknown shop_type" % shop_type)
			return []
	var shop: Dictionary = _state.get(key, {})
	return shop.get("line_up", []).duplicate(true)

func purchase_shop_item(shop_type: String, slot_id: int) -> bool:
	# 残高不足・売り切れなら何もせずfalse（空実装：ラインナップが空のため常にfalse）
	print("[GameManager] purchase_shop_item('%s', %d) -> false (dummy: lineup empty)" % [shop_type, slot_id])
	return false

func refresh_shop_if_needed(shop_type: String) -> void:
	print("[GameManager] refresh_shop_if_needed('%s') (dummy)" % shop_type)

# --- 育成 ---

func get_character_growth(character_id: String) -> Dictionary:
	var growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	var entry: Dictionary = growth.get(character_id, {})
	return entry.duplicate(true)

func level_up_character(character_id: String) -> bool:
	# 素材不足なら何もせずfalse（空実装）
	print("[GameManager] level_up_character('%s') -> false (dummy: insufficient materials)" % character_id)
	return false

func equip_item(character_id: String, slot: String, item_id: String) -> void:
	print("[GameManager] equip_item('%s', '%s', '%s') (dummy)" % [character_id, slot, item_id])

func unequip_item(character_id: String, slot: String) -> void:
	print("[GameManager] unequip_item('%s', '%s') (dummy)" % [character_id, slot])

func select_skill(character_id: String, slot_id: int, skill_id: String) -> void:
	print("[GameManager] select_skill('%s', %d, '%s') (dummy)" % [character_id, slot_id, skill_id])

# --- 研究 ---

func get_research_tree() -> Dictionary:
	return _state.get(GameStateKeys.RESEARCH_TREE, {}).duplicate(true)

func unlock_research_node(node_id: String) -> bool:
	# 前提未解放・素材不足なら何もせずfalse（空実装）
	print("[GameManager] unlock_research_node('%s') -> false (dummy: prerequisites not met)" % node_id)
	return false

func get_effective_level_cap(character_id: String) -> int:
	# 保存された値ではなく、research_treeを都度走査して計算する
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var cap: int = 0
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get("unlocked", false)) and str(node.get("effect_type", "")) == "level_cap_unlock":
			cap += int(node.get("effect_value", 0))
	return cap

func get_stat_boost_all() -> Dictionary:
	# 保存された値ではなく、research_treeを都度走査して計算する
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var boosts: Dictionary = {}
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get("unlocked", false)) and str(node.get("effect_type", "")) == "stat_boost_all":
			# effect_value を集約する想定だが、詳細ロジックは各ギルドEXECで確定するため現状は空
			pass
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
