extends Node

# ============================================================
# 検証用の起動口。⚠ シーンは1個だけ。
#
# ⚠ 検証専用。リリース前に消す（NEXT_STEPS §6 の片付け）。
# ⚠ 本番コードから呼ばないこと。scenes/ と autoload/ と scripts/ には1行も足していない。
#
# 使い方（ヘッドレス）：
#   godot --headless --path d:\pomodoro-heroes res://tests/debug_boot.tscn -- scenario=area
#
# ⚠ 引数を付けないとシナリオ名の一覧を出して終わる。
#   既定のシナリオを作らないのは、「どれを見たのか」が後から分からなくなるため
#   （skill_schema の origin に既定値を作らなかったのと同じ理由）。
#
# ⚠ 検証したい形が増えたら SCENARIOS に1行足す。シーンもスクリプトも増やさないこと。
#   増やしたくなったら、それは設計が間違っている合図（tests/ には既にデバッグ用が9件ある）。
# ============================================================

const SCENE_BATTLE: String = "res://scenes/adventure/battle.tscn"

# シナリオの種類。
# ⚠ screen は窓あり専用。ヘッドレスでは描画がダミーなので何も分からない。
const KIND_BATTLE: String = "battle"
const KIND_SCREEN: String = "screen"

# 撃つ前の下ごしらえ。
# ⚠ damage_party は「回復を検証するとき、味方が満タンだと回復量0で何も起きない」を潰すもの
#   （④-a で hp: 9999 に条件を書いて踏んだのと同じ形）。
const PREPARE_NONE: String = ""
const PREPARE_DAMAGE_PARTY: String = "damage_party"


const SCENARIOS: Dictionary = {
	# 段階4（mode: area）の検証。EXEC_SKILL_AREA.md §6 の数字をそのまま見る。
	"area": {
		"kind": KIND_BATTLE,
		"note": "範囲攻撃。narrow=2体 / wide=4体 / far=4体 / heal=味方3体",
		"stage_id": "stage_dbg_area",
		# ⚠ 編成は状態が唯一の正。stages.json の party_id では決まらない
		#   （battle_session.gd:19 / battle_controller.gd:176）。
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		# ⚠ スキル枠は2つ（SKILL_SLOT_COUNT=2）。段階4はここの押し忘れで1回ぶん溶けている。
		"skills": {
			"char_debug_mix": ["skill_dbg_area_narrow", "skill_dbg_area_wide"],
			"char_debug_life": ["skill_dbg_area_far", "skill_dbg_area_heal"],
		},
		# ⚠ 撃つ順。1つずつ間を空ける（同じ t に重なると、巻き込んだ数を
		#   「同じ t の damage の行数」で数えられなくなる）。
		"fire": [
			{"skill": "skill_dbg_area_narrow", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_wide", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_far", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_heal", "prepare": PREPARE_DAMAGE_PARTY},
		],
	},
	# 画面をいきなり開くだけのシナリオ。⚠ 窓あり専用。
	"training": {
		"kind": KIND_SCREEN,
		"note": "育成画面をいきなり開く（拠点→ギルド→育成を辿らない）",
		"scene": "res://scenes/guild/training_screen.tscn",
	},
}


func _ready() -> void:
	var scenario_name: String = _read_scenario_name()
	if not SCENARIOS.has(scenario_name):
		_print_usage(scenario_name)
		get_tree().quit()
		return

	var scenario: Dictionary = SCENARIOS[scenario_name]
	print("[DebugBoot] scenario=%s : %s" % [scenario_name, str(scenario.get("note", ""))])

	# ⚠ 状態は書き換えるが、絶対に保存しない。
	#   set_party_member() / select_skill() は本物の状態を触るので、保存すると
	#   人間の編成とスキル枠が黙って変わる。SaveManager をこのファイルから呼ばないこと。
	_apply_party(scenario)
	_apply_skills(scenario)

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_SCREEN:
		print("[DebugBoot] kind=screen（⚠ 窓あり専用。ヘッドレスでは何も分からない）")
		# ⚠ battle の枝と同じ理由で call_deferred。_ready() の中から遷移すると
		#   今のシーン（＝自分）を外す remove_child() が弾かれる。
		#   ⚠ 片方だけ直して片方を忘れた（2026-08-18）。枝が2つあることを忘れないこと。
		SceneManager.change_scene.call_deferred(str(scenario.get("scene", "")))
		return

	# ⚠ change_scene すると今のシーン（＝自分）は消えるので、撃つ役を root に残す。
	#   SceneManager が DebugOverlay を root に足しているのと同じ形（scene_manager.gd:29-34）。
	var driver: Driver = Driver.new()
	driver.name = "DebugBootDriver"
	driver.battle_scene_path = SCENE_BATTLE
	driver.skill_plan = scenario.get("fire", [])
	# ⚠ call_deferred なのは、_ready() の時点では root が子を組み立てている最中で
	#   add_child() が弾かれるため（"Parent node is busy setting up children"）。
	#   SceneManager が DebugOverlay を足すときに call_deferred しているのと同じ理由。
	get_tree().root.add_child.call_deferred(driver)

	# ⚠ 遷移も call_deferred。_ready() の中から呼ぶと、今のシーン（＝自分）を外す
	#   remove_child() が root の組み立て中に当たって弾かれる。
	SceneManager.change_scene_with_data.call_deferred(SCENE_BATTLE, {
		TransferKeys.STAGE_ID: str(scenario.get("stage_id", "")),
		TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
	})


# --- 起動引数 --------------------------------------------------

# `-- scenario=area` の形で受け取る。
# ⚠ コードを書き換えずに切り替えられることが要件。定数を書き換える運用にしない。
func _read_scenario_name() -> String:
	var args: Array = []
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for raw in args:
		var arg: String = str(raw)
		if arg.begins_with("scenario="):
			return arg.substr("scenario=".length())
		if arg.begins_with("--scenario="):
			return arg.substr("--scenario=".length())
	return ""


func _print_usage(given: String) -> void:
	if given == "":
		print("[DebugBoot] scenario が指定されていない")
	else:
		print("[DebugBoot] 知らない scenario: %s" % given)
	print("[DebugBoot] 使い方: -- scenario=<名前>")
	for key in SCENARIOS.keys():
		var scenario: Dictionary = SCENARIOS[key]
		print("[DebugBoot]   %s [%s] %s" % [
			str(key), str(scenario.get("kind", "")), str(scenario.get("note", ""))
		])


# --- 下ごしらえ ------------------------------------------------

func _apply_party(scenario: Dictionary) -> void:
	var members: Array = scenario.get("party", [])
	for i: int in range(members.size()):
		var character_id: String = str(members[i])
		if not GameManager.set_party_member(i, character_id):
			push_error("[DebugBoot] set_party_member(%d, '%s') が false" % [i, character_id])
	print("[DebugBoot] party=%s" % str(GameManager.get_party_members()))


func _apply_skills(scenario: Dictionary) -> void:
	var table: Dictionary = scenario.get("skills", {})
	for raw_character_id in table.keys():
		var character_id: String = str(raw_character_id)
		var skill_ids: Array = table[raw_character_id]
		for slot: int in range(skill_ids.size()):
			# ⚠ 既に同じ枠に入っている場合は false が返るが、それは正常
			#   （game_manager.gd:2168 の "already in this slot"）。
			GameManager.select_skill(character_id, slot, str(skill_ids[slot]))


# ============================================================
# 撃つ役。画面遷移で消えないよう root に付く。
# ⚠ 本番のノードを1つも作らない。見るだけ・呼ぶだけ。
# ============================================================
class Driver extends Node:

	# 撃つ間隔。⚠ これは「配置が整ったか」の合図ではなく、単なる間隔。
	#   同じ t に重なると「巻き込んだ数＝同じ t の damage の行数」が数えられなくなるため。
	const FIRE_GAP_SEC: float = 1.0
	# 決着してからログが出揃うまでの余裕。
	const SETTLE_SEC: float = 1.0
	# ⚠ 合図が来ないまま戦闘が長引いたら諦める（ヘッドレスがぶら下がったままにならないように）。
	const GIVE_UP_SEC: float = 180.0
	# 回復の検証で味方を削る量。⚠ BattleFormula を通るので def で割られる。
	const PREPARE_DAMAGE_POWER: int = 500

	var battle_scene_path: String = ""
	var skill_plan: Array = []

	# ⚠ battle_controller.gd に class_name が無いので型を付けられない。
	#   ここは検証用スクリプトなので許容する。本番コードでこの書き方をしないこと
	#   （AGENTS.md「エラーを理由にルールを緩めない」）。
	# 「止まった」とみなす1フレームの移動量と、その状態が続くべき長さ。
	const STILL_EPSILON: float = 0.5
	const STILL_HOLD_SEC: float = 0.5

	var _battle = null
	var _fired: int = 0
	var _last_fire_sec: float = -999.0
	var _signal_seen: bool = false
	var _prev_enemy_x: Dictionary = {}
	var _still_sec: float = 0.0
	var _prepared: Dictionary = {}
	var _killed: bool = false
	var _finished_sec: float = -1.0


	func _process(delta: float) -> void:
		if _battle == null:
			_battle = _find_battle()
			if _battle == null:
				return
			print("[DebugBoot] 戦闘画面をつかんだ")

		var session: BattleSession = _battle.get_session()
		if session == null:
			return

		# 決着した。ログが出揃うまで少し待ってから終わる。
		if session.state == BattleSession.STATE_VICTORY \
				or session.state == BattleSession.STATE_DEFEAT:
			if _finished_sec < 0.0:
				_finished_sec = 0.0
				print("[DebugBoot] 決着 state=%s t=%.2f" % [session.state, session.elapsed_sec])
			_finished_sec += delta
			if _finished_sec >= SETTLE_SEC:
				print("[DebugBoot] 終了")
				get_tree().quit()
			return

		if session.elapsed_sec > GIVE_UP_SEC:
			push_error("[DebugBoot] %.0f 秒たっても終わらないので諦める（撃った数=%d/%d）" % [
				GIVE_UP_SEC, _fired, skill_plan.size()
			])
			get_tree().quit()
			return

		if _fired < skill_plan.size():
			_step_fire(session, delta)
			return

		# 撃ち終わった。⚠ このステージは放っておいても終わらない（敵 hp 400 / 味方の火力が低い）ので、
		#   ログに result の行を出すために決着させる。
		if not _killed and session.elapsed_sec - _last_fire_sec >= SETTLE_SEC:
			_killed = true
			print("[DebugBoot] 撃ち終わったので決着させる")
			_battle.debug_kill_all_enemies()


	func _step_fire(session: BattleSession, delta: float) -> void:
		# ⚠ 合図は時間で書かない。「敵が動くのをやめた」＝全員が射程ぴったりの位置に落ち着いた。
		#   段階4では t=2.32 で撃ってしまい、狼が歩いている途中で敵4体が固まっていたため
		#   radius:150 でも4体入って判定できなかった（EXEC_SKILL_AREA.md §2-2）。
		#
		# ⚠ 「味方が殴られたら」では足りない。実測で、最初に殴ってきたのは射程300の置物
		#   （enemy_dbg_ranged）で、狼はまだ歩いていた。殴られたことは配置を保証しない。
		if not _signal_seen:
			if not _enemies_settled(session, delta):
				return
			_signal_seen = true
			print("[DebugBoot] 合図：敵が動くのをやめた t=%.2f" % session.elapsed_sec)
			return

		if session.elapsed_sec - _last_fire_sec < FIRE_GAP_SEC:
			return

		var entry: Dictionary = skill_plan[_fired]
		var skill_id: String = str(entry.get("skill", ""))

		# 撃つ前の下ごしらえ（回復のために味方を削る等）。1回だけ。
		if str(entry.get("prepare", "")) == "damage_party" and not _prepared.has(skill_id):
			_prepared[skill_id] = true
			print("[DebugBoot] 下ごしらえ：味方を削る（%s の前）" % skill_id)
			_battle.debug_damage_party(PREPARE_DAMAGE_POWER, BattleUnit.ATTACK_TYPE_PHYSICAL)
			return

		var user: BattleUnit = _find_user(session, skill_id)
		if user == null:
			push_error("[DebugBoot] %s を持っているユニットが居ない（スキル枠の割り当てを見ること）" % skill_id)
			_fired += 1
			return

		# ⚠ 戻り値は「撃てたか」。false ならクールダウン中か対象0体なので、次のフレームで試し直す。
		#   「押したつもりで撃てていない」がここで検出できる。
		if not _battle._fire_skill(user, skill_id, 1.0):
			return

		_fired += 1
		_last_fire_sec = session.elapsed_sec
		print("[DebugBoot] 撃った %s（%s） t=%.2f  %d/%d" % [
			skill_id, user.unit_id, session.elapsed_sec, _fired, skill_plan.size()
		])


	func _find_battle():
		var current: Node = get_tree().current_scene
		if current == null:
			return null
		if current.scene_file_path != battle_scene_path:
			return null
		return current


	# 生きている敵全員の x が STILL_HOLD_SEC のあいだ動かなかったか。
	# ⚠ ユニットは「距離 <= attack_range」で止まる（battle_controller.gd:601-627）ので、
	#   止まった＝全員が狙う相手の射程ぴったりに落ち着いた、という意味になる。
	func _enemies_settled(session: BattleSession, delta: float) -> bool:
		var moved: bool = false
		var current: Dictionary = {}
		for u in session.enemy_units:
			if not (u is BattleUnit) or not u.is_alive():
				continue
			current[u.unit_id] = u.x
			if _prev_enemy_x.has(u.unit_id) \
					and absf(float(_prev_enemy_x[u.unit_id]) - u.x) > STILL_EPSILON:
				moved = true

		var had_sample: bool = not _prev_enemy_x.is_empty()
		_prev_enemy_x = current

		if moved or current.is_empty() or not had_sample:
			_still_sec = 0.0
			return false

		_still_sec += delta
		return _still_sec >= STILL_HOLD_SEC


	func _find_user(session: BattleSession, skill_id: String) -> BattleUnit:
		for u in session.party_units:
			if u is BattleUnit and u.is_alive() and skill_id in u.skill_ids:
				return u
		return null
