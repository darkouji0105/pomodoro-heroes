extends Node2D

# BattleController
# battle.tscn に張り付くコントローラ。
# 戦闘ループ・ウェーブ進行・勝敗確定・結果表示を一元管理する。
# PRE_PLAN §7 の人間による決定事項を最優先で反映。

# 画面中央 y 位置
const GROUND_Y: float = 360.0
# 味方の初期 X 位置
const PARTY_BASE_X: float = 200.0
const PARTY_STEP_X: float = 100.0
# 敵の初期 X 位置
const ENEMY_BASE_X: float = 900.0
const ENEMY_STEP_X: float = 100.0

const UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/adventure/unit_view.tscn")
const DEBUG_PANEL_SCRIPT: GDScript = preload("res://scenes/adventure/battle_debug_panel.gd")

# ノード参照
@onready var party_container: Node2D = $PartyUnitsContainer
@onready var enemy_container: Node2D = $EnemyUnitsContainer
@onready var wave_label: Label = $HUD/WaveLabel
@onready var result_view: Control = $ResultView
@onready var result_label: Label = $ResultView/ResultLabel
@onready var reward_label: Label = $ResultView/RewardLabel
@onready var retry_button: Button = $ResultView/RetryButton
@onready var back_button: Button = $ResultView/BackButton

# データ
var _stage_id: String = "stage_1"
var _stage_data: Dictionary = {}
var _session: BattleSession = null

# PRE_PLAN §7-4: 敵 UnitView の参照配列。ウェーブ切替時に queue_free して clear する。
var _enemy_views: Array = []

# 味方の UnitView は wave 間で破棄しない（連戦のため）。
# ただし「もう一度」リトライ時は作り直すので、party_views も同じ仕組みを持つ。
var _party_views: Array = []

# unit_id -> UnitView。ダメージ数値の表示先を引くために持つ。
var _views_by_unit_id: Dictionary = {}

# 報酬二重適用防止フラグ（EXEC §7-1）
var _result_applied: bool = false

var _debug_panel: CanvasLayer = null


func _ready() -> void:
	# 起動時に SceneManager から transfer_data を 1 回だけ取り出す。
	# 2 回呼ぶと 2 回目は空 dict になる（EXEC §6-1）。
	var data: Dictionary = SceneManager.consume_transfer_data()

	_stage_id = str(data.get(TransferKeys.STAGE_ID, ""))
	if _stage_id == "":
		push_warning("[Battle] stage_id が渡されていないため stage_1 で開始する")
		_stage_id = "stage_1"

	# PRE_PLAN §7-2: stage_type は TransferKeys.STAGE_TYPE 優先、無ければ STAGE_TYPE_STORY。
	# push_warning は不要（stage_id 側で既に出る）。
	var stage_type: String = str(data.get(TransferKeys.STAGE_TYPE, ""))
	if stage_type == "":
		stage_type = GameStateKeys.STAGE_TYPE_STORY

	_stage_data = MasterDataLoader.get_stage(_stage_id)
	if _stage_data.is_empty():
		push_error("[Battle] stage_data が空: " + _stage_id)
		return

	# party_id は stage_data から取る（EXEC §6-1）
	var party_id: String = str(_stage_data.get("party_id", ""))
	var waves_array: Array = _stage_data.get("waves", [])
	var total_waves: int = waves_array.size()

	# PRE_PLAN §7-1: BattleSession._init は 4 引数。party_units / enemy_units は _init では空のまま。
	_session = BattleSession.new(_stage_id, stage_type, party_id, total_waves)

	_init_party_units()
	result_view.hide()
	retry_button.pressed.connect(_on_retry_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_setup_debug_panel()
	_enter_wave_intro()


# デバッグ実行時のみパネルを生成する。リリースビルドには出ない。
func _setup_debug_panel() -> void:
	if not OS.is_debug_build():
		return
	_debug_panel = CanvasLayer.new()
	_debug_panel.set_script(DEBUG_PANEL_SCRIPT)
	add_child(_debug_panel)
	_debug_panel.setup(self)


# Engine.time_scale は Autoload と同じくグローバル。
# 戻さずに画面を離れると拠点もポモドーロも 8 倍速のままになる。
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func get_session() -> BattleSession:
	return _session


# 味方の BattleUnit と UnitView を生成する。
# ウェーブをまたいで再生成しないが、リトライ時は _init_party_units を呼び直す。
func _init_party_units() -> void:
	# 既存があれば破棄（リトライ対応）
	for v in _party_views:
		if v is Node and is_instance_valid(v):
			v.queue_free()
	_party_views.clear()
	for v in party_container.get_children():
		v.queue_free()

	var party_data: Dictionary = MasterDataLoader.get_party(_session.party_id)
	if party_data.is_empty():
		push_error("[Battle] party_data が空: " + _session.party_id)
		return
	var members: Array = party_data.get("members", [])

	for i: int in range(members.size()):
		var character_id: String = str(members[i])
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		if char_data.is_empty():
			push_error("[Battle] character not found: " + character_id)
			continue

		# 育成データがあれば優先（EXEC §6-2 優先順）
		var growth: Dictionary = GameManager.get_character_growth(character_id)
		var has_growth: bool = not growth.is_empty() and growth.has(GameStateKeys.GROWTH_STATS) and (growth[GameStateKeys.GROWTH_STATS] is Dictionary) and not (growth[GameStateKeys.GROWTH_STATS] as Dictionary).is_empty()
		var stats: Dictionary = growth.get(GameStateKeys.GROWTH_STATS, {}) if has_growth else {}

		var hp: int = int(stats.get(GameStateKeys.STAT_HP, char_data.get("hp", 0)))
		var atk: int = int(stats.get(GameStateKeys.STAT_ATK, char_data.get("atk", 0)))
		var def: int = int(stats.get(GameStateKeys.STAT_DEF, char_data.get("def", 0)))
		var spd: int = int(stats.get(GameStateKeys.STAT_SPD, char_data.get("spd", 0)))

		var unit: BattleUnit = BattleUnit.new(
			"party_%d" % i,
			BattleUnit.TEAM_PARTY,
			str(char_data.get("name_key", "")),
			hp,
			atk,
			def,
			float(char_data.get("attack_range", 0)),
			float(char_data.get("attack_interval_sec", 0)),
			float(spd),
			false
		)
		unit.x = _party_start_x(i)
		_session.party_units.append(unit)

		var view: Node = UNIT_VIEW_SCENE.instantiate()
		view.position = Vector2(unit.x, GROUND_Y)
		party_container.add_child(view)
		view.setup(unit)
		_party_views.append(view)
		_views_by_unit_id[unit.unit_id] = view


func _party_start_x(index: int) -> float:
	return PARTY_BASE_X + index * PARTY_STEP_X


# ウェーブが切り替わるときに味方を左端の初期位置へ戻す。
#
# 戻すのは位置・ターゲット・攻撃タイマーだけ。
# HP は絶対に戻さないこと。戻すと連戦でなくなり、完了条件8が意味を失う。
# 死亡した味方は復活させず、位置も動かさない。
func _reset_party_positions() -> void:
	for i: int in range(_session.party_units.size()):
		var unit: BattleUnit = _session.party_units[i]
		if unit == null or not unit.is_alive():
			continue
		unit.x = _party_start_x(i)
		unit.target_unit_id = ""
		unit.attack_timer = 0.0


# 現在ウェーブの敵を生成する。
# PRE_PLAN §7-4: ウェーブ切替時に古い UnitView を queue_free する。
func _spawn_current_wave_enemies() -> void:
	# 古い敵 UnitView をすべて破棄（PRE_PLAN §7-4）
	for v in _enemy_views:
		if v is Node and is_instance_valid(v):
			v.queue_free()
	_enemy_views.clear()
	# コンテナ側の子も念のため（_enemy_views と二重に持つため）
	for v in enemy_container.get_children():
		v.queue_free()
	for u in _session.enemy_units:
		if u is BattleUnit:
			_views_by_unit_id.erase(u.unit_id)
	_session.enemy_units.clear()

	var waves_array: Array = _stage_data.get("waves", [])
	# current_wave は 1 始まり
	var wave_index: int = _session.current_wave - 1
	if wave_index < 0 or wave_index >= waves_array.size():
		push_error("[Battle] wave_index out of range: " + str(wave_index))
		return
	var wave_data: Dictionary = waves_array[wave_index]
	var enemies_array: Array = wave_data.get("enemies", [])

	var local_index: int = 0
	for entry in enemies_array:
		if not (entry is Dictionary):
			continue
		var enemy_type_id: String = str(entry.get("enemy_type_id", ""))
		var count: int = int(entry.get("count", 1))
		var is_boss: bool = bool(entry.get("is_boss", false))

		var enemy_data: Dictionary = MasterDataLoader.get_enemy(enemy_type_id)
		if enemy_data.is_empty():
			push_error("[Battle] enemy not found: " + enemy_type_id)
			continue

		for n: int in range(count):
			var unit: BattleUnit = BattleUnit.new(
				"enemy_%d_%d" % [_session.current_wave, local_index],
				BattleUnit.TEAM_ENEMY,
				str(enemy_data.get("name_key", "")),
				int(enemy_data.get("hp", 0)),
				int(enemy_data.get("atk", 0)),
				int(enemy_data.get("def", 0)),
				float(enemy_data.get("attack_range", 0)),
				float(enemy_data.get("attack_interval_sec", 0)),
				float(enemy_data.get("spd", 0)),
				is_boss
			)
			unit.x = ENEMY_BASE_X + local_index * ENEMY_STEP_X
			_session.enemy_units.append(unit)

			var view: Node = UNIT_VIEW_SCENE.instantiate()
			view.position = Vector2(unit.x, GROUND_Y)
			enemy_container.add_child(view)
			view.setup(unit)
			_enemy_views.append(view)
			_views_by_unit_id[unit.unit_id] = view
			local_index += 1


# ウェーブ開始演出。0.5秒待って敵を生成し、BATTLE_ACTIVE にする。
func _enter_wave_intro() -> void:
	_session.state = BattleSession.STATE_WAVE_INTRO
	_update_wave_label()
	await get_tree().create_timer(0.5).timeout
	# 待機中にリトライされて _session が変わっている可能性に備える
	if _session == null:
		return
	_spawn_current_wave_enemies()
	_session.state = BattleSession.STATE_BATTLE_ACTIVE


func _update_wave_label() -> void:
	wave_label.text = "%d / %d" % [_session.current_wave, _session.total_waves]


# 毎フレームの戦闘処理
func _process(delta: float) -> void:
	if _session == null:
		return
	if _result_applied:
		return
	if _session.state != BattleSession.STATE_BATTLE_ACTIVE:
		return

	# 1. 対象再選択（味方→敵の順）
	for unit in _session.party_units:
		_acquire_target_if_needed(unit)
	for unit in _session.enemy_units:
		_acquire_target_if_needed(unit)

	# 2. 攻撃 / 移動
	for unit in _session.party_units:
		_step_unit(unit, delta)
	for unit in _session.enemy_units:
		_step_unit(unit, delta)

	# 3. 勝敗判定（敗北判定を先に行う：EXEC §6-6）
	if _session.is_party_wiped():
		_enter_defeat()
		return
	if _session.is_wave_cleared():
		_enter_wave_clear()
		return


# 対象が未選択 or 死亡なら最も近い敵対を選び直す。
# 敵対チームに生存者がいなければ何もしない（PRE_PLAN §7-5）。
func _acquire_target_if_needed(unit: BattleUnit) -> void:
	if not unit.is_alive():
		return
	if unit.target_unit_id != "":
		var t: BattleUnit = _find_unit_by_id(unit.target_unit_id)
		if t != null and t.is_alive():
			return
		unit.target_unit_id = ""

	var opponents: Array = _session.get_alive_units(BattleUnit.TEAM_ENEMY if unit.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY)
	if opponents.is_empty():
		return

	var nearest: BattleUnit = null
	var nearest_dist: float = INF
	for o in opponents:
		if not (o is BattleUnit):
			continue
		var d: float = abs(unit.x - o.x)
		if d < nearest_dist:
			nearest_dist = d
			nearest = o
	if nearest != null:
		unit.target_unit_id = nearest.unit_id


func _find_unit_by_id(id: String) -> BattleUnit:
	for u in _session.party_units:
		if u is BattleUnit and u.unit_id == id:
			return u
	for u in _session.enemy_units:
		if u is BattleUnit and u.unit_id == id:
			return u
	return null


# 1 ユニットの 1 フレーム分の処理（攻撃 or 移動）
func _step_unit(unit: BattleUnit, delta: float) -> void:
	if not unit.is_alive():
		return
	if unit.target_unit_id == "":
		return
	var target: BattleUnit = _find_unit_by_id(unit.target_unit_id)
	if target == null or not target.is_alive():
		return
	var distance: float = abs(target.x - unit.x)
	if distance <= unit.attack_range:
		# 射程内
		unit.attack_timer += delta
		if unit.attack_timer >= unit.attack_interval_sec:
			var dmg: int = _compute_damage(unit, target)
			target.take_damage(dmg)
			_pop_damage(target, dmg)
			unit.attack_timer = 0.0
	else:
		# 射程外：対象方向へ移動
		var dir: float = sign(target.x - unit.x)
		unit.x += dir * unit.speed * delta
		# 射程外では attack_timer を進めない


# ダメージ計算。必ず max(1, ...) を入れる（EXEC §6-5）。
func _compute_damage(attacker: BattleUnit, target: BattleUnit) -> int:
	var raw: int = int(floor(attacker.atk * attacker.atk_multiplier)) - target.def
	return max(1, raw)


# 被弾したユニットの頭上にダメージ数値を出す
func _pop_damage(target: BattleUnit, amount: int) -> void:
	if not _views_by_unit_id.has(target.unit_id):
		return
	var view: Node = _views_by_unit_id[target.unit_id]
	if is_instance_valid(view) and view.has_method("pop_damage"):
		view.pop_damage(amount)


# ウェーブクリア処理（_enter_wave_clear → コルーチンで次ウェーブ or 勝利）
func _enter_wave_clear() -> void:
	_session.state = BattleSession.STATE_WAVE_CLEAR
	if _session.is_final_wave():
		_enter_victory()
		return
	_session.current_wave += 1
	_update_wave_label()
	# 次ウェーブは味方を左端から再スタートさせる（HP は引き継ぐ）
	_reset_party_positions()
	_enter_wave_intro()


# 勝利処理（EXEC §7-1 報酬二重適用防止フラグ）
func _enter_victory() -> void:
	if _result_applied:
		return
	_result_applied = true
	_session.state = BattleSession.STATE_VICTORY

	var result_data: Dictionary = {
		GameStateKeys.BATTLE_VICTORY: true,
		GameStateKeys.BATTLE_WAVES_CLEARED: _session.total_waves,
		GameStateKeys.BATTLE_REWARDS: _stage_data.get("rewards", {}),
	}
	GameManager.apply_battle_rewards(result_data)
	GameManager.mark_stage_cleared(_stage_id, 0)

	_show_result(true, result_data)


# 敗北処理（EXEC §7-4）
func _enter_defeat() -> void:
	if _result_applied:
		return
	_result_applied = true
	_session.state = BattleSession.STATE_DEFEAT
	# apply_battle_rewards も mark_stage_cleared も呼ばない
	_show_result(false, {})


# 結果画面の表示
func _show_result(victory: bool, result_data: Dictionary) -> void:
	if victory:
		result_label.text = tr("ui_battle_victory")
		var reward_lines: Array = []
		var rewards: Dictionary = result_data.get(GameStateKeys.BATTLE_REWARDS, {})
		if rewards.has("gold"):
			reward_lines.append(tr("ui_battle_reward_gold") + ": " + str(int(rewards["gold"])))
		if rewards.has("materials") and rewards["materials"] is Dictionary:
			for mat_id: String in (rewards["materials"] as Dictionary):
				var amount: int = int(rewards["materials"][mat_id])
				reward_lines.append(tr("ui_res_" + mat_id) + ": " + str(amount))
		reward_label.text = "\n".join(reward_lines)
		retry_button.hide()
	else:
		result_label.text = tr("ui_battle_defeat")
		reward_label.text = ""
		retry_button.show()
	result_view.show()
	back_button.show()


# 「もう一度」：BattleSession を作り直し、ウェーブ 1 から再開。PRE_PLAN §6.8 通り。
func _on_retry_pressed() -> void:
	_result_applied = false
	result_view.hide()
	# 古い敵 UnitView を即座に消したいが、queue_free は遅延実行のため
	# _init_session 内で clear し、新しい UnitView を上書きする。
	_init_session()
	_enter_wave_intro()


func _init_session() -> void:
	_stage_data = MasterDataLoader.get_stage(_stage_id)
	var total_waves: int = int(_stage_data.get("waves", []).size())
	var stage_type: String = GameStateKeys.STAGE_TYPE_STORY
	# 既存の _session から引き継ぐ（リトライ時に stage_type を変えない）
	if _session != null:
		stage_type = _session.stage_type
	_views_by_unit_id.clear()
	_session = BattleSession.new(_stage_id, stage_type, _stage_data.get("party_id", ""), total_waves)
	_init_party_units()


# 「拠点へ戻る」
func _on_back_pressed() -> void:
	# SceneManager.go_back() は履歴がダミー実装のため使わない
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")


# ============================================================
# デバッグ用（BattleDebugPanel から呼ばれる）
# 本番のロジックからは呼ばない。
# 状態を直接書き換えず、通常と同じ take_damage / 状態遷移を通す。
# ============================================================

func debug_kill_one_enemy() -> void:
	if _session == null:
		return
	for u in _session.enemy_units:
		if u is BattleUnit and u.is_alive():
			var dmg: int = u.hp
			u.take_damage(dmg)
			_pop_damage(u, dmg)
			print("[BattleDebug] %s をたおした" % u.unit_id)
			return
	print("[BattleDebug] 生存している敵がいない")


func debug_kill_all_enemies() -> void:
	if _session == null:
		return
	for u in _session.enemy_units:
		if u is BattleUnit and u.is_alive():
			var dmg: int = u.hp
			u.take_damage(dmg)
			_pop_damage(u, dmg)
	print("[BattleDebug] ウェーブ %d の敵を全滅させた" % _session.current_wave)


func debug_damage_party(amount: int) -> void:
	if _session == null:
		return
	for u in _session.party_units:
		if u is BattleUnit and u.is_alive():
			u.take_damage(amount)
			_pop_damage(u, amount)
	print("[BattleDebug] 味方全員に %d ダメージ" % amount)


# 通常の勝利経路をそのまま通す。報酬もステージクリアも本番と同じに入る。
func debug_force_victory() -> void:
	if _session == null or _result_applied:
		return
	_session.current_wave = _session.total_waves
	_update_wave_label()
	_enter_victory()


func debug_force_defeat() -> void:
	if _session == null or _result_applied:
		return
	for u in _session.party_units:
		if u is BattleUnit and u.is_alive():
			u.take_damage(u.hp)
	_enter_defeat()
