class_name GrowthFormula
extends RefCounted

# .tres に文字列で書かれた計算式を評価する静的クラス。Autoload にはしない（5つ固定ルール）。
#
# 目的：成長カーブとコストカーブを、コードを触らずに Inspector から差し替えられるようにする。
#   例: "base + growth * (level - 1)"      線形
#       "base + growth * (level - 1) * level"  二次
#       "base * pow(growth, level - 1)"    指数
#
# 式は人間が .tres で手打ちするため、typo は必ず起きる。
# パースにも実行にも失敗しうる前提で、失敗時は必ず fallback を返してゲームを止めない。
# push_error は出さない（編集ミスは想定内の事象であり、異常終了扱いにしないため）。


# formula を評価して float で返す。
# vars のキーが式中で使える変数名になる（例: {"base": 120.0, "growth": 8.0, "level": 3.0}）。
# 空文字・パース失敗・実行失敗・戻り値が数値でない場合は fallback を返す。
static func evaluate(formula: String, vars: Dictionary, fallback: float) -> float:
	if formula.strip_edges().is_empty():
		return fallback

	# Expression.parse() は変数名の配列を先に受け取り、execute() に同じ順で値を渡す。
	# Dictionary の走査順は挿入順で安定しているが、名前と値がずれると原因の分かりにくい
	# バグになるため、同じループで両方を組み立てる。
	var names: PackedStringArray = PackedStringArray()
	var values: Array = []
	for key: Variant in vars:
		names.append(str(key))
		values.append(vars[key])

	var expression: Expression = Expression.new()
	var parse_error: int = expression.parse(formula, names)
	if parse_error != OK:
		push_warning("[GrowthFormula] parse failed: '%s' — %s（fallback=%s を使用）" % [
			formula, expression.get_error_text(), str(fallback)
		])
		return fallback

	# 第3引数 show_error = false。式の誤りでエディタにエラーダイアログを出さない。
	var result: Variant = expression.execute(values, null, false)
	if expression.has_execute_failed():
		push_warning("[GrowthFormula] execute failed: '%s' — %s（fallback=%s を使用）" % [
			formula, expression.get_error_text(), str(fallback)
		])
		return fallback

	# bool は int に暗黙変換されてしまうため、明示的に弾く。
	# "level > 3" のような式を書かれたときに 1 が返るのを防ぐ。
	if result is bool:
		push_warning("[GrowthFormula] result is bool: '%s'（fallback=%s を使用）" % [formula, str(fallback)])
		return fallback
	if not (result is float or result is int):
		push_warning("[GrowthFormula] result is not a number: '%s' -> %s（fallback=%s を使用）" % [
			formula, str(result), str(fallback)
		])
		return fallback

	var value: float = float(result)
	# ゼロ除算や pow() の暴走で inf / nan が返ることがある。
	if is_nan(value) or is_inf(value):
		push_warning("[GrowthFormula] result is nan/inf: '%s'（fallback=%s を使用）" % [formula, str(fallback)])
		return fallback

	return value


# ステータスと必要素材数は整数で扱うため、四捨五入して返す版。
# 切り捨てではなく四捨五入にする理由：growth に 0.5 のような値を入れたとき、
# 切り捨てだとレベルを2つ上げるまで数値が動かず「上げたのに何も変わらない」体験になるため。
static func evaluate_int(formula: String, vars: Dictionary, fallback: float) -> int:
	return int(round(evaluate(formula, vars, fallback)))
