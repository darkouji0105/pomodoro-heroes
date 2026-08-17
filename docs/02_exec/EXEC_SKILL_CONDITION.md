# EXEC — **段階3の後半② 条件（毎フレーム評価する発火源）**

PLAN 10章の発火源のうち3つ目。**`trigger`（自分の実行）・購読・周期は済んでおり、条件だけが無い。**

⚠ **この回は事故が全部無音になる。** 条件が一度も真にならなくても、常に真でも、エラーは1つも出ず、
画面を見ても分からない。**前2回（戦闘ログ・敵の管理）はこの回を追えるようにするための土台。**
→ 完了条件は**ほぼ全部 `battle_last.jsonl` で判定する**（§6-B）。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **条件の書き方** | **効果に `condition{}` を持たせる**（＝状態が条件を持つ）。**毎フレーム評価し、真である間だけ効く。** ⚠ 「効果に `when` を足して発火時に1回だけ評価する」案は**採らない**（発火源ではなくフィルタなので、毎フレーム評価の穴が埋まらない。また同じ条件式に2経路ができ、宿題8と同じ形の事故になる） |
| **どの効果に書けるか** | **`buff` / `dot` / `react` の3つ全部**。⚠ 読む側が3箇所（`_rebuild_unit_mods` / `_fire_intervals` / `query`）に散るのが、この形で唯一の実際の危険。§3-1 の書き方を守ること |
| **宿り先** | **`host: unit` だけ。** `point`（オーラ）は**この回ではやらない**。真偽が「状態1件」ではなく「状態 × ユニットの対」ごとになり、記憶の持ち方もログの持ち方も丸ごと別物になるため |
| **評価の頻度** | **毎フレーム。ただし `condition` を持つ件だけ。** 持たない件は今と同じコスト。⚠ 間引かない（真偽が変わる瞬間がログの `t` とずれ、この回の目的である追跡可能性が落ちる。間引きは後から足せるが、精度は後から上げられない） |
| **スタック閾値** | ⚠ **この回では触らない。** 宿題5（`stack` の5部品のうち上限・消え方・再付与・閾値が未実装）に残す。上限が無いまま閾値を載せると、`independent` が無限に積む状態に閾値が乗り、**一度真になったら二度と偽に戻らない**。§2-3 の歯止めを必ず入れること |

### 0-1. 設計役が置いた前提（**違ったら言ってください**）

- **HP依存条件は敵側で検証する。** ⚠ 検証用キャラ3体は `hp: 9999`（`characters.json:161` 他）なので、
  味方に `hp_ratio <= 0.5` を書くと**一度も真にならない**。これは §2-4 が言っている事故そのもの。
  → 検証用の敵 `enemy_dbg_cond`（`hp: 20`）に持たせる。**味方が殴れば必ず半分を割る＝真になる瞬間が確実に来る**
- **「偽に戻る」も検証する。** HP依存は一度真になると偽に戻らないので、それだけでは「剥がれない条件」を見逃す。
  → 味方側に「**毒が付いている間**」の条件を1本置く。毒には寿命があるので**必ず真→偽が往復する**
- **検証用ステージは `stage_dbg_condition` を1本足す**（`stage_order.json` の `"debug"` 配列に1行）。⚠ **本番の `"story"` は触らない**

---

## 1. いま何が無いか（**実コードで確認済み・2026-08-17**）

| | 状態 |
|---|---|
| 状態の器（`status_registry.gd` 630行） | ✅ `tick()` が毎フレーム全件を回している。**条件を差す場所はここ** |
| 状態の1件が持つ欄 | `instance_id` / `status_id` / `kind` / `host` / `host_unit_id` / `host_x` / `source_unit_id` / `stack` / `life` / `duration_sec` / `elapsed` / `stat` / `value` / `damage_effect` / `interval_sec` / `fires_done` / `fires_total` / `react` / `counter`。⚠ **`condition` と `active` が無い** |
| 問い合わせ口 | ✅ `query()` / `count()` / `has()` / `stat_mod()` / `bump_counter()`。⚠ **条件から使う想定で用意済みだが、まだ誰も使っていない** |
| 補正の組み直し | ✅ `_rebuild_unit_mods()` が**ゼロから組み直す**（差分更新しない）。⚠ **この回の安全はここに乗っている** |
| 変数表 | ✅ `SkillResolver._scale_variable()`。`hp_ratio` / `hp_lost_ratio` / `hp_current` / `hp_lost` / `distance` ＋ 10軸 |
| ログ | ✅ `BattleLog`。⚠ **`condition` の入口が無い** |
| 検証用ステージ | ✅ `stage_order.json` の `"debug"` 列（常設・スタミナも報酬もクリア記録も付かない） |

⚠ **`query()` は `str(entry.get(key,"")) != str(filter[key])` で比べている**（`status_registry.gd:534`）。
`active` を bool で持てば `query({..., "active": true})` が**既存のまま効く**。**`query()` を書き換えないこと。**

---

## 2. 条件の形（**語彙**）

### 2-1. 書き方

```json
{
	"type": "buff",
	"host": "unit",
	"status_id": "status_edbg_cond_atk",
	"stat": "atk",
	"value": 20,
	"duration_sec": 60.0,
	"stack": "refresh",
	"condition": { "source": "hp_ratio", "of": "host", "op": "lte", "value": 0.5 }
}
```

| 欄 | 意味 | 省略 |
|---|---|---|
| `source` | 何を見るか。⚠ **`scale_from` の語彙をそのまま流用する**（2本目の語彙を作らない） | **不可** |
| `of` | 誰の値か。`host`（宿主）／ `source`（付与者） | 不可 |
| `op` | `lt` / `lte` / `gt` / `gte` / `eq` | 不可 |
| `value` | 比べる数値 | 不可 |
| `status_id` | `source: "status_has"` のときだけ。⚠ **効果の `status_id` とは別物**（見たい相手の状態のID） | `status_has` 以外では**書いたら赤** |

### 2-2. ⚠ `of` は `scale_from` の `of` と**別の一覧**にする

`scale_from` の `of` は `user` / `target` / `source`。**状態には `user` も `target` も居ない**（宿主と付与者しかいない）。
同じ語を使い回すと「`target` って誰？」が無音でズレる。→ **`host` / `source` の2語だけの一覧を作る。**

### 2-3. ⚠ `status_count`（件数）を作らない。`status_has`（有無）だけ

`source: "status_has"` は **0 か 1 しか返さない。** 件数を返す `status_count` を作ってはならない。

**理由**：件数を返せる形にすると、`{ "source": "status_count", "op": "gte", "value": 3 }` で
**スタック閾値がここから書けてしまう**（人間の決定＝この回では触らない）。
`stack` は上限も消え方も未実装（宿題5）なので、`independent` は無限に積む。
閾値を書くと**一度真になったら二度と偽に戻らない**状態ができ、しかもエラーは1つも出ない。

⚠ 「デバフの数だけ強く」は**変数表**の担当（段階3の後半④）。条件は bool だけを返す。

### 2-4. ⚠ `distance` は条件に書けない（赤）

`scale_from` の `distance` は「使用者と対象の間」の値。状態には対象が居ないので、
そのまま流用すると「宿主と付与者の距離」という**別の意味**になる。**この回では赤で弾く。**
（`point` のオーラを入れる回で、座標の規則と一緒に決める）

---

## 3. 実装（ファイル別）— **全部 設計役が書く**

⚠ **関数を足す前に `grep -n "func <名前>"` をして、同名が無いことを確かめる**（戦闘ログの回で `_exit_tree()` を二重宣言してパースエラーを出した）。
⚠ **足したあとにも `grep -n` で当たったことを確かめる**（`CLAUDE.md` 2番）。

### 3-1. `scripts/systems/status_registry.gd`（630行）

**この回の本体。** 追加する関数は4本（`_fill_condition` / `_eval_conditions` / `_eval_one` / `_condition_value`）、
既存関数の変更は5箇所（`_make_entry` / `add` / `tick` / `_rebuild_unit_mods` / `_fire_intervals`）。

#### (a) `_make_entry()` に**2行**足す

```gdscript
		# 条件（PLAN 10章の3つ目の発火源）。空なら「条件なし＝常に有効」。
		"condition": {},
		# 条件が今どうか。⚠ 書くのは _eval_conditions() と add() だけ。
		#   読む側（補正の組み直し・周期発火・購読）はこの bool を読むだけにする。
		"active": true,
```

⚠ **`active` は必ず全件が持つこと。** 持たない件があると `query({"active": true})` が
その件だけ黙って外す（`query()` は `entry.get("active", "")` を文字列で比べるため）。

#### (b) `_fill_condition(entry, effect) -> bool` を**足す**（`_fill_react` と同じ型）

- `effect` に `condition` が無ければ `true` を返して何もしない（条件なしは正常系）
- `Dictionary` でなければ赤で `false`
- `source` / `of` / `op` を `SkillSchema` の一覧と突き合わせる。不明なら赤で `false`
- `source: "status_has"` のときだけ `status_id` を要求する。それ以外で `status_id` があれば赤
- ⚠ **`duplicate(true)` で複製して `entry["condition"]` に入れる**（`_fill_react` と同じ理由。マスターの辞書を参照で握るとマスターごと書き変わる）

呼ぶ場所は `add()` の **`--- 6. 種類ごとの欄 ---` の直後**。
⚠ **`_entries` を触る前**（`CLAUDE.md` 6番：状態を変える前に全部の判定を終える）。

#### (c) `add()` の末尾に**1行**（⚠ 位置が要件）

`_entries` に入れた**直後**、`_rebuild_unit_mods()` を呼ぶ**前**に：

```gdscript
	entry["active"] = _eval_one(entry)
```

⚠ **これが無いと、条件が偽の状態が「1フレームだけ真」として付く。**
補正が1フレーム乗って次のフレームで剥がれるので、数字がちらつくだけで**エラーは出ない。**

⚠ ログはここでも1行出す（`why: "add"`）。**付いた時点の真偽が分からないと、
「一度も真にならなかった」のか「最初から常に真だった」のかがログから区別できない。**

#### (d) `tick()` に **`_eval_conditions(touched)` を1行**足す（⚠ 位置が要件）

```
1. _drop_dead_hosts(touched)
2. 時計を進める
3. _eval_conditions(touched)   ← ここに足す
4. _fire_intervals(results)
5. _expire(touched)
6. _rebuild_touched(touched)
```

⚠ **3 は 4 より前。** 逆にすると、偽になったフレームに DoT が1発だけ余計に出る。
⚠ **3 で真偽が変わった `buff` の宿主を `touched` に入れること。** 入れないと補正が組み直されず、
**条件が効かない**（`NEXT_STEPS` 2-3 の事故そのもの。`clear_all()` で踏んだのと同じ形）。

#### (e) `_eval_conditions(touched)` を**足す**

```gdscript
func _eval_conditions(touched: Dictionary) -> void:
	for entry: Dictionary in _entries:
		# ⚠ 条件を持たない件はここで抜ける。今と同じコストに保つ。
		if (entry.get("condition", {}) as Dictionary).is_empty():
			continue
		var was: bool = bool(entry.get("active", true))
		var now: bool = _eval_one(entry)
		if now == was:
			continue
		entry["active"] = now
		# ⚠ buff だけが補正に効く。dot / react は組み直しに関係しない。
		if str(entry.get("kind", "")) == KIND_BUFF \
				and str(entry.get("host", "")) == SkillSchema.HOST_UNIT:
			touched[str(entry.get("host_unit_id", ""))] = true
		BattleLog.log_condition(
			str(entry.get("status_id", "")), str(entry.get("host_unit_id", "")), now, "change"
		)
```

⚠ **`BattleLog` を出すのは「変わったとき」だけ。** 毎フレーム出すと1戦で数万行になる（§4-4）。

#### (f) `_eval_one(entry) -> bool` を**足す**

- `condition` が空なら `true`（条件なしは常に有効）
- `of` から見る相手を決める … `host` → `_find_unit(host_unit_id)` ／ `source` → `_find_unit(source_unit_id)`
- 相手が居なければ **`false`**。⚠ **警告を出さない**（宿主が死ぬフレームに必ず通る正常系）
- `source: "status_has"` … `has({ "host": HOST_UNIT, "host_unit_id": <相手のID>, "status_id": <条件の status_id> })` を 1.0 / 0.0 に
- それ以外 … `hp_ratio` / `hp_lost_ratio` / `hp_current` / `hp_lost` と10軸。
  ⚠ **`SkillResolver._scale_variable()` を呼ばないこと。** あちらは `user` / `target` の2者を取る契約で、
  ここは1者しか居ない。呼べる形にすると `of` の語彙が2つの意味を持つ（§2-2）
- `op` で比べて bool を返す

#### (g) `_rebuild_unit_mods()` に**1行**（⚠ この回の安全はここ）

```gdscript
		if not bool(entry.get("active", true)):
			continue
```

⚠ **ここは「ゼロから組み直す」形になっている**（`status_registry.gd:592` の注記）。
だから条件は**絞り込みを1行足すだけ**で済み、**「剥がれないバフ」「二重に乗るバフ」が構造的に起きない。**
⚠ **`add()` / `_eval_conditions()` から `unit.set_stat_mods()` を直接呼ばないこと。** 組み直しの1本道を守る。

#### (h) `_fire_intervals()` に**「偽の間の扱い」を足す**（⚠ 決めが1つ・無音でズレる）

**決定：時計は進める。偽の間に来た発火は捨てる。寿命は書いたとおりに切れる。**

```gdscript
		# 条件が偽の間は発火しない。
		# ⚠ fires_done を elapsed に追いつかせること。追いつかせないと、真に戻った
		#   瞬間に while が回り、偽の間ぶんを一気に連射する（総ダメージが暗算と
		#   合わなくなり、エラーは出ない）。
		if not bool(entry.get("active", true)):
			var skipped: int = int(floor(float(entry.get("elapsed", 0.0)) / interval_sec))
			if int(entry.get("fires_done", 0)) < skipped:
				entry["fires_done"] = skipped
			rest.append(entry)
			continue
```

⚠ **`elapsed` を止める案は採らない。** 「時計は1本」という既存の不変条件（`_make_entry()` の注記）が崩れ、
寿命も一緒に延びる。⚠ **`interval_sec` を読む行より後ろに置くこと**（`interval_sec` が要る）。

#### (i) `query()` は**触らない**

§1 のとおり、`active` を bool で持てば既存の比較のまま効く。

### 3-2. `scripts/systems/skill_runtime.gd`（532行）

`_notify()` の `query()` の filter に**1行**足すだけ（`skill_runtime.gd:473` 付近）：

```gdscript
	var subs: Array = _registry.query({
		"kind": StatusRegistry.KIND_REACT,
		"host_unit_id": host_unit_id,
		"active": true,
	})
```

⚠ **他は1行も触らない。** 購読の発火経路（`cast()` の1本道・PLAN 6-5）を変えない。

### 3-3. `scripts/systems/skill_schema.gd`（712行）

#### (a) 語彙を足す

```gdscript
# --- effects[].condition（毎フレーム評価する発火源・PLAN 10章） ---
#
# ⚠ of は scale_from の of（user / target / source）と別の一覧にすること。
#   状態には user も target も居ない（宿主と付与者しかいない）。同じ語を
#   使い回すと「target って誰？」が無音でズレる。
const COND_OF_HOST: String = "host"
const COND_OF_SOURCE: String = "source"
const COND_OF_KNOWN: Array = [COND_OF_HOST, COND_OF_SOURCE]

const COND_OP_LT: String = "lt"
const COND_OP_LTE: String = "lte"
const COND_OP_GT: String = "gt"
const COND_OP_GTE: String = "gte"
const COND_OP_EQ: String = "eq"
const COND_OPS_KNOWN: Array = [COND_OP_LT, COND_OP_LTE, COND_OP_GT, COND_OP_GTE, COND_OP_EQ]

# その状態が付いているか。⚠ 0 か 1 しか返さない。
#   件数を返す status_count を作らないこと（スタック閾値が書けてしまう。EXEC §2-3）。
const COND_SOURCE_STATUS_HAS: String = "status_has"
```

```gdscript
# condition の source に書ける名前。
# ⚠ scale_sources() を流用する（2本目の語彙を作らない）。
# ⚠ distance だけ除く。状態には対象が居ないので意味が変わる（EXEC §2-4）。
static func condition_sources() -> Array:
	var sources: Array = []
	for name: Variant in scale_sources():
		if str(name) != SCALE_DISTANCE:
			sources.append(str(name))
	sources.append(COND_SOURCE_STATUS_HAS)
	return sources
```

#### (b) `_validate_condition()` を足す（E55〜E61）

| 番号 | 判定 |
|---|---|
| E55 | `condition` が `Dictionary` でない |
| E56 | `condition.source` が無い、または `condition_sources()` に無い |
| E57 | `condition.of` が無い、または `COND_OF_KNOWN` に無い |
| E58 | `condition.op` が無い、または `COND_OPS_KNOWN` に無い |
| E59 | `condition.value` が数値でない |
| E60 | `source: "status_has"` なのに `condition.status_id` が無い／ `status_has` 以外なのに `condition.status_id` がある |
| E61 | `condition` を書いたのに `host` が `unit` でない（⚠ この回は `unit` だけ） |

#### (c) 呼ぶ場所

- `_validate_status_effect()` の末尾に `if effect.has("condition"): _validate_condition(...)`
- `_validate_effect()` に **E62**：状態でない効果（`damage` / `heal` など）に `condition` があれば赤。
  ⚠ **`react{}` の E50 と同じ形**（`skill_schema.gd:419` 付近）。**書ける場所を1箇所に閉じる歯止め。**

⚠ **`push_error` / `push_warning` をこのファイルで呼ばないこと**（`skill_schema.gd:17`）。`_err()` / `_warn()` を使う。

### 3-4. `scripts/systems/battle_log.gd`（269行）

入口を1本足す。⚠ **毎フレーム呼ばれない場所からしか呼ばないこと**（§4-4）。

```gdscript
# 条件の真偽（PLAN 10章）。⚠ 「変わったとき」と「付いたとき」だけ呼ぶ。
#   毎フレーム呼ぶと1戦で数万行になる（位置・移動を出さないのと同じ理由）。
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
```

### 3-5. `scenes/adventure/battle_debug_panel.gd`（385行）

`_format_entry_line()`（217行付近）に**1行**足す。⚠ **F3 の `P` が状態を見る唯一の手段**なので、
条件付きの件が今どちらかを出しておく。

```gdscript
	if not (entry.get("condition", {}) as Dictionary).is_empty():
		text += " cond=%s" % ("on" if bool(entry.get("active", true)) else "off")
```

⚠ **`_format_statuses()`（158行）は触らない。** あちらの `query()` に `active` を入れないこと。
条件が偽の件も**画面に出し続ける**（消えたのか偽なのかが区別できなくなる）。

### 3-6. `scripts/systems/master_data_loader.gd`（586行）

`ENEMY_DIRS_OPTIONAL` に**1行**（`DIR_ENEMIES + "enemy_dbg_cond/"`）。
⚠ **足し忘れるとその敵のスキルが無音で消える**（宿題13と同じ罠）。他は1行も触らない。

### 3-7. ⚠ 触らないファイル

`battle_controller.gd` / `skill_resolver.gd` / `skill_activation.gd` / `unit.gd` は**1行も触らない。**
条件は状態の器の中で完結する（§4-5）。

---

## 4. ⚠ 事故りやすい箇所

| | 内容 |
|---|---|
| **4-1** | ⚠ **「真になった瞬間」と「真である間」を混ぜない。** この回は**「真である間だけ効く」に統一**（`active` フラグ）。**条件が真になった瞬間に別の状態を `add()` する形を書かないこと。** 混ぜると「剥がれないバフ」と「二重に乗るバフ」が同時に出る |
| **4-2** | ⚠ **式を2回評価しない**（PLAN 11-0）。ダメージは1回だけ計算され、以降は確定した数値として持ち回される。**条件は `_rebuild_unit_mods()` を通して能力値に効かせるだけで、確定後の `amount` を書き換えない** |
| **4-3** | ⚠ **補正の組み直しを呼び忘れない。** `_eval_conditions()` で真偽が変わった `buff` の宿主を `touched` に入れること。**入れないと状態の配列は正しいのに能力値だけ古いまま**になり、エラーも出ず F3 の数字ももっともらしい |
| **4-4** | ⚠ **ログを毎フレーム出さない。** 出すのは `add`（付いた時点）と `change`（変わった瞬間）だけ |
| **4-5** | ⚠ **`battle_controller` に条件を散らさない。** 「今撃てるか」は `SkillActivation.blocked_reason()` の1箇所（PLAN 12章）。**発動条件と効果の条件を混ぜない。** `battle_controller.gd` はこの回で**1行も触らない** |
| **4-6** | ⚠ **`active` を書く場所を2箇所以上にしない。** 書くのは `add()` と `_eval_conditions()` だけ。読む側（3箇所）は bool を読むだけ |
| **4-7** | ⚠ **`parties.json` の `members` を戻し忘れない**（前回実際に戻し忘れた）。⚠ **ステージ側は `"debug"` 列で別枠になったので戻す運用は無い** |
| **4-8** | ⚠ **JSON に `cat >>` で追記すると追記分が CRLF になる**（敵の回で踏んだ）。**追記したら改行コードを確かめる** |

---

## 5. Ziva に渡せる部分（**JSON と `ja.csv` だけ**）

⚠ **`.gd` は1行も触らないこと。** `.gd` 側（§3）は設計役が書き終えている。
⚠ **考えて書かない。この章のブロックをそのまま貼る。** ⚠ **`status_id` はあとから改名できない**（`CLAUDE.md` 4番）。
⚠ **インデントはタブ。** ⚠ **既存のスキル45件・敵9体・ステージ4本を1文字も変えない**（下記で「足す」と書いたもの以外）。

### 5-1. `resources/balance/master/enemies.json` に **1体**

**末尾の `}` の手前に**足す（`enemy_dbg_ranged` の `}` に `,` を付ける）。

⚠ **`attack_range` が 300 なのは意図（初稿の 50 は誤り・2026-08-17に修正）。**
検証用キャラ3体は**全員 `attack_range: 300` の遠距離**なので、近接（50）の敵は
**6倍の射程差を歩いて詰める間に撃たれ続けて死に、射程に入れない。**
敵は「射程内でだけ」スキルを撃つので、**スキルが一度も発動しない**（1回目の実測がこれ）。

⚠ **`hp` が 60 なのも意図（初稿の 20 は誤り）。** 味方3体が2秒ごとに4ダメージ＝**約3ダメージ/秒**。
20 だと約7秒で死に、敵のスキルCD 8秒に**一度も届かない**。60 なら
「約10秒で半分を割り、約20秒で死ぬ」ので、**真になる前と後の両方に敵の攻撃が並ぶ。**

⚠ **`atk` が 5 なのは意図。** 条件で `+20` されて **5 → 25** に跳ねるのが `damage` 行の `amount` で一目で分かる。

```json
	"enemy_dbg_cond": {
		"name_key": "ui_battle_enemy_dbg_cond",
		"hp": 60,
		"atk": 5,
		"mag": 5,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 300,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_cond_hp"]
	}
```

### 5-2. `resources/balance/master/enemies/enemy_dbg_cond/skills.json`（**新規フォルダ・新規ファイル**）

⚠ **フォルダを1つ新規作成する**（`enemies/` 配下は人間が承認済み。7つ目）。

⚠ **`duration_sec` が 60・`cooldown_sec` が 8** なのは意図。`refresh` で貼り直され続けるので、
**寿命切れで条件の検証が途中で終わらない。**

```json
{
	"skill_edbg_cond_hp": {
		"name_key": "ui_battle_skill_edbg_cond_hp",
		"user_character_id": "enemy_dbg_cond",
		"unlock_level": 1,
		"cooldown_sec": 8.0,
		"activation": "instant",
		"target": {
			"team": "self"
		},
		"effects": [
			{
				"type": "buff",
				"host": "unit",
				"status_id": "status_edbg_cond_atk",
				"stat": "atk",
				"value": 20,
				"duration_sec": 60.0,
				"stack": "refresh",
				"condition": {
					"source": "hp_ratio",
					"of": "host",
					"op": "lte",
					"value": 0.5
				}
			}
		]
	}
}
```

### 5-3. `resources/balance/master/characters/char_debug_status/skills.json` に **8件目**

⚠ **既存の7件を1文字も変えない。** 末尾の `}` の手前に足す（`skill_dbg_react_followup` の `}` に `,` を付ける）。
⚠ **7件目（`skill_dbg_react_followup`）だけインデントが1タブ深い**（宿題20・見た目だけ）。**真似しないこと。**

⚠ **見る相手の状態は `status_edbg_dot`**（検証用の敵 `enemy_dbg_dot` が付ける毒）。
`condition.status_id` は**この効果の `status_id` とは別物**。

⚠ **`target` が `team: "ally" / sort: "all"` なのは意図（初稿の `team: "self"` は誤り・2026-08-17に修正）。**
`self` だと条件付きバフが `char_debug_status`（`party_0`）にしか付かないが、
敵の毒は `sort: "nearest"` で**一番手前の別のキャラ（`party_2`）に飛ぶ**。
条件は「宿主に毒があるか」を正しく見て `false` を返し続けるので、**バグではなく噛み合っていないだけ**になる（1回目の実測がこれ）。
→ **味方3人全員に条件付きバフを配れば、毒が誰に飛んでも必ず1人は真になる。**
✅ **副産物**：3件のうち**1件だけ**が真になるので、**条件が状態1件ごとに別々に評価されている証拠**が同時に取れる。

```json
	"skill_dbg_cond_poison": {
		"name_key": "ui_battle_skill_dbg_cond_poison",
		"user_character_id": "char_debug_status",
		"unlock_level": 1,
		"cooldown_sec": 1.0,
		"activation": "instant",
		"target": {
			"team": "ally",
			"mode": "select",
			"sort": "all"
		},
		"effects": [
			{
				"type": "buff",
				"host": "unit",
				"status_id": "status_dbg_cond_poison_atk",
				"stat": "atk",
				"value": 50,
				"duration_sec": 120.0,
				"stack": "refresh",
				"condition": {
					"source": "status_has",
					"of": "host",
					"op": "gte",
					"value": 1,
					"status_id": "status_edbg_dot"
				}
			}
		]
	}
```

### 5-4. `resources/balance/master/characters.json` の `char_debug_status` の `"skills"` に **1行**

⚠ **これを忘れるとスキルが画面のボタンに出ない**（`skills.json` だけでは候補一覧に載らない）。
`"skill_dbg_react_followup"` の後ろに `,` を付けて足す。

```json
			"skill_dbg_cond_poison"
```

### 5-5. `resources/balance/master/stages.json` に `stage_dbg_condition` を1件

⚠ **このファイルだけトップレベルが半角スペース2つ・中がタブ。** 既存の `stage_dbg_enemy_skill` の書き方に合わせる。
**末尾の `}` の手前に**足す（`stage_dbg_enemy_skill` の `}` に `,` を付ける）。

```json
  "stage_dbg_condition": {
	"name_key": "ui_stage_dbg_condition",
	"party_id": "party_default",
	"rewards": { "gold": 1 },
	"waves": [
	  { "wave_index": 1, "enemies": [ { "enemy_type_id": "enemy_dbg_cond", "count": 1 } ] },
	  { "wave_index": 2, "enemies": [ { "enemy_type_id": "enemy_dbg_dot", "count": 1 } ] }
	]
  }
```

⚠ **1波目＝敵側のHP依存条件。2波目＝味方側の「毒が付いている間」。** 分けてあるので混ざらない。

### 5-6. `resources/balance/master/stage_order.json` の `"debug"` に **1行**

⚠ **`"story"` は1文字も触らない。**

```json
{
  "story": ["stage_1", "stage_2", "stage_3"],
  "debug": ["stage_dbg_enemy_skill", "stage_dbg_condition"]
}
```

### 5-7. `localization/ja.csv` に **4行**

⚠ **UTF-8（BOMなし）。編集後は人間が再インポート。**

```
ui_battle_enemy_dbg_cond,検証・条件
ui_battle_skill_edbg_cond_hp,窮鼠の牙（敵）
ui_battle_skill_dbg_cond_poison,毒への備え
ui_stage_dbg_condition,検証用・条件
```

### 5-8. 差し込み方（⚠ `edit_file` はこのプロジェクトで動かない）

- `enemies.json` / `characters.json` / `stages.json` / `char_debug_status/skills.json` は
  **末尾の `}` を消し、手前のエントリに `,` を足してから `cat >>` で追記し、最後に `}` を戻す**
- `enemies/enemy_dbg_cond/skills.json` は**新規ファイル**なので、フォルダを作って丸ごと書く
- `stage_order.json` は3行しかないので**丸ごと書き直す**
- ⚠ **ファイル全体を閉じる最後の `}` を戻し忘れない。** JSON が壊れると起動時に全部のマスターが読めなくなる
- ⚠ **追記したら改行コードを確かめる**（`cat >>` は CRLF になる・宿題／§4-8）

### 5-9. Ziva への注意

- **`.gd` を1文字も触らない。** 直す必要があると思ったら、**直さずに報告して止まる**
- 書いたら `IMPL_LOG_SKILL_CONDITION.md` を `docs/03_log/` に生成する

---

## 6. 完了条件

⚠ **検証用3体は、冒険選択画面の「編成」から選ぶ**（`EXEC_PARTY_MEMBERS.md`・2026-08-17に入った）。
**`parties.json` はもう触らない。戻す作業も要らない**（§4-7 の「戻し忘れ」はこれで構造的に消えた）。

### 6-A. ログ（Godot の出力パネル）

1. `skills validated: **47** entries, 0 errors, **1** warnings`（45 ＋ 2）。⚠ **黄は `skill_dbg_dot_odd` の1本のまま。増えていたら赤扱い**
2. `basic attacks validated: **16** entries, 0 errors, 0 warnings`（15 ＋ 1）
3. 起動時に赤が出ない
4. 戦闘中に赤が出ない。⚠ **特に「条件の相手が居ない」系の警告が流れ続けていないこと**（§3-1(f)：出さないと決めてある）

### 6-B. ファイル（`user://logs/battle_last.jsonl` を読む）

**実体は `C:/Users/<user>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/`。**

#### 1波目（`enemy_dbg_cond`）— **「一度も真にならない」と「常に真」を潰す**

5. `ev:"condition"` の行が**存在する**。⚠ **1行も無ければ、条件が一度も評価されていない**（この回で一番あり得る無音事故）
6. `status:"status_edbg_cond_atk"` の最初の `condition` 行が **`why:"add"` かつ `active:false`**。
   ⚠ **`active:true` で始まっていたら「常に真」**（HP満タンなのに `hp_ratio <= 0.5` が真＝比較の向きが逆）
7. そのあと **`why:"change"` かつ `active:true`** の行が出る。⚠ **これが出なければ「一度も真にならない」**
8. 7 の行の `t` より**前**の `ev:"damage"` で `src:"enemy_dbg_cond..."` の `amount` が **5**、
   **後**の同じ行の `amount` が **25**。⚠ **数字が変わらなければ、`active` が立っても補正が組み直されていない**（§4-3）
9. 6 と 7 の間に `condition` の行が**何十行も並んでいない**（＝毎フレーム出していない・§4-4）

#### 2波目（`enemy_dbg_dot` ＋ 味方の `skill_dbg_cond_poison`）— **「偽に戻る」を潰す**

⚠ **2波目に入ったら、`char_debug_status` の「毒への備え」を1回押す**（以降は自動）。

10. `status:"status_dbg_cond_poison_atk"` の `condition` / `why:"add"` が **3行**出る（味方3人ぶん）。**全部 `active:false`**
11. ⚠ **そのうち、毒が付いた1人だけ**に `why:"change"` / `active:true` が出る。
    **残り2人には出ない。** これが「条件が状態1件ごとに別々に評価されている」証拠
12. 11 の `unit` が、`status:"status_edbg_dot"` の `status_add` の `unit` と**一致している**
13. 11 の `true` のあと、**毒が切れると `why:"change"` / `active:false` が出る**（`status_edbg_dot` の `status_end` と対になる）。
    ⚠ **`true` のまま戻らなければ「剥がれない条件」。この項目がこの回の一番の当たり所**
14. 11〜13 の `true` の区間で、**その `unit` の `damage` の `amount` が跳ね、`false` に戻ったあとに元へ戻る**
    （`atk` 1 → 51 なので `amount` 4 → 50前後）

#### 全体

13. `status_add` の数 ＝ `status_end` ＋ `status_clear` の `count`（条件を足しても壊れていない）
14. `ev:"dot"` の周期が今までどおり（条件を持たない DoT の発火が変わっていない）
15. 本編の `stage_1` を1面通したログに **`ev:"condition"` が1行も無い**
    （⚠ 条件を持たない状態のコストが変わっていないことの確認）

### 6-C. 画面（実機で操作する）

16. 冒険選択の「▼ 検証用」に **`検証用・条件` の行が増えて、押して入れる**。⚠ **本編3ステージと `検証・敵のスキル` の並びが変わっていないこと**
17. 1波目で敵の HP バーが半分を割ったあと、**敵の与ダメージの数字が目に見えて跳ねる**
18. `F3` → `P` で、条件付きの状態に **`cond=off` / `cond=on`** が出る。⚠ **条件が偽の間も行が消えないこと**
19. 本編の `stage_1` を1面通しても、**この回の前と挙動が変わらない**（報酬とクリア記録が今までどおり入る）

### 6-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- `condition` に `source: "distance"` を書くと赤（E56）
- `condition` に `source: "status_count"` を書くと赤（そんな語彙は無い・§2-3）
- `type: "damage"` に `condition` を書くと赤（E62）
- `host: "point"` に `condition` を書くと赤（E61）
- `of: "user"` / `of: "target"` を書くと赤（E57・§2-2）
- `of: "source"`（付与者を見る条件）が動く。⚠ **検証データを置いていない**

---

## 7. この回でやらないこと

- **`point` のオーラ**（宿り先の拡張）
- **スタック閾値**と宿題5（`stack` の上限・消え方・再付与）
- **効果に `when`**（発火時に1回だけ評価するフィルタ）
- **`status_count`**（件数を返す条件）。⚠ 変数表の担当（段階3の後半④）
- 宿題17（DoT で購読が発火しない）の修正
- 介入点3種と復活（**次の回**）
- バランスの調整

---

## 8. 宿題に足すもの（`PROJECT_STATUS.md`）

- 宿題16（リリース前に消すもの）に **`enemies/enemy_dbg_cond/`・`enemies.json` の `enemy_dbg_cond`・
  `char_debug_status` の8件目のスキル・`stage_dbg_condition`・`ja.csv` の4行・
  `MasterDataLoader.ENEMY_DIRS_OPTIONAL` の1行** を足す
- 宿題5（`stack` の5部品）に ⚠ **「条件の回で `status_count` を作らなかったのは、上限が無いまま閾値が書けると
  一度真になったら二度と偽に戻らないため」** を追記する
- **新**：⚠ **条件が偽の間の DoT は発火が失われる**（時計は進む・§3-1(h)）。
  「止まる」ほうが自然な効果を作りたくなったら、`elapsed` を止める2本目の時計ではなく
  **`interval` の基準を別に持つ形**で設計し直すこと
- **新**：⚠ **`point` の条件（オーラ）は真偽が「状態 × ユニットの対」ごとになる。**
  記憶の持ち方もログの持ち方も、この回の `active`（状態1件につき1つ）では足りない

---

## 9. 1回目のテストプレイでわかったこと（2026-08-17・`IMPL_LOG_SKILL_CONDITION.md`）

### 9-1. 結論：**`.gd` の不具合はゼロ。壊れていたのは §5 の検証データ**

Ziva が §5 を指示どおりに差し込み、人間がテストプレイした。**赤は1つも出ていない。**

### 9-2. ✅ この1行で証明されたこと

```
{"t":8.38,"ev":"condition","status":"status_dbg_cond_poison_atk","unit":"party_0","active":false,"why":"add"}
```

- `_fill_condition()` が条件を受け付けた（ロード時検証 `47 / 0 errors / 1 warnings`）
- `add()` の中の初回評価（`_eval_one`）が走り、**正しく `false` を返した**
- `BattleLog.log_condition()` が出た
- ⚠ **§2-4 の2大事故のうち「常に真」は完全に潰れた**

### 9-3. ❌ まだ1ミリも証明されていないこと（**再テストの主目的**）

⚠ **毎フレーム評価（`_eval_conditions()`）が本当に走っているか。**
`why:"change"` が0件なので、**「走っていて偽のままだった」のか「一度も呼ばれていない」のかがログから区別できない。**
→ **真になる場面を1回でも作ることが、この回の残り全部。**

### 9-4. 1波目が成立しなかった本当の理由（**HPの数字ではなかった**）

⚠ **`enemy_dbg_cond` を `attack_range: 50`（近接）にしたのが誤り。**
検証用キャラ3体は**全員 `attack_range: 300`**。敵は6倍の射程差を歩いて詰める間に撃たれ続け、
**射程に入る前に死ぬ。** 敵は「射程内でだけ」撃つので、**スキルが一度も発動しない。**

実測：味方の与ダメージ 4 × 3体 / 2秒 ＝ **約3ダメージ/秒**。`hp: 20` は約7秒で死に、
敵のスキルCD 8秒に**一度も届かない。**

→ **`attack_range: 300` ＋ `hp: 60` に直した**（§5-1）。約10秒で半分、約20秒で死ぬ。

### 9-5. 2波目が成立しなかった理由（**条件は正しく動いていた**）

`skill_dbg_cond_poison` を `target: {team: "self"}` にしたので、条件付きバフは `party_0` にだけ付いた。
一方、敵の毒は `sort: "nearest"` で **`party_2` に飛んだ**。
条件は「宿主（`party_0`）に毒があるか」を**正しく見て `false` を返し続けた**。

⚠ **これはバグではない。テストが噛み合っていないだけ。**
→ **`target` を `team: "ally" / sort: "all"` に直した**（§5-3）。味方3人に配れば、毒が誰に飛んでも必ず1人は真になる。
✅ **副産物**：3件のうち1件だけが真になるので、**条件が状態1件ごとに別々に評価されている証拠**が同時に取れる。

### 9-6. `status_end` が0件だった件は**正常**（`IMPL_LOG` §5-D の「要確認」への回答）

毒は `t=17.22` 付与・寿命8.0秒なので、切れるのは `t=25.22`。**戦闘終了は `t=24.03`。**
⚠ **切れる前に戦闘が終わったので、`status_clear` が掃いたのが正しい挙動。**
`status_add 2 = status_end 0 + status_clear 2` も合っている。**`.gd` を直す必要は無い。**

⚠ 再テストでは 1波目が約20秒に延びるので、**2波目で毒が寿命どおり切れ、`status_end` が出るはず**（§6-B-13 の対）。

### 9-7. `parties.json` は**もう触らない**

`EXEC_PARTY_MEMBERS.md` が入ったので、検証用3体は**冒険選択画面の「編成」から選ぶ**。
`parties.json` は本編3体（`[僧侶, 弓兵, 剣士]`）に戻し済み。**差し替えも戻しも二度と要らない。**

---

## 10. 2回目のテストプレイの判定（2026-08-17・設計役が `battle_last.jsonl` 87行を直読）

### 10-1. ✅ **この回の本丸が通った**

```
{"t":3.94,"ev":"condition","status":"status_edbg_cond_atk","unit":"enemy_1_0","active":false,"why":"add"}
{"t":9.79,"ev":"condition","status":"status_edbg_cond_atk","unit":"enemy_1_0","active":true,"why":"change"}
```

⚠ **`why:"change"` が出た。** これで **`_eval_conditions()` が毎フレーム走っていることが確定した**（§9-3 の唯一の未証明）。
`add` で偽→ 途中で真、なので **「一度も真にならない」も「常に真」も同時に潰れた**（§2-4 の2大事故）。

### 10-2. ✅ 条件が能力値に届いている（`_rebuild_unit_mods` の絞り込み）

| | 敵 `enemy_1_0` の与ダメージ |
|---|---|
| `change/true`（t=9.79）より**前** | `amount: 4`（t=5.94 / 7.94） |
| **後** | `amount: 24`（t=9.94 / 13.95） |

⚠ **完了条件 §6-B-8 に「5 → 25」と書いたが、実測は「4 → 24」。これは正しい。**
`BattleFormula.damage()` は `floor(power × 100 / (100 + def))` で、宿主側に研究・装備の `def` が
**4** 乗っているため。`5×100/104 = 4.8 → 4` ／ `25×100/104 = 24.0 → 24` で式と完全に一致する。
→ **絶対値ではなく「差が +20 か」を見ること。** 味方側も同じで、`4 → 54`（`atk` +50）。

### 10-3. ✅ 条件は状態1件ごとに別々に評価されている

```
{"t":18.83,...,"status_dbg_cond_poison_atk","unit":"party_0","active":false,"why":"add"}
{"t":18.83,...,"status_dbg_cond_poison_atk","unit":"party_1","active":false,"why":"add"}
{"t":18.83,...,"status_dbg_cond_poison_atk","unit":"party_2","active":false,"why":"add"}
{"t":24.4, ...,"status_dbg_cond_poison_atk","unit":"party_2","active":true, "why":"change"}
```

3人に同じ条件付きバフが付き、**毒が飛んだ `party_2` だけが真になった**（毒の `status_add` も同じ `t=24.4` / `party_2`）。
`party_0` / `party_1` には `change` が出ていない。→ **§6-B-11 / 12 が成立。**

### 10-4. ✅ `refresh` の貼り直しでも初回評価が走っている

```
{"t":11.95,"ev":"condition","status":"status_edbg_cond_atk","unit":"enemy_1_0","active":true,"why":"add"}
```

CD 8秒で貼り直された2回目の `add` が、**既にHP半分以下なので `active:true` で始まっている。**
→ `add()` の `entry["active"] = _eval_one(entry)`（§3-1(c)）が `refresh` の置き直しでも効いている。

### 10-5. ✅ ログの量が正しい

条件の行は**7行だけ**（1戦26秒）。毎フレーム出していない（§2-4 / §6-B-9）。

### 10-6. ⚠ `status_add` と `status_clear` の釣り合いは、`refresh` を数に入れると合わない

実測：`status_add` **6行** ／ `status_end` **1件**（`host_dead`）／ `status_clear` の `count` **4**。
6 ≠ 1 + 4 に見えるが、**`t=11.95` の `status_add` は `refresh` による置き直しで、件数は増えていない。**
→ 実体は 5件付いて、1件が `host_dead`、4件が `status_clear`。**正常。**

⚠ **完了条件 §6-B の「`status_add` の数 ＝ `status_end` ＋ `status_clear`」は `refresh` を数えていない。**
今後この項目を見るときは **`refresh` の再 `add` を引くこと**（`BattleLog` を直す話ではない。宿題へ）。

### 10-7. ❌ 残り1項目：**毒が切れて偽に戻る（§6-B-13）**

毒は `t=24.4` 付与・寿命8.0秒 → 切れるのは `t=32.4`。**戦闘は `t=26.2` で終了。**
2波目の `enemy_dbg_dot`（hp 80）が味方3体の前に約12秒しか持たず、
`skill_edbg_dot` の CD が 12.0 秒なので**毒が撒かれるのが遅すぎる。**

→ **`stages.json` の2波目を `enemy_dbg_dot` ×**2** にした**（`count: 1` → `2`）。
hp 160 になり2波目が約25秒続くので、`t≈24` の毒が `t≈32` に寿命どおり切れる。

⚠ **`enemies/enemy_dbg_dot/skills.json`（CD 12.0）は触っていない。** あれは敵の回で検証済みのデータで、
`stage_dbg_enemy_skill` からも使われている。**検証用ステージ側の数で調整するほうが影響が閉じる。**

### 10-8. 3回目で見るのはこれだけ

| | 見るもの |
|---|---|
| **本命** | `status_dbg_cond_poison_atk` に **`why:"change"` / `active:false`** が出る（毒の `status_end` と対） |
| 対 | `status:"status_edbg_dot"` の `ev:"status_end"` / `why:"expire"` が出る（§9-6 の積み残し） |
| 戻り | その `unit` の `damage` の `amount` が **54 → 4 に戻る** |

⚠ **1波目はもう見なくてよい**（10-1〜10-2 で完全に通っている）。

---

## 11. 3回目のテストプレイの判定（2026-08-17・`battle_last.jsonl` 106行を直読）

### 11-1. ✅ 増えた合格：**能力値が真の区間だけ跳ねて戻る手前まで確認できた**

```
{"t":24.7,"ev":"condition","status":"status_dbg_cond_poison_atk","unit":"party_2","active":true,"why":"change"}
{"t":24.56,"ev":"damage","src":"party_2","dst":"enemy_2_0","amount":4}    ← 真になる前
{"t":26.59,"ev":"damage","src":"party_2","dst":"enemy_2_0","amount":54}   ← 真になった後
{"t":28.63,"ev":"damage","src":"party_2","dst":"enemy_2_1","amount":54}
{"t":30.67,"ev":"damage","src":"party_2","dst":"enemy_2_1","amount":54}
```

⚠ **`4 → 54`（`atk` +50）がぴったり。§6-B-14 の「跳ねる」側は成立。**
1波目（`4 → 24`）も2回目と同じく再現している。**§6-B-5〜12 は2回連続で通った。**

### 11-2. ❌ 残る1項目：**偽に戻る（§6-B-13）が、また戦闘終了に間に合わなかった**

毒は `t=24.7` 付与・寿命8.0秒 → 切れるのは `t=32.7`。**戦闘終了は `t=30.72`。あと2.0秒**。

### 11-3. ⚠ 見つけた罠：**この検証には負のフィードバックがある**

**条件バフが効くと味方が強くなり、戦闘が短くなり、検証の窓が縮む。**

実測：`party_2` の与ダメージが真になった瞬間に `4 → 54` に跳ね、
2波目が予定より早く終わった（160HP を 16.3秒で片付けた）。
⚠ **「敵のHPを増やす」で押し切ろうとすると、増やすほど強化後の火力で削られるので効きが鈍い。**

### 11-4. ⚠ 2体にしたのは逆効果だった（10-7 の判断ミス）

`enemy_dbg_dot` を2体にしたので、**毒が2件（`independent`）付いた。**

```
{"t":24.7, "ev":"status_add","status":"status_edbg_dot","unit":"party_2","src":"enemy_2_0"}
{"t":27.18,"ev":"status_add","status":"status_edbg_dot","unit":"party_2","src":"enemy_2_1"}
```

⚠ **`status_has` は「1件でもあるか」なので、1件目が切れても2件目が残っている限り真のまま。**
偽に戻るのは**2件目が切れる `t=35.18`** になり、**窓が遠のいた。**
→ **毒を撒く敵は1体に戻すこと。**

### 11-5. 直したもの：**2波目を「毒1体 ＋ 壁2体」にした**

```json
{ "wave_index": 2, "enemies": [
  { "enemy_type_id": "enemy_dbg_dot", "count": 1 },
  { "enemy_type_id": "enemy_dbg_buff", "count": 2 } ] }
```

- **毒は1体だけ**（11-4）。付与は1件なので、寿命8秒でそのまま切れる
- **`enemy_dbg_buff` ×2 は毒を撒かない壁**。240HP になるので2波目が約22秒続き、
  `t≈24.7` の毒が `t≈32.7` に切れるまでに**約4秒の余裕**ができる
- ✅ **副産物**：`enemy_dbg_buff` の自己バフは寿命6秒／CD8秒なので、
  **`status_end` / `why:"expire"` が必ず出る。** §9-6 で積み残した
  「寿命で切れる `status_end` が出る経路」がこの1回で一緒に埋まる

⚠ **`enemies/enemy_dbg_dot/skills.json`（CD 12.0・`attack_range` 50）は今回も触っていない。**
毒が `t≈24.7` と遅いのは、この敵が**近接（射程50）で、射程300の味方まで歩く**ため（1波目と同じ構図）。
だが**あれは敵の回で検証済みのデータで `stage_dbg_enemy_skill` からも使われている。**
**検証用ステージ側の数で調整するほうが影響が閉じる。**

### 11-6. 4回目で見るのはこれだけ（**2波目のみ**）

| | 見るもの |
|---|---|
| **本命** | `status_dbg_cond_poison_atk` / `party_?` に **`why:"change"` / `active:false`** が出る |
| 対 | `status:"status_edbg_dot"` の **`ev:"status_end"` / `why:"expire"`** が出る |
| 戻り | その `unit` の `damage` の `amount` が **54 → 4 に戻る** |
| ついで | `status:"status_edbg_buff_atk"` の `status_end` / `why:"expire"` が出る（§9-6 の積み残し） |

⚠ **1波目はもう見なくてよい**（2回連続で完全に通っている）。
⚠ **2波目に入ったら「毒への備え」を1回押して、あとは最後まで放置する。**

---

## 12. 4回目のテストプレイ ＝ **完了**（2026-08-17・`battle_last.jsonl` 249行を直読）

### 12-1. ✅ 本命が通った：**偽に戻る**

```
{"t":32.66,"ev":"status_end","status":"status_edbg_dot","unit":"party_2","why":"expire"}
{"t":32.71,"ev":"condition","status":"status_dbg_cond_poison_atk","unit":"party_2","active":false,"why":"change"}
```

毒が寿命で切れた **0.05秒後（＝次のフレーム）** に条件が偽に戻った。
→ **「剥がれない条件」が潰れた。** これで §2-4 の3つの無音事故
（一度も真にならない／常に真／真のまま戻らない）が**全部潰れた。**

### 12-2. ✅ 能力値が真の区間だけ跳ねて、戻った（§6-B-14 完全成立）

| t | `party_2` の `damage` | |
|---|---|---|
| 〜28.78 | **4** | 条件は偽 |
| 30.82 | **54** | 条件が真（`atk` +50） |
| 32.85 〜 45.07 | **4** | 偽に戻ったあと |

⚠ **往復した。** `_rebuild_unit_mods()` の絞り込み1行が、付けるほうにも剥がすほうにも効いている。

### 12-3. ✅ 想定より強い証拠が取れた（`add` の時点で3件が別々の答えを返した）

```
{"t":29.56,...,"unit":"party_0","active":false,"why":"add"}
{"t":29.56,...,"unit":"party_1","active":false,"why":"add"}
{"t":29.56,...,"unit":"party_2","active":true, "why":"add"}   ← 毒は t≈24.7 に party_2 へ付いていた
```

人間がボタンを押したのが毒より**後**だったので、**同じ1回の `cast` で作られた3件が、
その場で別々の真偽を返した。** §6-B-10 は「3行とも `active:false`」と書いてあるが、
**これは押す順番の違いで、より強い結果。合格とする。**
（「毒より先に押す」順は2回目・3回目のログで `add:false → change:true` として確認済み）

### 12-4. ✅ §9-6 の積み残しも埋まった

`status_end` / `why:"expire"` が **7件**出た（`status_edbg_dot` ×1、`status_edbg_buff_atk` ×6）。
→ **寿命で切れる `status_end` の経路は正常。** 2回目に0件だったのは戦闘が先に終わっていただけ。

### 12-5. ✅ 状態の釣り合い（§10-6 の書き方で数え直す）

| | 件数 |
|---|---|
| `status_add` の**行数** | 13 |
| うち **生きている状態への `refresh` 貼り直し**（＝件数が増えない） | 1（`status_edbg_cond_atk` の t=12.1） |
| **実体の件数** | **12** |
| `status_end` | 9 |
| `status_clear` の `count` 合計 | 3 |

**12 ＝ 9 ＋ 3。合う。**

⚠ **`status_edbg_buff_atk` は寿命6秒／CD8秒なので「切れてから付け直す」を繰り返す。**
これは `refresh` の貼り直しではなく**毎回が新しい件**。
→ **数えるときは「同じ status+unit+src」でまとめてはいけない。**「生きている間に上書きされた回数」だけを引くこと。

### 12-6. ✅ ログの量

条件の行は**7行**（1戦59秒）。毎フレーム出ていない（§2-4 / §6-B-9）。

### 12-7. ✅ 残りも全部通った（2026-08-17）

| | 結果 |
|---|---|
| §6-C 画面：`P` で `cond=on/off` が出る | ✅ `#7 status_dbg_cond_poison_atk buff host=unit(party_2) 付与=party_0 stack=refresh **cond=off** 経過 6.32/120.00秒 \| atk +50`。⚠ `on` 側は窓が8秒／3人中1人なので手押しで取れないが、`battle_last.jsonl` で4回分証明済み |
| §6-B-16 本編 `stage_1` のログに `ev:"condition"` が0行 | ✅ **0行**。965行の内訳は `cast` 479 / `damage` 479 / `wave` 5 / `battle_start` 1 / `result` 1 のみ |
| §6-C 画面：本編 `stage_1` の挙動が変わらない | ✅ 全5ウェーブ勝利（`t=204.39`） |

⚠ **`.gd` は4回のテストを通して1行も直していない。** 直したのは検証データ（§9〜§11）だけ。

**この回は完了。**
