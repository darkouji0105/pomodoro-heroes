extends Node2D

# BattleController
# battle.tscn に張り付くコントローラ。
# 戦闘ループ・ウェーブ進行・勝敗確定・結果表示を一元管理する。
# フェーズ2（スキル・ボス）＋チャージスキル・3列レイアウト・
# 勝利時のスタミナ消費を反映済み。

# ユニットを並べる y 位置。
# 画面下部はスキルボタン3列ぶんの高さを使うため、その上に収まる位置に置く。
const GROUND_Y: float = 240.0
# 味方の初期 X 位置
const PARTY_BASE_X: float = 200.0
const PARTY_STEP_X: float = 100.0
# 敵の初期 X 位置
const ENEMY_BASE_X: float = 900.0
const ENEMY_STEP_X: float = 100.0

const UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/adventure/unit_view.tscn")
const DEBUG_PANEL_SCRIPT: GDScript = preload("res://scenes/adventure/battle_debug_panel.gd")
const PROJECTILE_VIEW_SCRIPT: GDScript = preload("res://scenes/adventure/projectile_view.gd")
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

# チャージゲージの色（本タスク限定の例外。main_theme.tres に対応する概念が無い）
const CHARGE_COLOR_NORMAL: Color = Color(0.6, 0.7, 0.9)
const CHARGE_COLOR_JUST: Color = Color(1.0, 0.9, 0.4)
const CHARGE_COLOR_OVER: Color = Color(0.5, 0.5, 0.5)
const CHARGE_GAUGE_HEIGHT: int = 8

# 通常攻撃を待ち行列に積むときの skill_id。⚠ どのスキルファイルにも存在しない。
# 警告文と待ち行列の中身にしか出ず、マスターを引くのには使わない
# （通常攻撃の中身は BattleUnit.basic_attack が持っている）。
const BASIC_ATTACK_SKILL_ID: String = "basic_attack"

# ノード参照
@onready var party_container: Node2D = $PartyUnitsContainer
@onready var enemy_container: Node2D = $EnemyUnitsContainer
@onready var wave_label: Label = $HUD/WaveLabel
@onready var skill_buttons_container: HBoxContainer = $HUD/SkillButtons
@onready var result_view: Control = $ResultView
@onready var result_label: Label = $ResultView/ResultLabel
@onready var reward_label: Label = $ResultView/RewardLabel
@onready var retry_button: Button = $ResultView/RetryButton
@onready var back_button: Button = $ResultView/BackButton

# データ
var _stage_id: String = "stage_1"
var _stage_data: Dictionary = {}
var _session: BattleSession = null

# 敵 UnitView の参照配列。ウェーブ切替時に queue_free して clear する。
var _enemy_views: Array = []

# 味方の UnitView は wave 間で破棄しない（連戦のため）。
# ただし「もう一度」リトライ時は作り直す。
var _party_views: Array = []
# 飛んでいる投射物のビュー。⚠ 待ち行列（SkillRuntime）とは別物なので、
#   捨てるときは _clear_projectiles() と clear_all() を必ずセットで呼ぶ。
var _projectile_views: Array = []

# unit_id -> UnitView。ダメージ数値の表示先を引くために持つ。
var _views_by_unit_id: Dictionary = {}

# スキルボタン。各要素は {button, user, skill_id, name_key, cooldown_sec, charge}
var _skill_buttons: Array = []

# チャージ中のスキル。{entry: Dictionary, time: float}。未チャージ時は空。
# 同時に1つしかチャージできない。
var _charging: Dictionary = {}

# 実行中のスキル層（段階2）。多段・遅延の待ち行列を持つ。
# ここに待ち行列を直接持たないこと。battle_controller は入力と表示だけ（PLAN 7-1）。
var _skill_runtime: SkillRuntime = null

# 状態の器（段階3）。buff / dot が残る場所。
#
# ⚠ SkillRuntime と混ぜないこと（PLAN 7-2）。捨てる基準が正反対で、
#   混ぜると術者が死んだ瞬間に敵に付けたDoTが消える。
var _status: StatusRegistry = null

# 報酬二重適用防止フラグ
var _result_applied: bool = false

var _debug_panel: CanvasLayer = null


func _ready() -> void:
	# 起動時に SceneManager から transfer_data を 1 回だけ取り出す。
	# 2 回呼ぶと 2 回目は空 dict になる。
	var data: Dictionary = SceneManager.consume_transfer_data()

	_stage_id = str(data.get(TransferKeys.STAGE_ID, ""))
	if _stage_id == "":
		push_warning("[Battle] stage_id が渡されていないため stage_1 で開始する")
		_stage_id = "stage_1"

	# stage_type は TransferKeys.STAGE_TYPE 優先、無ければ STAGE_TYPE_STORY
	var stage_type: String = str(data.get(TransferKeys.STAGE_TYPE, ""))
	if stage_type == "":
		stage_type = GameStateKeys.STAGE_TYPE_STORY

	_stage_data = MasterDataLoader.get_stage(_stage_id)
	if _stage_data.is_empty():
		push_error("[Battle] stage_data が空: " + _stage_id)
		return

	var party_id: String = str(_stage_data.get("party_id", ""))
	var waves_array: Array = _stage_data.get("waves", [])
	var total_waves: int = waves_array.size()

	_session = BattleSession.new(_stage_id, stage_type, party_id, total_waves)

	# ⚠ 器を先に作る。SkillRuntime が器を引数に取る。
	_status = StatusRegistry.new(_session)
	# ⚠ 表示の経路は1本。DoT のダメージも通常のスキルと同じ _pop_damage を通る。
	_status.effects_applied.connect(_on_skill_effects_applied)

	_skill_runtime = SkillRuntime.new(_session, _status)
	_skill_runtime.effects_applied.connect(_on_skill_effects_applied)
	# ⚠ ここが「データとビューが出会う場所」（PLAN 7-1）。新層はノードを触らず、
	#   投射物が要るときはシグナルで頼んでくる。生成はこの画面の担当。
	_skill_runtime.projectile_requested.connect(_on_projectile_requested)

	_init_party_units()
	result_view.hide()
	retry_button.pressed.connect(_on_retry_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_setup_debug_panel()
	# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ ウェーブ開始より前。ここで
	#   ファイルを空にするので、あとに置くと1波目の頭が消える。
	BattleLog.begin_battle(_stage_id, party_id, total_waves)
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
	# ⚠ 戦闘ログの取りこぼし対策（EXEC_BATTLE_LOG.md §0）。節目（ウェーブ交代・
	#   勝敗）だけだと、途中で「戻る」を押した戦闘・シーン遷移・通常終了で
	#   溜めたぶんが丸ごと消える。
	BattleLog.flush()


func get_session() -> BattleSession:
	return _session


# 状態の器を返す。⚠ 検証用（BattleDebugPanel が状態の行を出すのに使う）。
#   デバッグパネルと一緒にリリース前に消すもの。ゲームのロジックから呼ばないこと。
func get_status_registry() -> StatusRegistry:
	return _status


# 味方の BattleUnit と UnitView を生成する。
# ウェーブをまたいで再生成しないが、リトライ時は呼び直す。
func _init_party_units() -> void:
	# 既存があれば破棄（リトライ対応）
	for v in _party_views:
		if v is Node and is_instance_valid(v):
			v.queue_free()
	_party_views.clear()
	for v in party_container.get_children():
		v.queue_free()

	# 編成は状態が唯一の正（EXEC_PARTY_MEMBERS.md）。
	#
	# ⚠ MasterDataLoader.get_party() をここで読まないこと。stages.json の party_id は
	#   もう戦闘のメンバーを決めない（セーブに編成が無いときの初期値にだけ使う）。
	#   両方読むと編成が2箇所にある状態になり、どちらが効いているか実機でしか
	#   分からなくなる。
	# ⚠ _session.party_id は BattleLog の見出しとして残っているだけ。
	var members: Array = GameManager.get_party_members()
	if members.is_empty():
		push_error("[Battle] 編成が空（GameManager.get_party_members()）")
		return

	for i: int in range(members.size()):
		var character_id: String = str(members[i])
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		if char_data.is_empty():
			push_error("[Battle] character not found: " + character_id)
			continue

# レベル・研究・装備を合成した最終値。get_character_growth() の生の stats を
		# 直接読まないこと（研究の stat_boost_all と装備の加算が乗らない）。
		# エントリが無いキャラでも characters.json の既定値から組み立てて返るため、
		# has_growth のフォールバック分岐は要らない。
		var stats: Dictionary = GameManager.get_effective_stats(character_id)

		# 軸をここで1本ずつ取り出さないこと。10軸を辞書のまま create() に渡す。
		# 軸が増えてもこの行は直さなくてよい。
		var unit: BattleUnit = BattleUnit.create(
			"party_%d" % i,
			BattleUnit.TEAM_PARTY,
			char_data,
			stats,
			false
		)
		unit.x = _party_start_x(i)

		# スキルの割り当て。⚠ 敵は _spawn_current_wave_enemies() 側で別に割り当てる
		# （enemies.json の "skills" はそのまま装備枠。プレイヤーが選ぶ2枠が無い）。
		#
		# characters.json の "skills" を直接読まないこと。それはそのキャラの
		# 「候補一覧」であって、プレイヤーが選んだ2枠ではない
		# （EXEC_SKILL_SELECT.md §7）。上の stats が get_effective_stats() から
		# 来ているのと同じ理由で、スキルも状態から引く。
		#
		# 未選択の枠は get_battle_skills() 側が候補の先頭で埋めるため、
		# ここでフォールバックを書かない。
		var skill_list: Array = GameManager.get_battle_skills(character_id)
		unit.skill_ids = skill_list.duplicate()
		unit.skill_cooldowns = {}
		for sid in unit.skill_ids:
			unit.skill_cooldowns[str(sid)] = 0.0

		_session.party_units.append(unit)

		var view: Node = UNIT_VIEW_SCENE.instantiate()
		view.position = Vector2(unit.x, GROUND_Y)
		party_container.add_child(view)
		view.setup(unit)
		_party_views.append(view)
		_views_by_unit_id[unit.unit_id] = view

	# 味方が確定した直後に必ず作り直す。
	# リトライで BattleUnit が作り直されるため、
	# ここで作らないとボタンが古いユニットを掴んだままになる。
	_build_skill_buttons()


func _party_start_x(index: int) -> float:
	return PARTY_BASE_X + index * PARTY_STEP_X


# ウェーブが切り替わるときに味方を左端の初期位置へ戻す。
#
# 戻すのは位置・ターゲット・攻撃タイマーだけ。
# HP とスキルのクールダウンは絶対に戻さないこと。戻すと連戦でなくなる。
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
func _spawn_current_wave_enemies() -> void:
	for v in _enemy_views:
		if v is Node and is_instance_valid(v):
			v.queue_free()
	_enemy_views.clear()
	for v in enemy_container.get_children():
		v.queue_free()
	for u in _session.enemy_units:
		if u is BattleUnit:
			_views_by_unit_id.erase(u.unit_id)
	_session.enemy_units.clear()

	var waves_array: Array = _stage_data.get("waves", [])
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

		var base_data: Dictionary = MasterDataLoader.get_enemy(enemy_type_id)
		if base_data.is_empty():
			push_error("[Battle] enemy not found: " + enemy_type_id)
			continue

		# stat_overrides を基本値に被せる。
		# 上書きされたキーが一目で分かるよう、複製してから差し替える。
		var enemy_data: Dictionary = base_data.duplicate(true)
		var overrides: Variant = entry.get("stat_overrides", {})
		if overrides is Dictionary:
			for key in (overrides as Dictionary):
				enemy_data[key] = (overrides as Dictionary)[key]

		for n: int in range(count):
			# 敵はマスターのエントリがそのまま能力値なので、
			# p_source と p_stats に同じ辞書を渡す。
			var unit: BattleUnit = BattleUnit.create(
				"enemy_%d_%d" % [_session.current_wave, local_index],
				BattleUnit.TEAM_ENEMY,
				enemy_data,
				enemy_data,
				is_boss
			)
			unit.x = ENEMY_BASE_X + local_index * ENEMY_STEP_X

			# スキルの割り当て（EXEC_ENEMY_PARITY.md §3-2）。
			#
			# ⚠ enemies.json の "skills" は味方と違って「候補一覧」ではなく
			#   そのまま装備枠。敵にプレイヤーは居ないので、
			#   get_battle_skills() の2段（候補→選んだ2枠）を真似ない。
			# ⚠ stat_overrides と同じく enemy_data から読む（基本値ではなく、
			#   ウェーブ側で上書きされたあとの辞書）。
			unit.skill_ids = []
			unit.skill_cooldowns = {}
			for raw_sid: Variant in enemy_data.get("skills", []):
				var sid: String = str(raw_sid)
				unit.skill_ids.append(sid)
				unit.skill_cooldowns[sid] = 0.0

			_session.enemy_units.append(unit)

			var view: Node = UNIT_VIEW_SCENE.instantiate()
			view.position = Vector2(unit.x, GROUND_Y)
			enemy_container.add_child(view)
			view.setup(unit)
			_enemy_views.append(view)
			_views_by_unit_id[unit.unit_id] = view
			local_index += 1

	# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ 生成し終わってから出す。
	#   ここが jsonl の区切りになる（どこからが次の波か）。
	var spawned_ids: Array = []
	for u in _session.enemy_units:
		if u is BattleUnit:
			spawned_ids.append((u as BattleUnit).unit_id)
	BattleLog.log_wave(_session.current_wave, _session.total_waves, spawned_ids)


# ウェーブ開始演出。0.5秒待って敵を生成し、BATTLE_ACTIVE にする。
func _enter_wave_intro() -> void:
	_session.state = BattleSession.STATE_WAVE_INTRO
	_update_wave_label()
	await get_tree().create_timer(0.5).timeout
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

	# チャージとボタンの表示更新は状態に関わらず毎フレーム行う。
	# ここを状態ガードの内側に置くと、結果画面が出たあとや
	# ウェーブ間の待機中にボタンが押せる状態のまま固まる。
	_tick_charge(delta)
	_update_skill_buttons()

	if _result_applied:
		return
	if _session.state != BattleSession.STATE_BATTLE_ACTIVE:
		return

	# ログの時計も戦闘中だけ進む（EXEC_BATTLE_LOG.md §4-5）。
	# ⚠ 実時間を使わないこと。速度を上げると中の時計とズレる。
	BattleLog.advance(delta)

	# クールダウンは戦闘中だけ進む（決定事項 8-1）
	# ⚠ 敵も回すこと（EXEC_ENEMY_PARITY.md §4）。回さないと敵は最初の1回しか
	#   撃てず、しかもエラーが1つも出ない。
	for unit in _session.party_units:
		if unit is BattleUnit:
			unit.tick_cooldowns(delta)
	for unit in _session.enemy_units:
		if unit is BattleUnit:
			unit.tick_cooldowns(delta)

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

	# 3. 実行中のスキル（多段・遅延の待ち行列）
	#
	# ここに置く理由が2つある。
	#  ・勝敗判定より前 … 遅延で入った止めの一撃が同じフレームの判定に反映される。
	#    後ろに置くと「死んでいるのに1フレーム戦闘が続く」
	#  ・攻撃/移動より後 … distance でスケールする効果が、通常攻撃と同じ
	#    「そのフレームの移動後の距離」を読む
	# ⚠ 状態ガードの内側であること。ウェーブ間や結果画面で待ち行列を進めない。
	_skill_runtime.tick(delta)

	# 3-2. 状態（buff の寿命・dot の周期発火）
	#
	# ⚠ 待ち行列の直後・勝敗判定の前。DoT の止めの一撃が同じフレームの勝敗判定に
	#   反映される。後ろに置くと「HPが0なのに1フレーム戦闘が続く」。
	# ⚠ 状態ガードの内側であること。結果画面やウェーブ間で DoT を進めない。
	# ⚠ バフの効き始めはこの位置と関係ない。付いた瞬間に set_stat_mods() が
	#   走るので同じフレームの続きから効く。ここで進むのは寿命と周期だけ。
	_status.tick(delta)

	# 4. 死亡の介入点（PLAN 11-1・復活はここ）
	#
	# ⚠ 勝敗判定より先。後ろに置くと「戦闘が終わってから復活する」事故になり、
	#   無音で壊れる（PLAN 11-1 が名指しで警告している形）。
	# ⚠ _status.tick() より後。DoT の止めの一撃も同じフレームで拾う。
	# ⚠ 走査はここ1箇所だけ。ダメージを与える各所（_apply_damage /
	#   _fire_intervals / F3 の自傷）に2本目の判定を作らないこと。
	_step_deaths()

	# 5. 勝敗判定（敗北判定を先に行う）
	if _session.is_party_wiped():
		_enter_defeat()
		return
	if _session.is_wave_cleared():
		_enter_wave_clear()
		return


# HPが0になった全員に、死亡の介入点を1回だけ通す（PLAN 11-1）。
#
# ⚠ 死亡を知らせるシグナルが無いので毎フレーム走査する（StatusRegistry の
#   _drop_dead_hosts() と同じ形）。件数は多くても数体。
func _step_deaths() -> void:
	for unit in _session.party_units:
		_resolve_one_death(unit)
	for unit in _session.enemy_units:
		_resolve_one_death(unit)


# ⚠ death_handled を書いてよいのはここだけ（unit.gd の注記）。
# ⚠ 戻り値で分岐しない。HPを戻すのも状態を消すのも器の側の責務。
func _resolve_one_death(unit: Variant) -> void:
	if not (unit is BattleUnit):
		return
	var u: BattleUnit = unit
	if u.is_alive():
		# 復活した／まだ死んでいない。次の死亡で介入点を通せるように戻す。
		# ⚠ ここで戻すこと。復活の直後に必ず通る。戻さないと2回目の死亡で
		#   介入点を通らず、しかも _drop_dead_hosts() が状態を捨てられなくなる。
		u.death_handled = false
		return
	if u.death_handled:
		return
	# ⚠ 印を先に立てる。resolve_death() の中で clear_for_unit() が走り、
	#   そのあと _drop_dead_hosts() が「処理済みだから捨ててよい」と判断できる。
	u.death_handled = true
	_status.resolve_death(u)


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
		unit.attack_timer += delta
		# attack_interval_sec は create() の時点で atkspd 適用済み。
		# ここでマスターから読み直さないこと。
		if unit.attack_timer >= unit.attack_interval_sec:
			# 敵はここでスキルを試す（EXEC_ENEMY_PARITY.md §3-2）。
			#
			# ⚠ 攻撃間隔と同じ拍で撃つ。毎フレーム試すと、クールダウンが空いた
			#   フレームに通常攻撃と同時に出て、拍が2本になる。
			# ⚠ 射程内（この if の内側）でしか撃たない。歩いている間に撃たせると、
			#   target.range が未設定（宿題11）なので画面端から当たる。
			if not (unit.team == BattleUnit.TEAM_ENEMY and _try_enemy_skill(unit)):
				_fire_basic_attack(unit, target)
			unit.attack_timer = 0.0
	else:
		var dir: float = sign(target.x - unit.x)
		unit.x += dir * unit.speed * delta


# 敵のスキル発動（EXEC_ENEMY_PARITY.md §3-2）。撃てたら true。
#
# ⚠ 撃てるかの判定をここに書かない。_fire_skill() が SkillActivation に聞く。
#   戻り値を見るだけにしてあるのは、判定を2箇所に増やさないため。
# ⚠ 専用の cast を作らない（PLAN 6-5）。味方のボタンとまったく同じ
#   _fire_skill() を通るので、クールダウンの開始も購読の配布も自動で揃う。
# ⚠ 乱数で選ばない。skill_ids の先頭から、最初に撃てたものを撃つ。
#   乱数を入れるとログの再現性が落ちて、事故を追えなくなる。
func _try_enemy_skill(unit: BattleUnit) -> bool:
	for raw_sid: Variant in unit.skill_ids:
		if _fire_skill(unit, str(raw_sid), 1.0):
			return true
	return false


# 通常攻撃を1発撃つ。
#
# ⚠ 式をここに書かない。スキルとまったく同じ経路（SkillResolver）を通す。
#   通さないと、段階1で作ったダメージの介入点（軽減・確定会心・シールド・反射）が
#   「スキルにだけ効く」という説明のつかない仕様になる。
#   ⚠ 以前ここには _compute_damage() があり、BattleFormula を直接叩いていた。
#     戻さないこと。
#
# ⚠ 対象を選び直さない。歩いて近づいた相手（target_unit_id）をそのまま渡す。
#   SkillResolver.select_targets() に選ばせると sort: nearest で別人に当たりうる。
# ⚠ SkillActivation を通さない。射程・生死の判定は _step_unit() が済ませている。
#   通すと no_target / cooldown で通常攻撃が止まる（判定を2箇所にしない）。
# ⚠ 会心をここで振らない。SkillResolver が対象1体につき1回振る。二重に振ると
#   乱数を消費する回数が変わる。
# ⚠ SkillRuntime（待ち行列）に載せない。載せると攻撃間隔ごとに行列が伸びる。
func _fire_basic_attack(unit: BattleUnit, target: BattleUnit) -> void:
	# 空なのはデータ側の問題。ロード時検証が赤で言っているので、ここでは黙って撃たない
	# （毎フレーム走るので、ここで警告を出すと出力パネルが埋まる）。
	if unit.basic_attack.is_empty():
		return
	# ⚠ 待ち行列を通す。直接 resolve() を呼ぶと、飛んでいる矢が待ち行列に乗らず、
	#   飛び道具の無効化（cancel_by_delivery）が通常攻撃だけに効かなくなる。
	# ⚠ クールダウンは回さない。通常攻撃の間隔は attack_timer が持つ。
	#
	# ⚠ target を書いていない通常攻撃は、対象を固定で渡す。cast() に選ばせると
	#   「歩いて近づいた相手」ではなく sort: nearest が選んだ相手に当たる。
	# ⚠ target を書いてある通常攻撃は範囲攻撃（僧侶など）。固定を渡さず cast() に
	#   選ばせる。⚠ ここで両方渡すと固定が勝ち、書いた target が黙って無視される。
	var fixed_ids: Array = []
	if not unit.basic_attack.has("target"):
		fixed_ids = [target.unit_id]
	_skill_runtime.cast(unit, BASIC_ATTACK_SKILL_ID, unit.basic_attack, 1.0, fixed_ids)


# ⚠ is_crit / is_dot は既定値を持つ。既定値を外すと、引数を渡していない
#   F3 パネルの自傷3本（_pop_damage(u, dmg) の形）が壊れる。
func _pop_damage(target: BattleUnit, amount: int, is_crit: bool = false, is_dot: bool = false) -> void:
	if target == null:
		return
	if not _views_by_unit_id.has(target.unit_id):
		return
	var view: Node = _views_by_unit_id[target.unit_id]
	if is_instance_valid(view) and view.has_method("pop_damage"):
		view.pop_damage(amount, is_crit, is_dot)


# 回復の数値。_pop_damage と同じ形（見つからなければ黙って何もしない）。
func _pop_heal(target: BattleUnit, amount: int) -> void:
	if target == null:
		return
	if not _views_by_unit_id.has(target.unit_id):
		return
	var view: Node = _views_by_unit_id[target.unit_id]
	if is_instance_valid(view) and view.has_method("pop_heal"):
		view.pop_heal(amount)


# ============================================================
# スキル
# ============================================================

# 味方が作り直されるたびに呼ぶ。既存のボタンは必ず捨てる。
# キャラごとに1列、その列の中にスキルを縦に並べる。
func _build_skill_buttons() -> void:
	_cancel_charge()
	for entry in _skill_buttons:
		var b: Variant = entry.get("button", null)
		if b is Node and is_instance_valid(b):
			b.queue_free()
	_skill_buttons.clear()
	for child in skill_buttons_container.get_children():
		child.queue_free()

	for unit in _session.party_units:
		if not (unit is BattleUnit):
			continue

		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		skill_buttons_container.add_child(column)

		var name_label: Label = Label.new()
		name_label.text = tr(unit.unit_name_key)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)

		for sid in unit.skill_ids:
			var skill_id: String = str(sid)
			var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
			if skill_data.is_empty():
				continue

			var charge: Dictionary = {}
			var raw_charge: Variant = skill_data.get("charge", null)
			if raw_charge is Dictionary:
				charge = (raw_charge as Dictionary).duplicate(true)

			# 発動の型は activation を見る。charge 欄の有無で分岐しないこと（PLAN 8章）。
			var activation: String = str(skill_data.get("activation", SkillSchema.ACTIVATION_INSTANT))

			var button: Button = PRIMARY_BUTTON_SCENE.instantiate()
			# label_key は使わない。残り秒数やチャージ時間を混ぜるため text を直接扱う。
			button.text = tr(str(skill_data.get("name_key", "")))
			column.add_child(button)

			# チャージスキルだけゲージを足す。
			# 常に置いておくことで「これはためられる」と見て分かる。
			var gauge: ProgressBar = null
			if activation == SkillSchema.ACTIVATION_CHARGE:
				gauge = ProgressBar.new()
				gauge.custom_minimum_size = Vector2(0, CHARGE_GAUGE_HEIGHT)
				gauge.min_value = 0.0
				gauge.max_value = 1.0
				gauge.step = 0.01
				gauge.value = 0.0
				gauge.show_percentage = false
				gauge.modulate = CHARGE_COLOR_NORMAL
				column.add_child(gauge)

			var entry: Dictionary = {
				"button": button,
				"gauge": gauge,
				"user": unit,
				"skill_id": skill_id,
				"name_key": str(skill_data.get("name_key", "")),
				# haste 適用済みの実効 CD。base を入れないこと（表示に使うときにずれる）。
				"cooldown_sec": BattleFormula.cooldown(
					float(skill_data.get("cooldown_sec", 0.0)),
					unit.get_stat(GameStateKeys.STAT_HASTE)
				),
				"charge": charge,
			}
			_skill_buttons.append(entry)

			if activation == SkillSchema.ACTIVATION_CHARGE and not charge.is_empty():
				# チャージスキルは押した瞬間ではなく離した瞬間に発動する
				button.button_down.connect(_on_charge_button_down.bind(entry))
				button.button_up.connect(_on_charge_button_up.bind(entry))
			else:
				if activation == SkillSchema.ACTIVATION_CHARGE:
					# 押しても離しても反応しないボタンを作らない。
					# ロード時検証（E6）でも捕まえるが、ここでも instant として繋ぐ。
					push_error("[BattleController] activation: charge なのに charge{} が空: " + skill_id)
				button.pressed.connect(_on_skill_button_pressed.bind(unit, skill_id))


func _update_skill_buttons() -> void:
	var active: bool = _session != null and _session.state == BattleSession.STATE_BATTLE_ACTIVE
	var charging_entry: Variant = _charging.get("entry", null)
	for entry in _skill_buttons:
		var button: Variant = entry.get("button", null)
		if not (button is Button) or not is_instance_valid(button):
			continue
		var user: BattleUnit = entry.get("user", null)
		var skill_id: String = str(entry.get("skill_id", ""))
		var name_key: String = str(entry.get("name_key", ""))

		var remaining: float = 0.0
		var alive: bool = false
		if user != null:
			remaining = user.get_cooldown(skill_id)
			alive = user.is_alive()

		if entry == charging_entry:
			# チャージ中はボタンを押しっぱなしなので disabled にしない。
			# disabled にすると button_up が飛ばず、離しても発動しなくなる。
			var t: float = float(_charging.get("time", 0.0))
			button.text = "%s %.2f%s" % [tr(name_key), t, _just_suffix(entry, t)]
			button.disabled = false
			_update_charge_gauge(entry, t)
			continue

		_update_charge_gauge(entry, 0.0)

		if remaining > 0.0:
			button.text = "%s (%.1f)" % [tr(name_key), remaining]
		else:
			button.text = tr(name_key)

		button.disabled = (not active) or (not alive) or (remaining > 0.0)


# ジャストの窓に入っているあいだだけボタンに出す目印。
# 1秒を目で測るのは無理なので、フィードバックが無いと当てられない。
func _just_suffix(entry: Dictionary, t: float) -> String:
	var charge: Dictionary = entry.get("charge", {})
	if charge.is_empty():
		return ""
	var just_sec: float = float(charge.get("just_sec", 1.0))
	var window: float = float(charge.get("just_window_sec", 0.15))
	if absf(t - just_sec) <= window:
		return "  JUST"
	return ""


# チャージの進み具合をゲージに反映する。
# 目盛りは just_sec を満タンとする。窓に入ると色が変わり、
# 行き過ぎるとくすんだ色になる（威力が 100% に落ちたことの合図）。
func _update_charge_gauge(entry: Dictionary, t: float) -> void:
	var gauge: Variant = entry.get("gauge", null)
	if not (gauge is ProgressBar) or not is_instance_valid(gauge):
		return
	var charge: Dictionary = entry.get("charge", {})
	if charge.is_empty():
		return

	var just_sec: float = float(charge.get("just_sec", 1.0))
	var window: float = float(charge.get("just_window_sec", 0.15))
	if just_sec <= 0.0:
		return

	gauge.value = clampf(t / just_sec, 0.0, 1.0)
	if absf(t - just_sec) <= window:
		gauge.modulate = CHARGE_COLOR_JUST
	elif t > just_sec:
		gauge.modulate = CHARGE_COLOR_OVER
	else:
		gauge.modulate = CHARGE_COLOR_NORMAL


# スキル発動。
# 撃てるかの判定は SkillActivation に集約してある。
# クールダウンの開始は必ず最後。撃てなかった場合はクールダウンを回さない
# （対象が0体でも消費される形だったのを、決定1-6 で「押せなかっただけ」に変えた）。
# 勝敗判定はここで行わない。_process の判定に一本化する。
func _on_skill_button_pressed(user: BattleUnit, skill_id: String) -> void:
	_fire_skill(user, skill_id, 1.0)


# ⚠ 戻り値は「撃てたか」。敵のAI（_try_enemy_skill）が、撃てなかったときに
#   通常攻撃へ回すために見る。判定を呼び出し側にコピーさせないための戻り値であって、
#   ここ以外に blocked_reason() を書かないこと（EXEC_ENEMY_PARITY.md §3-2）。
func _fire_skill(user: BattleUnit, skill_id: String, power_ratio: float) -> bool:
	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)

	# 撃てるかの判定は SkillActivation に集約してある。
	# ここに条件を書き足さないこと（PLAN_SKILL_TEMPLATE.md 12章）。
	# 撃てなかったらクールダウンは回さない。押せなかっただけ。
	var reason: String = SkillActivation.blocked_reason(user, skill_id, skill_data, _session)
	if reason != SkillActivation.REASON_OK:
		return false

	# 発動を1個作って新層に渡す。チャージ倍率の畳み込みも、効果を trigger ごとに
	# 待ち行列へ割るのも新層の仕事（PLAN 7-1）。ここに待ち行列を持たないこと。
	# 結果は effects_applied シグナルで返ってくる（cast の効果はこの行の中で発火する）。
	_skill_runtime.cast(user, skill_id, skill_data, power_ratio)

	# skills.json の cooldown_sec は base。haste を通してから渡す。
	# ⚠ 待ち行列が空になるのを待たない。押した時点で回り始めるのが今の挙動。
	user.start_cooldown(skill_id, BattleFormula.cooldown(
		float(skill_data.get("cooldown_sec", 0.0)),
		user.get_stat(GameStateKeys.STAT_HASTE)
	))
	return true


# ============================================================
# 投射物（PLAN 6-7 / 6-8）
# ============================================================

# 新層から「投射物を出してくれ」と頼まれたときに呼ばれる。
#
# ⚠ ここが「データとビューが出会う場所」（PLAN 7-1）。新層は RefCounted で
#   ノードを知らないので、生成はこの画面だけがやる。
# ⚠ 演出シーンのIDは delivery から引く（人間の決定）。JSONに演出の欄を足さない。
# ⚠ 対象1体につき1本出す。対象0体なら1本も出ないが、待ち行列の要素は積まれて
#   いるので5秒後にタイムアウトで発火する（空振り。正常系）。
func _on_projectile_requested(
		cast_id: int, delivery: String, user_id: String, target_ids: Array
) -> void:
	var user: BattleUnit = _find_unit_by_id(user_id)
	if user == null:
		return
	_prune_projectiles()
	for raw_id: Variant in target_ids:
		var target: BattleUnit = _find_unit_by_id(str(raw_id))
		if target == null:
			continue
		var view: Node2D = Node2D.new()
		view.set_script(PROJECTILE_VIEW_SCRIPT)
		# ⚠ 味方のコンテナに入れない。ウェーブ交代で敵のビューごと消えるため。
		add_child(view)
		view.setup(
			self,
			cast_id,
			target.unit_id,
			Vector2(user.x, GROUND_Y),
			Vector2(target.x, GROUND_Y),
			_projectile_speed(delivery),
			_projectile_color(delivery)
		)
		_projectile_views.append(view)


# 着弾の合図。演出シーンから呼ばれる。
#
# ⚠ ダメージはここでも出さない。新層に「着いた」と伝えるだけで、
#   待っていた効果は SkillRuntime が発火させる（経路は1本・PLAN 6-5）。
# ⚠ 同じ cast_id の矢が複数本あっても、待ち行列から取り出すのは最初の1本だけ。
#   2本目以降の合図は何も起こさない（全体攻撃で対象の数だけ矢が出るため）。
func on_projectile_hit(cast_id: int) -> void:
	if _skill_runtime == null:
		return
	_skill_runtime.notify_event(cast_id, SkillSchema.EVENT_HIT)


func _projectile_speed(delivery: String) -> float:
	if delivery == SkillSchema.DELIVERY_MAGIC:
		return Balance.adventure.magic_speed_px_sec
	return Balance.adventure.projectile_speed_px_sec


func _projectile_color(delivery: String) -> Color:
	if delivery == SkillSchema.DELIVERY_MAGIC:
		return ProjectileView.COLOR_MAGIC
	return ProjectileView.COLOR_PROJECTILE


# 飛んでいる投射物を全部消す。ウェーブ交代・勝敗確定・リトライで呼ぶ。
#
# ⚠ _skill_runtime.clear_all() と必ずセットで呼ぶこと。待ち行列だけ消すと
#   矢が飛び続けて、着弾しても何も起きない（無音）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。remove_child してから queue_free。
#
# ⚠ この配列には解放済みの参照が必ず混じる。投射物は着弾すると自分から
#   queue_free() するが、配列からは抜けないため。
#   ⚠ `view is Node` を先に書くと「Left operand of 'is' is a previously freed
#     instance」で赤が出る（実際に踏んだ）。is_instance_valid() を先に見ること。
func _clear_projectiles() -> void:
	for view: Variant in _projectile_views:
		if not is_instance_valid(view):
			continue
		var node: Node = view as Node
		remove_child(node)
		node.queue_free()
	_projectile_views.clear()


# 着弾して消えた投射物を配列から落とす。
# ⚠ 発射のたびに呼ぶ。呼ばないと、1回の戦闘のあいだ配列が伸び続ける
#   （中身は解放済みの参照なので見た目には何も起きず、気づけない）。
func _prune_projectiles() -> void:
	var alive: Array = []
	for view: Variant in _projectile_views:
		if is_instance_valid(view):
			alive.append(view)
	_projectile_views = alive


# 新層が効果を1つ当てたときに呼ばれる。表示だけを担当する。
# cast の効果は _fire_skill() の中で、delay の効果は _process() の tick で発火する。
func _on_skill_effects_applied(results: Array) -> void:
	for r in results:
		if not (r is Dictionary):
			continue
		var target: BattleUnit = _find_unit_by_id(str(r.get("unit_id", "")))
		# 種類で色を分ける（EXEC_DAMAGE_POP_COLOR.md）。分岐はここ1箇所。
		# ⚠ is_heal を先に見る。将来 HoT（周期回復）が来ると is_heal と is_dot が
		#   両方立つが、回復として出すのが正しい。
		if bool(r.get("is_heal", false)):
			_pop_heal(target, int(r.get("amount", 0)))
		else:
			_pop_damage(
				target,
				int(r.get("amount", 0)),
				bool(r.get("is_crit", false)),
				bool(r.get("is_dot", false))
			)


# ============================================================
# チャージスキル
# ============================================================

func _on_charge_button_down(entry: Dictionary) -> void:
	if _session == null or _session.state != BattleSession.STATE_BATTLE_ACTIVE:
		return
	if not _charging.is_empty():
		return
	var user: BattleUnit = entry.get("user", null)
	var skill_id: String = str(entry.get("skill_id", ""))
	if user == null or not user.is_alive():
		return
	if not user.is_skill_ready(skill_id):
		return
	_charging = {"entry": entry, "time": 0.0}

	# trigger: "charge_start" の効果だけがここで発火する（PLAN 6-2）。
	# ⚠ 今は該当する効果を持つスキルが0件なので、実質何も起きない。
	#   本命の用途（チャージ中のダメージ軽減）は状態＝段階3。
	_skill_runtime.charge_start(user, skill_id, MasterDataLoader.get_skill(skill_id))


func _on_charge_button_up(entry: Dictionary) -> void:
	if _charging.is_empty():
		return
	if _charging.get("entry", null) != entry:
		return
	var t: float = float(_charging.get("time", 0.0))
	var user: BattleUnit = entry.get("user", null)
	var skill_id: String = str(entry.get("skill_id", ""))
	_charging.clear()
	# ⚠ until: "charge_end" の状態をここで剥がす。_cancel_charge() を通らない
	#   経路なので、あちらに書いても効かない（チャージが「成立」した側）。
	# ⚠ _fire_skill() より前に剥がす。チャージ中だけの状態が、チャージ後の
	#   一撃に乗らないようにする。
	if user != null and _status != null:
		_status.end_charge(user.unit_id)

	# ジャストかどうかは発動の前に確かめる。
	# 発動で敵が全滅すると、そのあとでは判定に使う情報が変わりうるため。
	var is_just: bool = _is_just(entry, t)
	_fire_skill(user, skill_id, _charge_power_ratio(entry, t))
	if is_just:
		_pop_just(user)


func _is_just(entry: Dictionary, t: float) -> bool:
	var charge: Dictionary = entry.get("charge", {})
	if charge.is_empty():
		return false
	var just_sec: float = float(charge.get("just_sec", 1.0))
	var window: float = float(charge.get("just_window_sec", 0.15))
	return absf(t - just_sec) <= window


# ジャスト成功を使用者の頭上に出す。
# 敵側のダメージ数値とは別に、撃った本人のところに出したいので
# _pop_damage とは経路を分けている。
func _pop_just(user: BattleUnit) -> void:
	if user == null:
		return
	if not _views_by_unit_id.has(user.unit_id):
		return
	var view: Node = _views_by_unit_id[user.unit_id]
	if is_instance_valid(view) and view.has_method("pop_just"):
		view.pop_just()


# チャージ中に戦闘が終わったり使用者が死んだら、発動せず取り消す。
# クールダウンも入らない。何も起きていないのに待たされる状態を作らないため。
func _tick_charge(delta: float) -> void:
	if _charging.is_empty():
		return
	var entry: Dictionary = _charging.get("entry", {})
	var user: BattleUnit = entry.get("user", null)
	if _session == null or _session.state != BattleSession.STATE_BATTLE_ACTIVE:
		_cancel_charge()
		return
	if user == null or not user.is_alive():
		_cancel_charge()
		return
	_charging["time"] = float(_charging.get("time", 0.0)) + delta


# チャージを取り消す。⚠ until: "charge_end" の状態もここで剥がす。
#
# ⚠ _charging を clear する前に、誰がチャージしていたかを読むこと。
#   clear してからでは剥がす相手が分からず、状態が永久に残る。エラーは出ない。
func _cancel_charge() -> void:
	var entry: Dictionary = _charging.get("entry", {})
	var user: BattleUnit = entry.get("user", null)
	if user != null and _status != null:
		_status.end_charge(user.unit_id)
	_charging.clear()


# チャージ時間から威力倍率を出す。
#
#   0秒            → min_ratio（既定 0.5）
#   just_sec まで  → min_ratio から 1.0 へ直線的に増加
#   ジャストの窓内 → just_bonus（既定 1.3）
#   窓を過ぎたあと → 1.0（何秒ためても変わらない。ためすぎの罰は無い）
func _charge_power_ratio(entry: Dictionary, t: float) -> float:
	var charge: Dictionary = entry.get("charge", {})
	if charge.is_empty():
		return 1.0

	var just_sec: float = float(charge.get("just_sec", 1.0))
	var window: float = float(charge.get("just_window_sec", 0.15))
	var min_ratio: float = float(charge.get("min_ratio", 0.5))
	var just_bonus: float = float(charge.get("just_bonus", 1.3))

	if absf(t - just_sec) <= window:
		return just_bonus
	if t > just_sec:
		return 1.0
	if just_sec <= 0.0:
		return 1.0
	return clampf(min_ratio + (1.0 - min_ratio) * (t / just_sec), min_ratio, 1.0)


# ============================================================
# ウェーブ進行・勝敗
# ============================================================

func _enter_wave_clear() -> void:
	_session.state = BattleSession.STATE_WAVE_CLEAR
	if _session.is_final_wave():
		_enter_victory()
		return
	_session.current_wave += 1
	_update_wave_label()
	# ⚠ 待ち行列は _reset_party_positions() より前に捨てる。あとだと、味方が
	#   左端へ瞬間移動したあとの距離で distance スケールの効果が計算される。
	#   捨てるのは正常な中断なので警告を出さない（PLAN 6-6）。
	_skill_runtime.clear_all()
	_clear_projectiles()
	# ⚠ 状態も捨てる。HP とクールダウンとは扱いが違う（引き継がない）。
	#   待ち行列と同じく _reset_party_positions() より前。
	_status.clear_all()
	# 節目の書き出し（EXEC_BATTLE_LOG.md §0）。ここまでのぶんをファイルへ落とす。
	BattleLog.flush()
	# 次ウェーブは味方を左端から再スタートさせる（HP とクールダウンは引き継ぐ）
	_reset_party_positions()
	_enter_wave_intro()


func _enter_victory() -> void:
	if _result_applied:
		return
	_result_applied = true
	_cancel_charge()
	# 勝利画面が出たあとにダメージ数値が出ないようにする。
	_skill_runtime.clear_all()
	_clear_projectiles()
	_status.clear_all()
	_session.state = BattleSession.STATE_VICTORY
	_consume_stage_stamina()

	var result_data: Dictionary = {
		GameStateKeys.BATTLE_VICTORY: true,
		GameStateKeys.BATTLE_WAVES_CLEARED: _session.total_waves,
		GameStateKeys.BATTLE_REWARDS: _stage_data.get("rewards", {}),
	}
	# ⚠ 報酬もクリア記録も story のときだけ（人間の決定・2026-08-17）。
	#   スタミナの消費（_consume_stage_stamina）が既に同じ判定をしている。
	#   検証用ステージは training で入るので、セーブに痕跡が残らない。
	#   ⚠ 結果画面は出す。出さないと勝ったのに何も起きない画面になる。
	if _session.stage_type == GameStateKeys.STAGE_TYPE_STORY:
		GameManager.apply_battle_rewards(result_data)
		GameManager.mark_stage_cleared(_stage_id, 0)

	_show_result(true, result_data)


# スタミナは勝ったときだけ消費する。
#
# 入場時は冒険選択画面が残量を確認するだけで、実際には減らしていない。
# 負けても減らないので、詰まったときに素材集めができなくなる詰みが起きない。
# 「もう一度」も勝つまでは無料であり、これは仕様。
#
# 消費量は冒険選択画面と同じ Balance.adventure から読む。
# 画面から転送データで受け取らないこと。値を1箇所で変えられる状態を保つため。
func _consume_stage_stamina() -> void:
	if _session == null:
		return
	# トレーニングは消費しない（現状は story のみ到達する）
	if _session.stage_type != GameStateKeys.STAGE_TYPE_STORY:
		return
	if Balance.adventure == null:
		push_warning("[Battle] Balance.adventure が未設定のためスタミナを消費しない")
		return
	var cost: int = int(Balance.adventure.stamina_cost_per_stage)
	if cost <= 0:
		return
	if not GameManager.spend_stamina(cost):
		# 入場時に残量を確認しているので通常は起きない。
		# 起きても報酬は取り消さない（勝った手応えを奪わない）。
		push_warning("[Battle] 勝利時のスタミナ消費に失敗した（cost=%d）" % cost)


func _enter_defeat() -> void:
	if _result_applied:
		return
	_result_applied = true
	_cancel_charge()
	_skill_runtime.clear_all()
	_clear_projectiles()
	_status.clear_all()
	_session.state = BattleSession.STATE_DEFEAT
	# apply_battle_rewards も mark_stage_cleared も呼ばない
	_show_result(false, {})


func _show_result(victory: bool, result_data: Dictionary) -> void:
	# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ ここは勝利と敗北の両方が通る唯一の場所。
	#   _enter_victory() / _enter_defeat() の2箇所に書かない。
	BattleLog.log_result(victory, _session.current_wave, _session.total_waves)
	BattleLog.flush()

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


func _on_retry_pressed() -> void:
	_result_applied = false
	result_view.hide()
	_init_session()
	_enter_wave_intro()


func _init_session() -> void:
	_stage_data = MasterDataLoader.get_stage(_stage_id)
	var total_waves: int = int(_stage_data.get("waves", []).size())
	var stage_type: String = GameStateKeys.STAGE_TYPE_STORY
	if _session != null:
		stage_type = _session.stage_type
	_views_by_unit_id.clear()
	_session = BattleSession.new(_stage_id, stage_type, _stage_data.get("party_id", ""), total_waves)
	# ⚠ セッションが作り直されるので新層にも差し替えを伝える。忘れると、リトライ後の
	#   スキルが「前の戦闘のユニット」を探して見つからず、1発も出なくなる。
	#   エラーは1つも出ない。
	# ⚠ 器を先に差し替えること。あとにすると SkillRuntime に古い器を渡す。
	#   器を差し替え忘れると、リトライ後の状態が前の戦闘のユニットを宿主に持ち、
	#   補正の組み直しが空振りする（こちらもエラーは出ない）。
	_status.reset(_session)
	_skill_runtime.reset(_session, _status)
	# ⚠ 待ち行列を捨てただけでは、飛んでいる矢のノードは残る。着弾しても
	#   待っている効果がもう無いので、無音で消えるだけの矢が前の戦闘から居座る。
	_clear_projectiles()
	_init_party_units()
	# ⚠ リトライでも呼び直す。忘れると前の戦闘の続きに見え、時計も戻らない。
	BattleLog.begin_battle(_stage_id, str(_stage_data.get("party_id", "")), total_waves)


func _on_back_pressed() -> void:
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")


# ============================================================
# デバッグ用（BattleDebugPanel から呼ばれる）
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


# 検証用：味方全員に「威力 power の一撃」を通す。
#
# take_damage(power) を直接呼ばないこと。通常攻撃と同じ BattleFormula を通すので、
# 物理なら def、魔法なら mdef で割られた値が入る。
# こうしないと「除算が効いているか」「mdef が生きているか」をここで確かめられない。
# 会心はしない（毎回同じ値が出ないと比較できないため）。
func debug_damage_party(power: int, attack_type: String) -> void:
	if _session == null:
		return
	for u in _session.party_units:
		if not (u is BattleUnit) or not u.is_alive():
			continue
		var unit: BattleUnit = u
		var defense: int = unit.get_defense(attack_type)
		# 第4引数（crit_dmg）は is_crit が false のとき使われない。
		var dmg: int = BattleFormula.damage(power, defense, 1.0, 0, false)
		unit.take_damage(dmg)
		_pop_damage(unit, dmg, false)
		# ログも画面と同じ名前で出す（party_0 だと誰か読み替えが要る）。
		print("[BattleDebug] %s に %s 威力%d → %d ダメージ（防御 %d）" % [
			tr(unit.unit_name_key), attack_type, power, dmg, defense
		])


func debug_reset_cooldowns() -> void:
	if _session == null:
		return
	for u in _session.party_units:
		if not (u is BattleUnit):
			continue
		for sid in u.skill_ids:
			u.start_cooldown(str(sid), 0.0)
	print("[BattleDebug] スキルのクールダウンをリセットした")


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
