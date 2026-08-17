# EXEC — **介入点3種（回復・状態付与・死亡）＋ 復活**

段階3の後半③。`PLAN_SKILL_TEMPLATE.md` 11章の「割り込む場所は4つ」のうち、**残る3つ**を作る。

| 対象 | 例 | 状況 |
|---|---|---|
| ダメージ | シールド・軽減・反射・貫通%・確定クリティカル | **段階1で受け口だけ作った**（`_step_crit_override` / `_step_reduction`・⚠ **両方 `pass` のまま**） |
| **回復** | 被回復低下・回復量増加 | **この回** |
| **状態の付与** | CC耐性・デバフ無効・免疫 | **この回** |
| **死亡** | HP1で耐える・**復活**・死亡時発動 | **この回** |

> ⚠ **全滅判定より、死亡の介入点が先**（PLAN 11-1）。これを外すと**戦闘が終わってから復活する**事故が起き、無音で壊れる。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **死亡の検出** | ⚠ **`battle_controller._process()` の勝敗判定の直前に走査を1本置く。** 全ユニットを見て「HPが0かつ未処理」のものに介入点を通す。`BattleUnit` に「死亡処理済み」のフラグを1つ足す（復活したら戻す）。**`take_damage()` の中では検出しない**（`BattleUnit` は `RefCounted` で器も session も知らないため、復活を書くと契約が変わる） |
| **この回で作る利用者** | ⚠ **3種とも最小の利用者を1件ずつ作る。** 死亡＝**復活** ／ 状態付与＝**免疫** ／ 回復＝**被回復増減**。受け口だけにしない |
| **復活の書き方** | ⚠ **`buff` に `on_death` の欄を足す。** `react` に `event:died` を足す案は採らない（`EVENTS_KNOWN` の追加＋`SkillRuntime` への配線が要り、しかも復活そのものは「死者に `heal` を当てる」形になれず結局 `target` の外の話になる） |

### 0-1. 採らなかった案と、その理由

- **`take_damage()` の中で死亡検出**：死んだ瞬間に分かるが、`unit.gd` が器と session を知る必要が出る。`RefCounted` のままでいられなくなる
- **ダメージを与える各所でその場で判定**：`_apply_damage()` / `_fire_intervals()` / F3 の自傷の3箇所以上に散る。**PLAN 11-1 の「ブレると4箇所バラバラになる」を最初から踏む**
- **`react` ＋ `event:died`**：「死亡時発動」（＝他の効果を撃つ）を書くならこちらが正しい。⚠ **復活とは別の機能**なので、④以降に回す（§8の宿題）

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-17**）

| | 状態 |
|---|---|
| ダメージの介入点 | `skill_resolver.gd:376-382`。⚠ **`_step_crit_override()` / `_step_reduction()` は2本とも `pass`。** 段階1で受け口だけ作り、**12スキル書いても利用者が1件も付かなかった**（`PROJECT_STATUS.md:388`） |
| 介入点の形 | `static func _step_xxx(ctx: Dictionary) -> void`。`ctx` を順に加工する（PLAN 11-0-1「1本の数式にしない」） |
| 回復 | `skill_resolver.gd:388-403` `_apply_heal()`。⚠ **全対象に同じ数値を配る**（対象ごとに計算し直さない）。会心も `atk_multiplier` も介入点も通っていない |
| 状態の付与 | `status_registry.gd:80-207` `add()`。⚠ **169行に「ここまで状態を1つも触っていない」**とあり、`CLAUDE.md` 6番の形が既に守られている。**弾くならこの行より前** |
| ⚠ **死亡** | **置く場所が存在しない。** `take_damage()` は `hp = max(0, hp - amount)` するだけ（`unit.gd:208-211`）で、死んだことに誰も気づかない。各所が `is_alive()` を都度見ているだけ |
| 全滅判定 | `battle_controller.gd:425-431`。⚠ **`_status.tick(delta)`（423行）の直後** |
| `buff` の欄埋め | `status_registry.gd:262-278` `_fill_buff()`。⚠ **`stat` は10軸必須・`value` は0以外の整数必須。** 両方無い buff は今は書けない |
| `buff` のロード時検証 | `skill_schema.gd:653-666`（E37 / E38 / E39）。⚠ **E番号は E62 まで使用済み。この回は E63 から** |
| ⚠ 効果の欄の「知らない欄」検出 | **無い。** E26（`skill_schema.gd:363`）が見ているのは **スキル直下**（`SKILL_FIELDS_KNOWN`）だけ。**効果の中の typo（`on_dead`）は今も無音で無視される** |
| `BattleLog` | `write(ev, fields)` が汎用。専用関数が `log_cast` / `log_results` / `log_react` / `log_condition` / `log_status_add` / `log_status_end` / `log_status_clear` / `log_wave` / `log_result` |

### 1-1. ⚠ **実コードで見つけた、この回の設計を決める事実**（**報告**）

**`StatusRegistry._drop_dead_hosts()` が `tick()` の先頭（`status_registry.gd:433`）で、宿主が死んだ状態を全部捨てている。**

`battle_controller._process()` の並びはこうなっている：

```
401-404  _step_unit()          … 通常攻撃。ここで死にうる
414      _skill_runtime.tick() … スキル。ここでも死にうる
423      _status.tick()        … ⚠ 先頭で _drop_dead_hosts() が走る
425-431  勝敗判定
```

⚠ **通常攻撃で死ぬと、423 行の `_drop_dead_hosts()` が「復活を与えていた状態」ごと捨てる。**
決定どおり走査を勝敗判定の直前（424 行あたり）に置くと、**そこに着く頃には復活の状態が消えている。**

⚠ **走査を `_status.tick()` の前に動かしても解決しない。** DoT で死ぬ経路（`_fire_intervals()`・`status_registry.gd:632`）は `_status.tick()` の**中**なので、今度はそちらが1フレーム遅れ、**次のフレームの `_drop_dead_hosts()` に先に食われる。** 鏡写しに壊れるだけ。

**→ この回の要件が1つ増える：**

> **`_drop_dead_hosts()` は「宿主が死んだが、死亡の介入点をまだ通していない」状態を捨てない。**
> 介入点が処理済みの印を付けた**次のフレーム**に、いつもどおり捨てる。

⚠ **これは「走査の置き場所」の話ではなく「状態の掃除の順序」の話。** PLAN 11-1 は全滅判定としか書いていない。**PLAN 側の穴として §8 の宿題に送る。**

### 1-2. ⚠ もう1件（**直していない・報告のみ**）

`_rebuild_unit_mods()`（`status_registry.gd:825-826`）は `stat` が `""` の状態でも `mods[""] += 0` を書く。
今は全 buff が `stat` を必須にしているので `""` は起きないが、**この回で `stat` の無い buff（＝介入だけを持つ buff）を許すので起きるようになる。**
`get_stat()` は `_stat_mods.get(stat_key, 0)` をキーで引くので `""` は誰にも当たらず**実害は無い**が、F3 パネルに空キーが出る。**この回で1行ガードを足す**（§3-3）。

---

## 2. ⚠ 事故りやすい箇所

### 2-1. 介入点3つを「同じ作り方」にする（PLAN 11-1 の条件）

⚠ **ブレると4箇所バラバラになる。** 段階1の `_step_crit_override(ctx)` に合わせ、**3つとも `ctx: Dictionary` を1つ取って書き換える形**にする。
戻り値で分岐する形（`-> bool`）と混ぜないこと。**呼ぶ側は `ctx` の欄を読んで判断する。**

### 2-2. 死亡の走査は「全滅判定の直前」の1箇所だけ

⚠ **2箇所目を作らない。** 「DoT の死は `_fire_intervals()` で拾う」を足した瞬間に、片方だけ直す事故になる（表示経路を1本に保ったのと同じ理由）。

### 2-3. ⚠ 復活の順序は「発火 → 全消し」（PLAN 14-4）

**HPを戻してから `clear_for_unit()` する。** 逆にすると、復活を与えていた状態が先に消えて**発火しない。**
⚠ **「1回だけ」はこの全消しが保証する。** カウンターを足さないこと（PLAN 14-4 の ✅）。

### 2-4. ⚠ 復活しても `is_alive()` が真に戻るだけ

- **CDはリセットしない**（PLAN 14-4）
- **`target_unit_id` は復活後に `_acquire_target_if_needed()` が拾い直す**（`battle_controller.gd:434-441`）。走査で触らないこと
- ⚠ **`UnitView._process()` は `is_alive()` が偽の間 `hide()` する**（`unit_view.gd:55-58`）。`BattleController._process()` と `UnitView._process()` のどちらが先に走るかは**保証されていない**ので、**復活のフレームに1フレームだけ消えることがありうる。** 直さない（§7 の見え方に注記する）

### 2-5. ⚠ 死亡処理済みのフラグを戻す場所

**復活したとき**と、**ウェーブ交代・リトライで作り直したとき。**
⚠ 後者は `BattleUnit` を作り直すので既定値 `false` で足りる。⚠ **走査の側で「生きているなら `false` に戻す」を書くこと**（復活の直後に必ず通る）。

### 2-6. ⚠ `stat` の無い buff を許すことの波及

`_fill_buff()` の必須チェックを緩めるので、**`stat` の typo が「介入だけの buff」として黙って通る**ようになる。
→ **ロード時検証（E63〜）で「介入の欄も `stat`/`value` も無い buff」を赤で弾くこと。** ここを省くと `CLAUDE.md` 1番の再発になる。

### 2-7. ⚠ 免疫は「付けさせない」であって「すぐ剥がす」ではない

`add()` が `false` を返して**登録しない。** 登録してから消す形にすると、`status_add` がログに出てしまい「付いたのに消えた」と読める。
⚠ **`BattleLog.log_status_add()` は169行より後（登録後）にあるので、169行より前で弾けば自然に出ない。**

### 2-8. ⚠ 検証用スキルを `skills.json` に足しただけでは画面に出ない

候補の一覧と並び順は **`characters.json` の `"skills"` 配列**が決める（`game_manager.gd:1745`）。
⚠ **ロード時検証は `skills.json` しか見ないので、忘れてもログは `0 errors` と正常に見える。**（購読の回で実機で踏んだ・`PROJECT_STATUS.md:442`）

---

## 3. 実装（ファイル別）

⚠ **関数を足す前に `grep -n "func <名前>"`、足したあとにも `grep -n` で当たったか確認する**（`CLAUDE.md` 2番）。

### 3-0. 器の語彙 — `buff` に足す3つの欄

**`stat` / `value` の代わりに、次のいずれか1つを持てる**ようにする。

| 欄 | 形 | 何をするか |
|---|---|---|
| `on_death` | `{ "revive_hp_ratio": float }` | 宿主が死んだとき、最大HPのその割合で復活する |
| `block_status` | `Array[String]`（status_id の配列） | その status_id を宿主に付けさせない |
| `heal_taken_pct` | `int`（負なら低下） | 宿主が受ける回復量を ％ で増減する |

⚠ **3つを同時に持ってよい。** 排他にしない（「毒に免疫かつ被回復低下」は普通に書きたくなる）。
⚠ **`stat`/`value` と同時に持ってもよい**（「攻撃力＋10かつ毒に免疫」）。
⚠ **どれも無い buff は赤**（E63）。

> **なぜ `intervene{}` の入れ子にしないか**：人間の決定が「`buff` に `on_death` の欄」だったため、兄弟の欄として揃えた。
> ⚠ **4つ目が来たら入れ子に畳むこと**（§8の宿題）。

### 3-1. `scripts/systems/skill_schema.gd` — ロード時検証（E63〜E67）

`_validate_effect()` の `EFFECT_BUFF` の枝（653-666行）を書き換える。

| 番号 | 内容 |
|---|---|
| **E63** | `stat`/`value` も介入の欄（`on_death` / `block_status` / `heal_taken_pct`）も1つも無い buff は赤。⚠ **今の E37〜E39 を「`stat` があるときだけ見る」に変える**（無条件必須をやめる） |
| **E64** | `on_death` が Dictionary でない、または `revive_hp_ratio` が **0より大きく1以下の数値**でない |
| **E65** | `block_status` が配列でない、空、または要素が文字列でない |
| **E66** | `heal_taken_pct` が整数でない、または **0**（何も起きない介入は書かせない。E39 と同じ考え方） |
| **E67** | 介入の欄が `buff` 以外（`dot` / `react` / `damage` / `heal`）に書かれている。⚠ **`host: unit` 以外にも書けない**（宿主が居ないと誰に効くか決まらない） |

⚠ **`EFFECT_TYPES_*` の一覧に何も足さない。** 効果の種類は増えていない。

### 3-2. `scripts/systems/status_registry.gd` — 欄埋め・介入点2つ・掃除の順序

#### (a) `_fill_buff()`（262行）を書き換える

- `stat` が**書かれているときだけ**10軸チェックと `value` チェックを走らせる
- `on_death` / `block_status` / `heal_taken_pct` を `entry` に写す（⚠ **`duplicate(true)` する**。`_fill_react` / `_fill_condition` と同じ理由）
- **3つとも無く `stat` も無ければ `false`**（ロード時検証と二重に守る）

#### (b) `_make_entry()`（223-259行の戻り値）に3欄足す

`"on_death": {}` / `"block_status": []` / `"heal_taken_pct": 0`
⚠ **持たない件にも必ず持たせる**（`"active"` の注記と同じ。持たない件があると `query()` が黙って外す）。

#### (c) 状態付与の介入点 — `add()` の169行より前

```gdscript
# --- 6-3. 状態付与の介入点（PLAN 11-1）。⚠ 状態を1つも触っていないここで弾く ---
var block_ctx: Dictionary = {
	"status_id": status_id, "kind": kind, "host_unit": host_unit,
	"source": source, "blocked": false, "blocked_by": "",
}
_step_status_block(block_ctx)
if bool(block_ctx["blocked"]):
	BattleLog.log_intervene("status", str(...host_unit_id...), status_id, str(block_ctx["blocked_by"]))
	return false
```

`_step_status_block(ctx)` の中身：**宿主に付いている buff のうち `block_status` に `status_id` を含むものを探し、あれば `ctx["blocked"] = true`。**
⚠ **`active` が偽の件は見ない**（条件付き免疫が偽の間に効いてしまう）。

#### (d) 死亡の介入点 — 新設の公開関数

```gdscript
# 宿主の死亡に介入するものがあるか。介入したら true。
# ⚠ 呼ぶのは battle_controller._step_deaths() の1箇所だけ（PLAN 11-1）。
func resolve_death(unit: BattleUnit) -> bool:
```

- `ctx` を作って `_step_death(ctx)` を通す
- `ctx["revived"]` が真なら：**HPを戻す → `BattleLog.log_intervene("death", ...)` → `clear_for_unit(unit.unit_id)`**（⚠ **この順**・§2-3）
- ⚠ **`unit.hp` を直接書かない。** `unit.heal(int(...))` を通す（`unit.gd:6` の「必ず `take_damage()` / `heal()` 経由」）

`_step_death(ctx)`：**宿主に付いている buff のうち `on_death` を持つものを探し、あれば `ctx["revived"] = true` / `ctx["revive_hp"] = 最大HP × revive_hp_ratio`（⚠ **最低1**）。**
⚠ **`active` が偽の件は見ない**（(c) と同じ）。

#### (e) ⚠ `_drop_dead_hosts()`（459行）に1条件足す（**§1-1 の本体**）

```gdscript
var host: BattleUnit = _find_unit(str(entry.get("host_unit_id", "")))
if host != null and host.is_alive():
	rest.append(entry)
	continue
# ⚠ 死んだが、死亡の介入点をまだ通していない → このフレームは捨てない（§1-1）。
#   捨てると、通常攻撃で死んだ相手の復活が、走査に着く前に消える。
if host != null and not host.death_handled:
	rest.append(entry)
	continue
```

#### (f) `_rebuild_unit_mods()`（825行）に1行ガード（§1-2）

`var stat_key: String = str(entry.get("stat", ""))` の直後に `if stat_key == "": continue`

### 3-3. `scripts/systems/unit.gd` — フラグ1つ

```gdscript
# 死亡の介入点（復活）を通したか（PLAN 11-1）。
# ⚠ 書いてよいのは battle_controller._step_deaths() だけ。
# ⚠ 復活したら false に戻す。戻さないと2回目の死亡で介入点を通らない。
# ⚠ StatusRegistry._drop_dead_hosts() がこれを読む（§1-1）。真になるまで
#   宿主の状態を捨てない。
var death_handled: bool = false
```

⚠ **`take_damage()` / `heal()` / `is_alive()` は1文字も変えない。**

### 3-4. `scripts/systems/skill_resolver.gd` — 回復の介入点

`_apply_heal()`（388行）を書き換える。⚠ **「全対象に同じ数値を配る」を保つが、介入は対象ごと**（被回復低下は受け手の性質だから）。

```gdscript
var base_amount: int = int(floor(...))   # 今までどおり。1回だけ計算する
for t: BattleUnit in targets:
	if t == null:
		continue
	var ctx: Dictionary = { "target": t, "amount": base_amount, "pct": 0 }
	_step_heal_taken(ctx, registry)
	var amount: int = int(ctx["amount"])
	t.heal(amount)
	results.append({ "unit_id": t.unit_id, "amount": amount, "is_heal": true, "is_crit": false, "is_dot": false })
```

⚠ **`_apply_heal()` に `registry` を渡す引数が1つ増える**（呼び出し元は `resolve()` の290行の1箇所だけ）。
⚠ **`base_amount` を作り直さないこと**（PLAN 11-0 の不変条件「式を2回評価しない」）。介入は確定値に％を掛けるだけ。
⚠ **0未満にしない**（`maxi(0, ...)`）。⚠ **`heal(0)` は `unit.gd:216` が弾くので、被回復100%低下は「数字も出ない」が正しい。**

`_step_heal_taken(ctx, registry)`：**対象に付いている buff の `heal_taken_pct` を合計し、`amount` に掛ける。**
⚠ **`registry` の型は `RefCounted` のまま**（`skill_resolver.gd:216-221` の Cyclic reference の注記と同じ理由）。

⚠ **`_apply_damage()` の2本の受け口（`_step_crit_override` / `_step_reduction`）はこの回でも `pass` のまま。** 触らない。

### 3-5. `scripts/systems/battle_log.gd` — 1本足す

```gdscript
# 介入点が効いた（PLAN 11-1）。3種を1本にまとめる。
# ⚠ 種類ごとに3本作らないこと（片方だけ直す事故になる）。
static func log_intervene(kind: String, unit_id: String, status_id: String, detail: String) -> void:
```

`kind` は `"death"` / `"status"` / `"heal"`。イベント名は `intervene`。

### 3-6. `scenes/adventure/battle_controller.gd` — 死亡の走査

`_status.tick(delta)`（423行）と勝敗判定（425行）の**間**に置く。

```gdscript
	# 4. 死亡の介入点（PLAN 11-1）。⚠ 勝敗判定より先。
	#
	# ⚠ ここを勝敗判定の後ろに置くと「戦闘が終わってから復活する」。
	# ⚠ _status.tick() の後ろであること。DoT の止めの一撃も同じフレームで拾う。
	# ⚠ 走査は1箇所だけ。ダメージを与える各所に2本目を作らないこと。
	_step_deaths()

	# 5. 勝敗判定（敗北判定を先に行う）
```

```gdscript
func _step_deaths() -> void:
	for unit in _session.party_units:
		_resolve_one_death(unit)
	for unit in _session.enemy_units:
		_resolve_one_death(unit)


func _resolve_one_death(unit: BattleUnit) -> void:
	if not (unit is BattleUnit):
		return
	if unit.is_alive():
		# 復活した／まだ死んでいない。次の死亡で介入点を通せるように戻す。
		unit.death_handled = false
		return
	if unit.death_handled:
		return
	unit.death_handled = true
	_status.resolve_death(unit)
```

⚠ **`_status.resolve_death()` の戻り値でここが分岐しない。** HPを戻すのも状態を消すのも器の側の責務。

---

## 3-7. ⚠ Ziva に出す分（JSON ＋ `ja.csv`）

**§9 に切り出した。** `.gd` を1行も触らない、データだけの作業。**§3 の `.gd` が全部入ったあとに渡すこと**（先に渡すと、ロード時検証が知らない欄として赤を出す）。

---

## 4. 変えないもの

- `_step_crit_override()` / `_step_reduction()`（ダメージの受け口・**`pass` のまま**）
- `BattleUnit.take_damage()` / `heal()` / `is_alive()`
- `_pop_damage()` / `_pop_heal()` / `pop_label()` と `AdventureConfig` の12欄（**前の回のもの**）
- `results` の5キー（`unit_id` / `amount` / `is_heal` / `is_crit` / `is_dot`）。⚠ **`is_dot` を書くのは `skill_resolver.gd` だけ**
- `EFFECT_TYPES_KNOWN` / `EFFECT_TYPES_IMPLEMENTED` / `HOSTS_KNOWN` / `EVENTS_KNOWN`（**語彙を1つも増やさない**）
- `_on_skill_effects_applied()` の表示経路（**1本のまま**）
- `parties.json` ／ `stage_order.json` の `"story"` 列 ／ `main_theme.tres`

---

## 5. 完了条件 — **ログ**（Godot の出力パネル）

> ⚠ **この章と、§9 のデータの突き合わせは `EXEC_INTERVENTION_ZIVA_CHECK.md` に切り出して Ziva に渡した**（2026-08-17）。
> **画面を使わない検証はそちらが持つ。** §6（ファイル）と §7（画面）は人間の担当のまま。
> ⚠ **件数の期待値は Ziva 側が正**（スキル **50件** ／ 通常攻撃 **19件**。下の2番は旧い 47 件のまま残してある）。

1. 戦闘を開始したとき、**赤いエラー（parse error / Invalid call）が1つも出ないこと。** 特に `_apply_heal()` の引数の数（`registry` が1つ増えている）
2. 起動時の検証で **`skills validated:` の件数が増えていること**（検証用の敵スキル3件ぶん）。⚠ **`errors` は 0 のまま。`warnings` は 1 のまま**（`skill_dbg_dot_odd` の端数。**黄1本は出るのが正解**）
3. ⚠ **`[StatusRegistry] buff の stat が10軸に無い` が出ないこと。** 出たら `_fill_buff()` の緩和が効いておらず、介入だけを持つ buff が弾かれている
4. ⚠ **`[SkillResolver] resolve() に効果が N 件来た` の警告が新たに出ないこと**（引数を足した際の渡し間違いの検出）
5. ⚠ **`[BattleUnit] 未定義のステータス軸: ` が出ないこと**（§1-2 の空キーのガードが効いていることの確認）

---

## 6. 完了条件 — **ファイル**（`user://logs/battle_last.jsonl`）

⚠ **戦闘のたびに上書きされる。読む前に別の戦闘を始めないこと。**
⚠ **画面で分かることをここに書かない。** ここに書くのは「介入点が本当に通ったか」＝**画面に出ない内部の値**だけ。

`stage_dbg_intervene` を**3波とも終わらせてから**開く。

6. **`{"ev":"intervene","kind":"death",...}` が1行出ていること。** ⚠ `unit_id` が `enemy_dbg_revive` の個体で、`detail` に戻したHPが入っていること
7. ⚠ **その直後に `status_end` が `why:"revive_clear"` で出ていること**（PLAN 14-4 の「発火 → 全消し」の順。⚠ **`intervene` より前に出ていたら順序が逆**）
8. ⚠ **同じ個体について `intervene`(death) が**2回以上出ていないこと**。** 「1回だけ」が全消しで保証されていることの確認（`counter` を足していないこと）
9. **`{"ev":"intervene","kind":"status","status":"status_dbg_dot_long","detail":"status_edbg_immune"}` が出ていること。**
   ⚠ **`status_edbg_immune` の `status_add` より後に撃った毒については、`status_dbg_dot_long` の `status_add` が1行も無いこと**（§2-7。付けさせない＝ログに出ない）。
   ⚠ **「1行も無い」を無条件で求めないこと**（**2026-08-17・実機で踏んだ**）。免疫が付く前に撃った1発は**通るのが正しい**。免疫は「付けさせない」であって「既に付いているものを剥がす」ではない。
   ⚠ **そのとき画面では毒が刻み続ける。** `enemy_dbg_immune` の `attack_interval_sec` を **0.5** にして免疫を先に付けさせてあるが、**2波に入った直後に押すと今も先を越せる。** 敵が近づいてから押すこと
10. **`{"ev":"intervene","kind":"heal",...}` が出ていること**（3波）
11. ⚠ **`heal` 行の `amount` が、同じ `cast` から出た2体ぶんで違うこと。** 低下を持つ個体のほうが小さい。⚠ **絶対値では見ない。2体の差で見る**
12. ⚠ **`damage` / `dot` / `heal` / `status_add` / `status_end` / `cast` の行の形が変わっていないこと**（`is_dot` はログに出さないまま）

---

## 7. 完了条件 — **画面**（実機で操作する）

**準備**：冒険選択 →「編成」で**検証用3体**を選ぶ → **`stage_dbg_intervene`** に入る。
⚠ `char_debug_status` のスキル選択で **`skill_dbg_dot_long`** を必ず1枠に入れる（2波の免疫の検証に要る）。

### 1波 — 復活（死亡の介入点）

13. **`enemy_dbg_revive` を倒すと、HPが0になった直後に立ち上がり、HPバーが最大の3割ほどで戻ること**
14. ⚠ **戦闘が終わらないこと。** 「ウェーブクリア」の表示が出てから復活する、が起きていないこと（**PLAN 11-1 の事故そのもの**）
15. **復活した個体をもう一度倒すと、今度は復活せずに倒れること**（「1回だけ」の確認）
16. ⚠ **復活の瞬間に1フレームだけ姿が消えることがある。** これは既知（§2-4）。**消えたまま戻らない場合だけ不具合**

### 2波 — 免疫（状態付与の介入点）

17. ⚠ **敵が近づいてくるのを待ち、F3 → `P` で `status_edbg_immune` が付いたのを見てから** `skill_dbg_dot_long`（**表示名は「長寿命DoT（30発）」。「毒への備え」ではない**）を撃つ。**紫のダメージ数値が1つも浮かばないこと**
    ⚠ **免疫が付く前に撃つと通る**（§6-9）。その1発は30秒間 2 ダメージを刻み続けるので、**先走ると「効いていない」ようにしか見えない**
18. ⚠ **F3 → `P` で状態一覧を見て、`status_dbg_dot_long` が載っていないこと**（出力パネルに出る）。⚠ **`status_dbg_immune` のほうは載っていること**（免疫そのものは付いている）
19. **通常攻撃の黄色いダメージは従来どおり出ること**（免疫がダメージまで止めていないこと）

### 3波 — 被回復増減（回復の介入点）

20. **`enemy_dbg_heal` が回復したとき、緑の数字が2つ同時に浮かび、`enemy_dbg_recv`（低下持ち）のほうが明らかに小さいこと**
21. ⚠ **`enemy_dbg_buff`（低下なし）の数字は従来どおりであること**（介入が無関係の相手にまで効いていないこと）

### 通しで見るもの

22. **僧侶の回復が緑色・通常のダメージが黄色・毒が紫のままであること**（前の回の色分けが壊れていないこと）
23. **F3 →「4」で速度8倍にしても、1波の復活が1回だけ起きること**（`_process` の走査が多重に走らないこと）
24. **`stage_dbg_condition` を1回戦い、条件バフが従来どおり効くこと**（`_fill_buff()` を触った影響が無いこと）
25. **本編のステージを1つ戦い、勝てること**（回復の引数が1つ増えた影響が無いこと）

### 7-1. ⚠ 数字の絶対値を期待値にしない

検証用キャラの `atk` は 1 だが**与ダメージは 4**（研究・装備が乗る）。**復活HPも回復量も、絶対値ではなく「戻る前との差」「2体の差」で見る。**

---

## 8. 終わったあとに足す宿題（`PROJECT_STATUS.md`）

⚠ **書き換えるかは人間の判断。** 設計役は勝手に触らない。

- ⚠ **NEW：`PLAN_SKILL_TEMPLATE.md` 11-1 は「全滅判定より先」としか書いておらず、`StatusRegistry._drop_dead_hosts()` に先に食われることに触れていない**（§1-1）。**PLAN 側の穴。** 死亡の介入点は「全滅判定より先」かつ「宿主の状態の掃除より先」の**2つ**を満たす必要がある
- ⚠ **NEW：PLAN 14-4 の「復活は『1回だけ』が全消しで自動保証される」は不正確**（**2026-08-17・実機で踏んだ**・§9-2）。保証されるのは**「付与1回につき復活1回」**であって「1戦闘に1回」ではない。**付与元がCDを回して撃ち直せば何度でも復活する。** 本編で「1戦闘に1回だけ復活するボス」を作るなら、**CDを戦闘より長くする**か、**カウンターを持たせる**（＝PLAN が「不要」と言ったもの）かの判断が要る
- ⚠ **NEW：敵の `cooldown_sec` が攻撃間隔より短いと、その敵は通常攻撃を1度もしない。** `_try_enemy_skill()` が true を返すと `_fire_basic_attack()` へ行かないため（`battle_controller.gd:531`）。**エラーは出ず「なぜか殴ってこない敵」になる。** 検証用の敵を作るときの定石として書いておく
- ⚠ **NEW：ダメージの介入点（`_step_crit_override` / `_step_reduction`）はこの回でも `pass` のまま。** 4つのうち**3つに利用者が付き、1つだけ利用者ゼロ**という状態になった。シールド・軽減・反射を書く回で埋まる
- ⚠ **NEW：`buff` の介入の欄が3つ兄弟で並んでいる**（`on_death` / `block_status` / `heal_taken_pct`）。**4つ目が来たら `intervene{}` の入れ子に畳むこと**（§3-0）
- ⚠ **NEW：効果の中の欄に「知らない欄」の検出が無い。** E26（`skill_schema.gd:363`）はスキル直下しか見ない。**`on_dead` のような typo は今も無音で無視される**（この回で E63〜E67 を足したので「介入の欄が1つも無い buff」は赤になるが、typo そのものは捕まらない）
- ⚠ **NEW：「死亡時発動」（死んだら他の効果を撃つ）はまだ書けない。** `react` に `event:died` を足す形になる（§0-1）。復活とは別の機能
- ⚠ **NEW：他人の蘇生はまだ書けない。** 死者を対象に取れないため（PLAN 14-4）。この回で書けるのは自己復活だけ
- ⚠ **NEW：死亡中もCDは回る**（既出の宿題10番と同じもの）。PLAN 14-4 は「推奨：死亡中は停止」としているが、**この回では触っていない**
- **NEW：検証用の敵3体（`enemy_dbg_revive` / `enemy_dbg_immune` / `enemy_dbg_recv`）とステージ `stage_dbg_intervene` はリリース前に消す**（宿題16番に含める）

---

## 9. データ（`.gd` を1行も触らない分）

> ⚠ **2026-08-17：この §9 は設計役が実施済み。Ziva に渡す必要は無い。**
> 当初は Ziva に切り出す前提で書いたが、`.gd` が全部入ったあとに続けて入れた。
> **以下は「何が入ったか」の記録として読むこと。** 数値（HP・割合）を調整するときの入口でもある。

⚠ **`.gd` より先にデータを入れないこと。** 先に入れると、ロード時検証が `on_death` を知らない欄として扱う。

⚠ **`.json` はタブインデント**（`stages.json` だけトップレベルが半角スペース2つ）。
⚠ **Windows の bash で `cat >>` すると追記分が CRLF になる。** 元が LF の JSON に混ざって壊れる。**追記したら改行コードを確かめること。**
⚠ **`ja.csv` は UTF-8（BOMなし）。** 編集後の再インポートは人間の作業。

### 9-1. `resources/balance/master/enemies.json` — 敵3体

`enemy_dbg_*` の既存エントリと**同じ形**で足す（`hp` は倒しやすい値、`skills` は装備枠そのもの）。

| enemy_type_id | 何のため | `skills` |
|---|---|---|
| `enemy_dbg_revive` | 復活（死亡の介入点） | `["skill_edbg_revive"]` |
| `enemy_dbg_immune` | 免疫（状態付与の介入点） | `["skill_edbg_immune"]` |
| `enemy_dbg_recv` | 被回復低下（回復の介入点） | `["skill_edbg_recv_down"]` |

### 9-2. `resources/balance/master/enemies/<enemy_type_id>/skills.json` — 3ファイル

**3つとも `target: { "team": "self" }` ／ `activation: "instant"` ／ **`cooldown_sec: 999.0`** の自己バフ1件。**

> ⚠ **2026-08-17・実機で踏んだ。当初 `cooldown_sec: 1.0` にしていて、敵が無限に復活した。**
>
> 敵は攻撃間隔（2.0秒）ごとにスキルを試し、CDが空いていれば撃つ（`battle_controller.gd:524-533`）。
> **復活 → 全消し → 次の拍で撃ち直し → また復活**、が延々続く。
>
> ⚠ **PLAN 14-4 の「全消しで『1回だけ』が自動保証される」は、「付与1回につき復活1回」の保証であって
> 「1戦闘に1回」ではない。** 付与元が撃ち直せば何度でも復活する。**PLAN の書きぶりの穴**（§8の宿題）。
>
> ⚠ **副作用がもう1つあった**：`cooldown_sec` が攻撃間隔より短いと、敵は毎拍スキルを撃って
> **通常攻撃を1度もしない**（`_try_enemy_skill()` が true を返すと `_fire_basic_attack()` へ行かない）。
>
> **999.0 にすると、射程に入った最初の1拍で1回だけ撃ち、以降は通常攻撃に回る。**
> ⚠ **復活してもCDはリセットされない**（PLAN 14-4）ので、撃ち直しは起きない。

```jsonc
// enemy_dbg_revive
{ "type": "buff", "host": "unit", "status_id": "status_edbg_revive",
  "duration_sec": 300.0, "stack": "refresh",
  "on_death": { "revive_hp_ratio": 0.3 } }

// enemy_dbg_immune
{ "type": "buff", "host": "unit", "status_id": "status_edbg_immune",
  "duration_sec": 300.0, "stack": "refresh",
  "block_status": ["status_dbg_dot_long"] }

// enemy_dbg_recv
{ "type": "buff", "host": "unit", "status_id": "status_edbg_recv_down",
  "duration_sec": 300.0, "stack": "refresh",
  "heal_taken_pct": -50 }
```

⚠ **`stat` と `value` は書かない**（この回から省ける）。⚠ **`multiplier` は書けない**（E の対象）。

### 9-3. `resources/balance/master/stages.json` — ステージ1本

```
"stage_dbg_intervene"   name_key: "ui_stage_dbg_intervene"
  wave 1 … enemy_dbg_revive ×1
  wave 2 … enemy_dbg_immune ×1
  wave 3 … enemy_dbg_heal ×1 ＋ enemy_dbg_recv ×1 ＋ enemy_dbg_buff ×1
```

⚠ **3波の3体は全部要る。** `enemy_dbg_heal` が回復役、`enemy_dbg_recv` が低下持ち、`enemy_dbg_buff` が**比較用の素の相手**（完了条件21）。

### 9-4. `resources/balance/master/stage_order.json` — `"debug"` 列に1行

⚠ **本番の `"story"` 列を触らないこと。**

### 9-5. `localization/ja.csv` — 行を足す

| キー | 内容 |
|---|---|
| `ui_stage_dbg_intervene` | ステージ名 |
| `ui_battle_enemy_dbg_revive` / `_immune` / `_recv` | 敵の名前 |
| `ui_battle_skill_edbg_revive` / `_immune` / `_recv_down` | スキル名（`name_key`） |

⚠ **状態（`status_edbg_*`）には行を足さない。** 状態のUIが無く、F3 パネルは `status_id` を生で出す（宿題15番）。

### 9-6. ⚠ Ziva に**やらせない**こと

- **`master_data_loader.gd` の `ENEMY_DIRS_OPTIONAL` に3行足す**（宿題13番）。⚠ **`.gd` なので設計役がやる。足し忘れると敵のスキルが無音で消える**
- `.gd` 全般・`parties.json`・`characters.json`
