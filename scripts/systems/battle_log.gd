class_name BattleLog
extends RefCounted

# 戦闘中の出来事を1行1イベント（JSON Lines）でファイルに落とす静的クラス。
# EXEC_BATTLE_LOG.md
#
# 【なぜ静的クラスか】
# SkillRuntime / SkillResolver / StatusRegistry は RefCounted でノードツリーを
# 知らない（契約）。静的クラスならその3層からも battle_controller からも
# 同じ呼び方で書けて、契約に触れずに済む。
# ⚠ Autoload にしない（AGENTS.md：6つ以外は人間の承認が要る）。
#
# 【なぜ JSON Lines か】
# 配列1本にすると、途中でクラッシュしたときに全部読めなくなる。
# 落ちた戦闘こそ読みたいので、1行ずつ完結させる。
#
# ⚠ 検証用。リリース前にこのファイルごと消す（宿題16）。
# ⚠ tr() を呼ばないこと（静的関数からは呼べない・AGENTS.md）。画面には出さない。

# ⚠ リリース前に false にしてから、ファイルごと消す。
const ENABLED: bool = true

const DIR_PATH: String = "user://logs/"
const FILE_PATH: String = DIR_PATH + "battle_last.jsonl"

# 未書き出しがこれを超えたら自動で flush する。
# ⚠ 節目（ウェーブ交代・戦闘終了）だけにすると、1波の途中で落ちたときに
#   その波の記録が丸ごと消える。
const FLUSH_THRESHOLD: int = 200

# F3 パネルの O キー。const と AND を取る（両方が on のときだけ書く）。
static var _runtime_on: bool = true

# 未書き出しの行。1要素＝1行のJSON文字列。
static var _buffer: Array[String] = []

# 戦闘中の経過秒。⚠ 実時間ではない。battle_controller が advance() で進める。
static var _t: float = 0.0

# この戦闘で1度でもファイルを開いたか。初回だけ空にしてから書く。
static var _truncated: bool = false


# ============================================================
# 出入口
# ============================================================

static func is_on() -> bool:
	return ENABLED and _runtime_on


# 戦闘の開始。時計を0に戻し、ファイルを空にしてから1行目を書く。
# ⚠ リトライでも呼ぶこと。忘れると前の戦闘の続きに見える。
static func begin_battle(stage_id: String, party_id: String, total_waves: int) -> void:
	_buffer.clear()
	_t = 0.0
	_truncated = false
	if not is_on():
		return
	print("[BattleLog] %s -> %s" % [FILE_PATH, ProjectSettings.globalize_path(FILE_PATH)])
	write("battle_start", {
		"stage": stage_id,
		"party": party_id,
		"waves": total_waves,
	})


# 時計を進める。⚠ 呼ぶのは battle_controller._process() の戦闘中だけ。
# Time.get_ticks_msec() を使わないこと。速度8倍のとき中の時計とズレる。
static func advance(delta: float) -> void:
	_t += delta


static func now() -> float:
	return _t


# F3 パネルの O キー。切り替えた後の状態を返す。
# ⚠ off にする前に flush する。途中で終わったファイルを残さないため。
static func set_runtime_on(on: bool) -> void:
	if not on and _runtime_on:
		flush()
	_runtime_on = on
	print("[BattleLog] 記録 %s" % ("on" if is_on() else "off"))


# ============================================================
# 書く
# ============================================================

# 1件を溜める。⚠ ここでは FileAccess を開かない（毎フレーム開くと重い）。
static func write(ev: String, fields: Dictionary) -> void:
	if not is_on():
		return
	var row: Dictionary = { "t": snappedf(_t, 0.01), "ev": ev }
	for key: Variant in fields:
		row[key] = fields[key]
	# ⚠ sort_keys を false にすること。既定の true だとキーがアルファベット順に
	#   並び替えられ、t と ev が行の途中に埋もれて目で追えなくなる。
	_buffer.append(JSON.stringify(row, "", false))
	if _buffer.size() >= FLUSH_THRESHOLD:
		flush()


# 溜めた行を追記して配列を空にする。
static func flush() -> void:
	if _buffer.is_empty():
		return
	if not ENABLED:
		_buffer.clear()
		return

	if not DirAccess.dir_exists_absolute(DIR_PATH):
		DirAccess.make_dir_recursive_absolute(DIR_PATH)

	# 初回は WRITE（＝前の戦闘の内容を捨てる）。以降は末尾へ追記する。
	var file: FileAccess = null
	if _truncated:
		file = FileAccess.open(FILE_PATH, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		# ⚠ 書けないまま溜め続けるとメモリを食う。捨てて先へ進む。
		push_warning("[BattleLog] 書き出せない: %s (%d件を捨てる)" % [FILE_PATH, _buffer.size()])
		_buffer.clear()
		return

	_truncated = true
	for line: String in _buffer:
		file.store_line(line)
	file.close()
	_buffer.clear()


# ============================================================
# 出来事ごとの入口（差し込み先を1行で済ませるため）
# ============================================================

# phase … 段（activation: recast）の番号。
# ⚠ 既定の -1 では欄を出さない。phases を書いていない既存スキルの行が
#   1バイトも変わらないようにするため（段階1〜4の完了条件をそのまま検証できる）。
static func log_cast(unit_id: String, skill_id: String, target_ids: Array, phase: int = -1) -> void:
	if not is_on():
		return
	var fields: Dictionary = {
		"unit": unit_id,
		"skill": skill_id,
		"targets": _to_id_array(target_ids),
	}
	if phase >= 0:
		fields["phase"] = phase
	write("cast", fields)


# 構えの出来事（activation: recast・段階5）。
#
# ⚠ 窓切れ（why: "expire"）も死亡（why: "death"）も、画面にも damage にも
#   何も出ない。記録が無いと「そのまま終わった」のか「2段目を撃ち損ねた」のかを
#   後から区別できない。
# why … "begin"（構えた） / "expire"（窓が切れた） / "death"（死んで捨てた）
static func log_recast(unit_id: String, skill_id: String, phase: int, why: String) -> void:
	if not is_on():
		return
	write("recast", {
		"unit": unit_id,
		"skill": skill_id,
		"phase": phase,
		"why": why,
	})


# 召喚の出来事（type: "summon"・段階6）。
#
# ⚠ 期限切れ（why: "expire"）も召喚者の死亡（why: "owner_death"）も、
#   画面には「四角が消える」しか出ない。記録が無いと、消えた理由を
#   設計役が区別できない（構え＝recast の log_recast と同じ理由）。
# ⚠ x を出すこと。座標の規則（offset_x の符号と等間隔）はログでしか検証できない。
# why … "begin" / "expire" / "owner_death" / "death"
static func log_spawn(owner_id: String, unit_id: String, source_id: String, x: float, why: String) -> void:
	if not is_on():
		return
	write("spawn", {
		"owner": owner_id,
		"unit": unit_id,
		"src": source_id,
		"x": snappedf(x, 0.01),
		"why": why,
	})


# ルーンが1件発動した（段階8・GAME_DESIGN.md 7-5）。
#
# ⚠ 効果そのものは SkillRuntime.cast() を通るので cast / status_add / heal が
#   別に出る。ここで出すのは「どのスキルの直前に、どのルーンが乗ったか」だけ。
# ⚠ 移動系は cast を通らないので、この行が唯一の記録になる。move には
#   符号つきの距離が入る（0 なら移動系ではない）。
static func log_rune(unit_id: String, rune_id: String, skill_id: String, move: int, x: float) -> void:
	if not is_on():
		return
	write("rune", {
		"unit": unit_id,
		"rune": rune_id,
		"skill": skill_id,
		"move": move,
		"x": snappedf(x, 0.01),
	})


# SkillResolver が返す results を damage / heal / dot に振り分ける。
#
# ⚠ results の形を知る場所をここ1箇所に閉じる（3つの差し込み先に同じループを
#   書かない）。形は { "unit_id", "amount", "is_heal", "is_crit",
#   "source_unit_id", "attack_type" }。後ろ2つはダメージのときだけ。
#
# src_fallback   … source_unit_id が無いとき（回復）に使う撃った側のID
# dot_status_id  … 空でなければ damage の代わりに dot を出す
static func log_results(results: Array, src_fallback: String, dot_status_id: String = "") -> void:
	if not is_on() or results.is_empty():
		return
	for raw: Variant in results:
		if not (raw is Dictionary):
			continue
		var r: Dictionary = raw as Dictionary
		# ⚠ kind を持つ1件は damage / heal ではない（段階6の召喚）。ここで弾かないと
		#   amount: 0 の damage の行が出る。記録は _spawn_summon() が log_spawn() で出す。
		if r.has("kind"):
			continue
		var src: String = str(r.get("source_unit_id", ""))
		if src == "":
			src = src_fallback
		if bool(r.get("is_heal", false)):
			# ⚠ 回復には crit も attack_type も無い。無い欄を出さない。
			write("heal", {
				"src": src,
				"dst": str(r.get("unit_id", "")),
				"amount": int(r.get("amount", 0)),
			})
		elif dot_status_id != "":
			write("dot", {
				"status": dot_status_id,
				"src": src,
				"dst": str(r.get("unit_id", "")),
				"amount": int(r.get("amount", 0)),
			})
		else:
			write("damage", {
				"src": src,
				"dst": str(r.get("unit_id", "")),
				"amount": int(r.get("amount", 0)),
				"crit": bool(r.get("is_crit", false)),
				"atk_type": str(r.get("attack_type", "")),
			})


static func log_react(
		status_id: String, event_name: String, host_unit_id: String,
		source_unit_id: String, effect_count: int
) -> void:
	if not is_on():
		return
	write("react", {
		"status": status_id,
		"event": event_name,
		"unit": host_unit_id,
		"src": source_unit_id,
		"effects": effect_count,
	})


# 条件の真偽（PLAN 10章の3つ目の発火源）。
#
# ⚠ 呼ぶのは「付いたとき」と「真偽が変わったとき」だけ。毎フレーム呼ぶと
#   1戦で数万行になる（位置・移動を出さないのと同じ理由・§2-4）。
# ⚠ 付いた時点（why: "add"）を必ず出すこと。出さないと「一度も真にならなかった」
#   のか「最初から常に真だった」のかがログから区別できない。どちらも無音の事故。
#
# why … "add"（付いた時点）／ "change"（真偽が変わった）
static func log_condition(
		status_id: String, host_unit_id: String, active: bool, why: String
) -> void:
	if not is_on():
		return
	write("condition", {
		"status": status_id,
		"unit": host_unit_id,
		"active": active,
		"why": why,
	})


static func log_status_add(
		status_id: String, kind: String, host_unit_id: String,
		source_unit_id: String, life: String, duration_sec: float
) -> void:
	if not is_on():
		return
	write("status_add", {
		"status": status_id,
		"kind": kind,
		"unit": host_unit_id,
		"src": source_unit_id,
		"life": life,
		"dur": snappedf(duration_sec, 0.01),
	})


# 介入点が効いた（PLAN 11-1・段階3の後半③）。
#
# kind … "death"（復活）／ "status"（付与を弾いた）／ "heal"（被回復増減）
#        ／ "shield"（肩代わりした）／ "reduction"（軽減）／ "pierce"（貫通）
#        ／ "crit"（確定クリティカル）／ "reflect"（殴り返した）
# status_id … 介入の原因になった状態のID。⚠ "status" のときだけ意味が違い、
#             「弾かれたほうのID」が入る（免疫そのもののIDではない）。
#             どちらか一方しか出せないので、事故の側（弾かれたほう）を採る。
# detail … 種類ごとの値を文字列で。"death"=戻したHP ／ "status"=弾いた状態のID
#          ／ "heal"=元の量と後の量
#
# ⚠ 種類ごとに3本作らないこと。3本にすると片方だけ直す事故になる
#   （表示経路を _on_skill_effects_applied の1本に保ったのと同じ理由）。
# ⚠ 介入が「効いた」ときだけ出す。素通しは出さない（毎フレーム数十行になる）。
static func log_intervene(kind: String, unit_id: String, status_id: String, detail: String) -> void:
	if not is_on():
		return
	write("intervene", {
		"kind": kind,
		"unit": unit_id,
		"status": status_id,
		"detail": detail,
	})


# 範囲（オーラ・毒沼・設置地帯）の出入り（EXEC_SKILL_AURA.md）。
#
# ⚠ これが要る理由：オーラは画面に何も出ない（補正は数字が変わるだけ）。
#   記録が無いと「効いていない」のか「範囲の中に居ない」のかを切り分けられない。
# ⚠ 出入りしたときだけ出す。毎フレーム出すと1戦で数万行になる
#   （位置・移動を出さないのと同じ理由）。
# why … "enter"（入った） / "leave"（出た）
static func log_zone(status_id: String, unit_id: String, why: String) -> void:
	if not is_on():
		return
	write("zone", {
		"status": status_id,
		"unit": unit_id,
		"why": why,
	})


# why … "expire"（寿命切れ）／ "host_dead"（宿主が死んだ）／ "revive_clear"（復活で全消し）
#       ／ "consumed"（シールドを吸い切った・EXEC_SKILL_MITIGATION.md）
static func log_status_end(status_id: String, host_unit_id: String, why: String) -> void:
	if not is_on():
		return
	write("status_end", {
		"status": status_id,
		"unit": host_unit_id,
		"why": why,
	})


# ウェーブ交代・勝敗で状態をまとめて捨てたとき。⚠ 1件ずつ status_end を出さない
#   （交代のたびに数十行出て、寿命切れの status_end が埋もれる）。
#   件数だけ出せば「status_add の残りがここで消えた」と読める。
static func log_status_clear(count: int) -> void:
	if not is_on() or count <= 0:
		return
	write("status_clear", { "count": count })


static func log_wave(wave: int, total: int, enemy_ids: Array) -> void:
	if not is_on():
		return
	write("wave", {
		"wave": wave,
		"total": total,
		"enemies": _to_id_array(enemy_ids),
	})


static func log_result(victory: bool, wave: int, total: int) -> void:
	if not is_on():
		return
	write("result", {
		"victory": victory,
		"wave": wave,
		"total": total,
	})


# JSON.stringify に Variant の配列をそのまま渡すと型が混ざる。文字列に揃える。
static func _to_id_array(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in ids:
		out.append(str(raw))
	return out
