class_name ProjectileView
extends Node2D

# 飛んでいる投射物の見た目（PLAN_SKILL_TEMPLATE.md 6-7）。
#
# 【この層が持つもの】位置と絵と「着いたか」の判定だけ。
# 【この層が持たないもの】ダメージ・対象選択・寿命の意味。
#
#   SkillRuntime      … 効果を「着弾待ち」として待ち行列に積み、投射物を1本頼む
#          ↓ projectile_requested（シグナル。⚠ 新層はノードを触らない）
#   BattleController  … ここを生成する。データとビューが出会う唯一の場所（PLAN 7-1）
#          ↓ setup()
#   ProjectileView(ここ) … 飛ぶ。着いたら合図を返す
#          ↓ notify_event(cast_id, "hit")
#   SkillRuntime      … 待っていた効果を発火する
#
# ⚠ ダメージをここで出さない。合図を返すだけ。
#   ここで当てると、待ち行列の取り消し（飛び道具の無効化・PLAN 6-8）が効かなくなる。
#
# ⚠ .tscn を作らない。コードで組み立てる（battle_debug_panel.gd と同じ理由）。
#
# 【誘導する】対象が生きている限り追う（PLAN 6-7）。
# ⚠ 対象が消えたら、発射時の座標へ飛び続けて空振りする。
#   その場で消すと「撃ったのに何も起きない」が無音になる。合図は必ず返す
#   （PLAN 6-6「演出シーンの規約：外れても合図を出す」）。

# 色。送り方で変える（見た目で melee / projectile / magic を見分けるため）。
const COLOR_PROJECTILE: Color = Color(0.95, 0.85, 0.45)
const COLOR_MAGIC: Color = Color(0.6, 0.75, 1.0)

# 絵の大きさ（ピクセル）。当たり判定には使わない。
const RADIUS: float = 5.0
const TRAIL_LENGTH: float = 14.0

# ⚠ 保険。着弾も消滅もしないまま飛び続けるのを防ぐ。
#   SkillRuntime 側のタイムアウト（5秒）より短くすること。長いと、
#   ダメージが先に落ちてから矢が消える形になり、見た目と結果がずれる。
const MAX_LIFE_SEC: float = 4.0

var _controller: Node = null
var _cast_id: int = 0
var _target_unit_id: String = ""
var _speed: float = 1200.0
var _color: Color = COLOR_PROJECTILE
var _fallback_position: Vector2 = Vector2.ZERO
var _life_sec: float = 0.0
var _done: bool = false


# from_position … 発射位置
# fallback       … 対象が消えたときに向かい続ける座標（＝発射時点の対象の位置）
func setup(
		controller: Node, cast_id: int, target_unit_id: String,
		from_position: Vector2, fallback: Vector2, speed: float, color: Color
) -> void:
	_controller = controller
	_cast_id = cast_id
	_target_unit_id = target_unit_id
	_fallback_position = fallback
	_speed = maxf(1.0, speed)
	_color = color
	position = from_position
	queue_redraw()


# ⚠ _process を使う。Engine.time_scale（デバッグパネルの 1〜4 で最大8倍）に
#   自動で追従する。Timer や Tween に置き換えないこと。
func _process(delta: float) -> void:
	if _done:
		return

	_life_sec += delta
	if _life_sec >= MAX_LIFE_SEC:
		# 届かないまま時間切れ。⚠ それでも合図は返す（外れても合図を出す規約）。
		_arrive()
		return

	var goal: Vector2 = _goal_position()
	var to_goal: Vector2 = goal - position
	var step: float = _speed * delta
	if to_goal.length() <= maxf(step, _hit_distance()):
		position = goal
		_arrive()
		return

	position += to_goal.normalized() * step
	rotation = to_goal.angle()
	queue_redraw()


# 追う先。対象が生きていればその位置、消えていれば発射時の座標。
func _goal_position() -> Vector2:
	var target: BattleUnit = _find_target()
	if target == null or not target.is_alive():
		return _fallback_position
	return Vector2(target.x, _fallback_position.y)


func _find_target() -> BattleUnit:
	if _controller == null or _target_unit_id == "":
		return null
	var session: BattleSession = _controller.get_session()
	if session == null:
		return null
	for u in session.party_units + session.enemy_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == _target_unit_id:
			return u
	return null


func _hit_distance() -> float:
	if Balance == null or Balance.adventure == null:
		return 12.0
	return Balance.adventure.projectile_hit_distance_px


# 着弾（または時間切れ）。⚠ 合図を返してから消える。
# ⚠ 二重に呼ばない。1本の矢が2回当たると、待っていた効果が2回発火する
#   （notify_event は1回目で待ち行列から取り出すので実害は出ないが、
#    2本目の矢が同じ cast_id を持つ場合に順番が読めなくなる）。
func _arrive() -> void:
	if _done:
		return
	_done = true
	if _controller != null and _controller.has_method("on_projectile_hit"):
		_controller.on_projectile_hit(_cast_id)
	queue_free()


func _draw() -> void:
	# 進行方向に尾を引く。rotation を当ててあるので、常に -X 方向が後ろ。
	draw_line(Vector2(-TRAIL_LENGTH, 0.0), Vector2.ZERO, Color(_color, 0.45), 2.0)
	draw_circle(Vector2.ZERO, RADIUS, _color)
