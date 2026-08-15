class_name BattleFormula
extends RefCounted

# 戦闘の計算式を集約する静的クラス。
# SkillResolver と同じスタイル（Autoload にしない・状態を持たない）。
#
# 【なぜ1ファイルに集めるか】
# 10軸の前半で調べた結果、ダメージ計算が battle_controller.gd と
# skill_resolver.gd の2箇所に別々に書かれていた（EXEC_STATS_10_AXES.md §2-4）。
# 式を足すたびに両方へ同じものを書く形になっていたので、ここへ一本化する。
# 戦闘の式を直すときは、まずこのファイルを見ること。
#
# 【依存の向き】このファイルは何にも依存しない。引数はすべて数値。
# BattleUnit を参照しないこと。BattleUnit 側がこのファイルを参照するため、
# 相互参照になるとパースエラー（Cyclic reference）を踏む。
# 「どの軸を使うか」（物理→atk/def、魔法→mag/mdef）は BattleUnit.get_power() /
# get_defense() が持つ。ここに置くのは算術だけ。
#
# 【式の出典】GAME_DESIGN.md 8-2。式の本文をここに書き写さない。
# 【上限値】Balance.adventure（AdventureConfig）から引く。const で持たない。


# 実際の攻撃間隔（秒）。atkspd が高いほど短くなる。
#
# 上限は「％の上限」ではなく「秒数の下限」で持つ（GAME_DESIGN.md 8-2-2）。
# base_sec が 0 のデータでも下限が効くので、毎フレーム攻撃にはならない。
static func attack_interval(base_sec: float, atkspd: int) -> float:
	var denom: float = 1.0 + float(max(0, atkspd)) / 100.0
	return maxf(base_sec / denom, Balance.adventure.min_attack_interval_sec)


# 実際のクールダウン（秒）。haste が高いほど短くなる。
# haste は max_haste で頭打ちにする（超過分は捨てる）。
static func cooldown(base_sec: float, haste: int) -> float:
	var h: int = clampi(haste, 0, Balance.adventure.max_haste)
	return base_sec / (1.0 + float(h) / 100.0)


# 会心の抽選。damage() から分けてある。
#
# 分けている理由：デバッグパネルが「会心でないときのダメージ」を
# 乱数なしで出せるようにするため。混ぜると表示用にもう1本式を書くことになる。
#
# crit_rate は max_crit_rate で頭打ちにする。超過分は捨てる（crit_dmg に変換しない）。
static func roll_crit(crit_rate: int) -> bool:
	var rate: int = clampi(crit_rate, 0, Balance.adventure.max_crit_rate)
	if rate <= 0:
		return false
	return randf() * 100.0 < float(rate)


# 1発分のダメージ。必ず 1 以上を返す。
#
# power            … 物理なら atk、魔法なら mag（BattleUnit.get_power() が選ぶ）
# defense          … 物理なら def、魔法なら mdef（BattleUnit.get_defense() が選ぶ）
# multiplier       … スキル倍率 × チャージ倍率 × atk_multiplier を畳んだもの
# crit_dmg_percent … 150 なら 1.5 倍
# is_crit          … 呼び出し側が roll_crit() で決めて渡す。ここでは抽選しない
#
# 防御は除算。減算にしない（GAME_DESIGN.md 8-2-1）。
# 負の防御が入っても 100 + defense が 0 以下にならないよう 0 で切る。
static func damage(power: int, defense: int, multiplier: float, crit_dmg_percent: int, is_crit: bool) -> int:
	var value: float = float(power) * multiplier
	if is_crit:
		value = value * float(crit_dmg_percent) / 100.0
	var d: float = float(max(0, defense))
	return max(1, int(floor(value * 100.0 / (100.0 + d))))
