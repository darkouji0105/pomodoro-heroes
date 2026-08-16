extends Control

# 状態の器（StatusRegistry・段階3の前半）の検証用シーン。
#
# 【なぜテストシーンが要るか】
# 状態の事故は全部無音。黙って剥がれる／二重に付く／消えない／最後の1発が落ちる。
# どれもエラーが出ず、しかも状態は画面にほとんど出ない（F3 パネルの3行目だけ）。
# 画面から確かめられないものを、ここで print に落とす。
#
# 【シーンツリーは要らない】
# StatusRegistry / BattleUnit / BattleSession / SkillResolver は全部 RefCounted。
# ノードに登録せず直接叩く。_ready() で全項目を回して結果を print する。
#
# 【時間の進め方】
# tick() に渡す delta は 0.5 / 1.0 / 2.0 など2進で誤差の出ない値だけを使う。
# 0.1 を60回足すと 5.999... になり、「ちょうど3回発火」の判定が
# テスト側の誤差で崩れる（器の不具合と区別できなくなる）。
#
# 【失敗の出し方】
# push_error を使わない。⚠ 最後の3項目は「赤が出るのが正解」なので、
# 失敗も赤で出すと正解の赤と混ざって読めなくなる。行頭の NG! で見る。

# 検証用ユニットの素の能力値。
# ⚠ crit_rate は 0。会心が抽選されるとダメージがフレームごとにぶれ、
#   「DoT が何回発火したか」を回数ではなく合計値で見たときに判定が揺れる。
# ⚠ hp は大きめ。DoT で宿主が死ぬと器が状態を捨ててしまい、
#   「発火回数」の検証が「宿主の死」の検証にすり替わる。
const TEST_STATS: Dictionary = {
	"hp": 9999, "atk": 20, "mag": 10, "def": 0, "mdef": 0,
	"atkspd": 0, "haste": 0, "crit_rate": 0, "crit_dmg": 150, "spd": 100,
}

# characters.json / enemies.json のエントリに相当するもの。
const TEST_SOURCE: Dictionary = {
	"name_key": "ui_common_ok",
	"attack_range": 100.0,
	"attack_interval_sec": 2.0,
	"attack_type": "physical",
}

var _pass_count: int = 0
var _fail_count: int = 0

# effects_applied で流れてきた発火結果の総数。_new_case() ごとに 0 に戻す。
var _fire_count: int = 0


func _ready() -> void:
	print("================================================")
	print("STATUS_REGISTRY: TEST START")
	print("================================================")

	_test_refresh_twice()
	_test_independent_twice()
	_test_refresh_by_other_source()
	_test_dot_6_by_2()
	_test_dot_4_by_2()
	_test_dot_5_by_2()
	_test_dot_big_delta()
	_test_dot_source_dead()
	_test_buff_host_dead()
	_test_stat_mods_and_restore()
	_test_rejected_inputs()

	print("================================================")
	print("STATUS_REGISTRY: TEST END  OK %d件 / NG %d件" % [_pass_count, _fail_count])
	print("================================================")


# ============================================================
# 検証（1項目 = 1関数）
# ============================================================

# stack: refresh を2回 … 1本のまま。寿命が最初の値に戻る。
func _test_refresh_twice() -> void:
	print("\n--- 1. stack: refresh を2回かける ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]

	_add(c, _buff({ "stack": "refresh", "duration_sec": 4.0 }))
	registry.tick(2.0)
	_add(c, _buff({ "stack": "refresh", "duration_sec": 4.0 }))

	_check("状態の本数", 1, registry.size())
	_check("寿命が戻る（elapsed）", "0.00", "%.2f" % _elapsed_at(registry, 0))
	_check("補正は二重に乗らない（atk）", 26, _host(c).get_stat(GameStateKeys.STAT_ATK))


# stack: independent を2回 … 2本になる。⚠ 寿命はそれぞれ別（同時に消えない）。
func _test_independent_twice() -> void:
	print("\n--- 2. stack: independent を2回かける ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]

	_add(c, _buff({ "stack": "independent", "duration_sec": 2.0 }))
	registry.tick(1.0)
	_add(c, _buff({ "stack": "independent", "duration_sec": 2.0 }))

	_check("状態の本数", 2, registry.size())
	_check("1本目の elapsed", "1.00", "%.2f" % _elapsed_at(registry, 0))
	_check("2本目の elapsed", "0.00", "%.2f" % _elapsed_at(registry, 1))
	_check("補正が2本分（atk 20+6+6）", 32, _host(c).get_stat(GameStateKeys.STAT_ATK))

	# 1本目だけが切れる時刻まで進める。
	registry.tick(1.0)
	_check("1本目だけ消える", 1, registry.size())
	_check("補正が1本分に戻る（atk）", 26, _host(c).get_stat(GameStateKeys.STAT_ATK))

	registry.tick(1.0)
	_check("2本目も消える", 0, registry.size())
	_check("補正が素に戻る（atk）", 20, _host(c).get_stat(GameStateKeys.STAT_ATK))


# 同じ status_id を別の付与者が refresh でかける … 2本になる
# （同一性のキーは 宿主・status_id・付与者 の3つ組）。
func _test_refresh_by_other_source() -> void:
	print("\n--- 3. 同じ status_id を別の付与者が refresh でかける ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]

	# 2人目の付与者を味方に足す。
	var second: BattleUnit = BattleUnit.create("party_1", BattleUnit.TEAM_PARTY, TEST_SOURCE, TEST_STATS)
	c["session"].party_units.append(second)

	registry.add(_buff({ "stack": "refresh", "duration_sec": 4.0 }), c["source"], _host(c), c["session"])
	registry.add(_buff({ "stack": "refresh", "duration_sec": 4.0 }), second, _host(c), c["session"])

	_check("状態の本数", 2, registry.size())
	_check("補正が2本分（atk 20+6+6）", 32, _host(c).get_stat(GameStateKeys.STAT_ATK))


# duration 6 × interval 2 … ちょうど3回発火。
func _test_dot_6_by_2() -> void:
	print("\n--- 4. dot: duration 6 × interval 2 ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	_add(c, _dot({ "duration_sec": 6.0, "interval_sec": 2.0 }))

	_check("fires_total", 3, int(registry.snapshot()[0].get("fires_total", 0)))
	_tick_by(registry, 0.5, 12)   # 合計 6.0 秒
	_check("発火した回数", 3, _fire_count)
	_check("寿命が切れて消える", 0, registry.size())


# ⚠ duration 4 × interval 2 … 2回発火。最後の1発と寿命切れが同じフレームに来る。
#   発火を寿命切れより先にやっていないと、最後の1発が黙って落ちる。
func _test_dot_4_by_2() -> void:
	print("\n--- 5. dot: duration 4 × interval 2（最後の1発が落ちないこと） ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	_add(c, _dot({ "duration_sec": 4.0, "interval_sec": 2.0 }))

	_check("fires_total", 2, int(registry.snapshot()[0].get("fires_total", 0)))
	_tick_by(registry, 0.5, 8)   # 合計 4.0 秒
	_check("発火した回数", 2, _fire_count)
	_check("寿命が切れて消える", 0, registry.size())


# ⚠ duration 5 × interval 2 … 2回発火（端数は切り捨て）。
func _test_dot_5_by_2() -> void:
	print("\n--- 6. dot: duration 5 × interval 2（端数は切り捨て） ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	_add(c, _dot({ "duration_sec": 5.0, "interval_sec": 2.0 }))

	_check("fires_total", 2, int(registry.snapshot()[0].get("fires_total", 0)))
	_tick_by(registry, 0.5, 10)   # 合計 5.0 秒
	_check("発火した回数", 2, _fire_count)
	_check("寿命が切れて消える", 0, registry.size())


# ⚠ 1フレームに大きい delta（速度8倍相当）… 跨いだぶんが全部発火する。
#   発火が if だと1回しか出ず、速度を上げるほど総ダメージが減る。
func _test_dot_big_delta() -> void:
	print("\n--- 7. dot: 1フレームに 6.0 秒ぶんの delta を渡す ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	_add(c, _dot({ "duration_sec": 6.0, "interval_sec": 2.0 }))

	registry.tick(6.0)
	_check("発火した回数（1フレームで3回）", 3, _fire_count)
	_check("寿命が切れて消える", 0, registry.size())


# ⚠ 付与者を殺してから tick … DoT は止まらない（SkillRuntime と正反対）。
func _test_dot_source_dead() -> void:
	print("\n--- 8. 付与者を殺してから tick（DoT が止まらないこと） ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	var source: BattleUnit = c["source"]
	_add(c, _dot({ "duration_sec": 6.0, "interval_sec": 2.0 }))

	source.take_damage(source.hp)
	_check("付与者は死んでいる", false, source.is_alive())

	_tick_by(registry, 0.5, 12)
	_check("発火した回数（死んでも止まらない）", 3, _fire_count)


# ⚠ 宿主を殺してから tick … 状態が消え、補正も消える。
func _test_buff_host_dead() -> void:
	print("\n--- 9. 宿主を殺してから tick（状態も補正も消えること） ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	var host: BattleUnit = _host(c)
	_add(c, _buff({ "stack": "refresh", "duration_sec": 10.0 }))
	_check("死ぬ前の atk", 26, host.get_stat(GameStateKeys.STAT_ATK))

	host.take_damage(host.hp)
	registry.tick(0.5)

	_check("状態が消える", 0, registry.size())
	# ⚠ 素の値に戻ること。get_stat() は 0 で切るので、hp 0 でも atk は 20 のまま。
	_check("補正が消える（atk）", 20, host.get_stat(GameStateKeys.STAT_ATK))


# set_stat_mods() 後の get_stat() / attack_interval_sec が変わり、剥がすと元に戻る。
# ⚠ atkspd のバフで攻撃間隔が累積して速くならないことを見る（_base_attack_interval_sec）。
func _test_stat_mods_and_restore() -> void:
	print("\n--- 10. atkspd バフの攻撃間隔（剥がして元に戻ること） ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]
	var host: BattleUnit = _host(c)

	var base_interval: String = "%.4f" % host.attack_interval_sec

	# atkspd +100 → 攻撃間隔は半分。
	var effect: Dictionary = _buff({ "stack": "refresh", "duration_sec": 2.0 })
	effect["stat"] = GameStateKeys.STAT_ATKSPD
	effect["value"] = 100
	registry.add(effect, c["source"], host, c["session"])

	_check("atkspd", 100, host.get_stat(GameStateKeys.STAT_ATKSPD))
	_check("攻撃間隔が半分", "1.0000", "%.4f" % host.attack_interval_sec)

	# もう一度かけ直しても（refresh）さらに速くならない。
	registry.add(effect, c["source"], host, c["session"])
	_check("かけ直しても累積しない", "1.0000", "%.4f" % host.attack_interval_sec)

	registry.tick(2.0)
	_check("剥がれた", 0, registry.size())
	_check("atkspd が素に戻る", 0, host.get_stat(GameStateKeys.STAT_ATKSPD))
	_check("攻撃間隔が元に戻る", base_interval, "%.4f" % host.attack_interval_sec)


# ロード時検証を通り抜けた不正な効果を器が弾くこと。
# ⚠ この3項目は赤（push_error）が3本出るのが正解。器が黙って受け取ったら NG。
func _test_rejected_inputs() -> void:
	print("\n--- 11-13. 弾かれること（⚠ 赤が3本出るのが正解） ---")
	var c: Dictionary = _new_case()
	var registry: StatusRegistry = c["registry"]

	var hp_buff: Dictionary = _buff({ "stack": "refresh", "duration_sec": 4.0 })
	hp_buff["stat"] = GameStateKeys.STAT_HP
	_check("11. stat: hp の buff は付かない", false, registry.add(hp_buff, c["source"], _host(c), c["session"]))

	var no_stack: Dictionary = _buff({ "duration_sec": 4.0 })
	_check("12. stack を書かない buff は付かない", false, registry.add(no_stack, c["source"], _host(c), c["session"]))

	var both: Dictionary = _buff({ "stack": "refresh", "duration_sec": 4.0 })
	both["until"] = SkillSchema.UNTIL_CHARGE_END
	_check("13. duration_sec と until の両方は付かない", false, registry.add(both, c["source"], _host(c), c["session"]))

	_check("器は空のまま", 0, registry.size())


# ============================================================
# 道具
# ============================================================

# 1項目ぶんの場を作る。⚠ 項目ごとに作り直すこと。
#   1つの器を使い回すと、前の項目の残りが次の項目の本数に混ざる。
#
# セッションは空の器でよい（stage / wave の中身は器が読まない）。
# 付与者を味方（party_0）、宿主を敵（enemy_0）に置く。
func _new_case() -> Dictionary:
	var session: BattleSession = BattleSession.new("test_stage", "story", "test_party", 1)
	var source: BattleUnit = BattleUnit.create("party_0", BattleUnit.TEAM_PARTY, TEST_SOURCE, TEST_STATS)
	var host: BattleUnit = BattleUnit.create("enemy_0", BattleUnit.TEAM_ENEMY, TEST_SOURCE, TEST_STATS)
	session.party_units.append(source)
	session.enemy_units.append(host)

	var registry: StatusRegistry = StatusRegistry.new(session)
	_fire_count = 0
	registry.effects_applied.connect(_on_effects_applied)

	return { "session": session, "source": source, "host": host, "registry": registry }


func _host(c: Dictionary) -> BattleUnit:
	return c["host"]


func _add(c: Dictionary, effect: Dictionary) -> bool:
	return (c["registry"] as StatusRegistry).add(effect, c["source"], _host(c), c["session"])


# dot の発火はここに流れてくる。件数だけ数える（中身は damage の検証の担当）。
func _on_effects_applied(results: Array) -> void:
	_fire_count += results.size()


# 検証用の buff。overrides で stack / duration_sec / until を足す。
# stat は atk、value は +6（TEST_STATS の atk 20 に対して 26 になる）。
func _buff(overrides: Dictionary) -> Dictionary:
	var effect: Dictionary = {
		"type": SkillSchema.EFFECT_BUFF,
		"host": SkillSchema.HOST_UNIT,
		"status_id": "test_buff",
		"stat": GameStateKeys.STAT_ATK,
		"value": 6,
	}
	for key: Variant in overrides:
		effect[key] = overrides[key]
	return effect


# 検証用の dot。stack は independent（同じ項目で2本並べても潰れないように）。
# multiplier 0.5 × atk 20 ÷ (def 0) → 1発 10 ダメージ。
func _dot(overrides: Dictionary) -> Dictionary:
	var effect: Dictionary = {
		"type": SkillSchema.EFFECT_DOT,
		"host": SkillSchema.HOST_UNIT,
		"status_id": "test_dot",
		"stack": SkillSchema.STACK_INDEPENDENT,
		"multiplier": 0.5,
		"attack_type": BattleUnit.ATTACK_TYPE_PHYSICAL,
		"scale_from": GameStateKeys.STAT_ATK,
	}
	for key: Variant in overrides:
		effect[key] = overrides[key]
	return effect


# delta を count 回。⚠ delta には 0.5 / 1.0 など2進で誤差の出ない値だけを渡す。
func _tick_by(registry: StatusRegistry, delta: float, count: int) -> void:
	for _i in range(count):
		registry.tick(delta)


func _elapsed_at(registry: StatusRegistry, index: int) -> float:
	var entries: Array = registry.snapshot()
	if index < 0 or index >= entries.size():
		return -1.0
	return float((entries[index] as Dictionary).get("elapsed", 0.0))


# ⚠ 期待値と実測を必ず両方出す。「OK」だけにすると、比較そのものが
#   合っているかを人間が確かめられない。
func _check(label: String, expected: Variant, actual: Variant) -> void:
	var ok: bool = str(expected) == str(actual)
	if ok:
		_pass_count += 1
	else:
		_fail_count += 1
	# ⚠ 三項演算子を書式の中に混ぜないこと。`"..." % A if ok else B` は
	#   `("..." % A) if ok else B` と解釈され、失敗したときだけ配列がそのまま出る。
	var mark: String = "OK " if ok else "NG!"
	print("  %s %s | 期待 %s / 実測 %s" % [mark, label, str(expected), str(actual)])
