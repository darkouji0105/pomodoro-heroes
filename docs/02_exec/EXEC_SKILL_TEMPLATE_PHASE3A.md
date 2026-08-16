# EXEC_SKILL_TEMPLATE_PHASE3A.md — 状態の器と `buff` / `dot`（段階3の前半）

決定台帳は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`（**13章・9章・19章・20章**）。
直前タスクの指示書は `docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE2.md`（段階2・完了済み）。

**この回で作るもの**：ユニット／座標／戦場に紐づく「残るもの」を持つ層と、それに乗る `buff` / `dot`。

⚠ **段階3は大きすぎるので割った**（PLAN 19章）。**購読・条件・介入点3種・パッシブ・コンボ・復活は後半。この回では作らない。**

---

## 1. 人間による決定事項（2026-08-16・**本文と矛盾する場合こちらが優先**）

### 1-1.【体制】設計役が全部書く。MiniMax（実装役）は使わない

直近8タスクと同じ。**PRE_PLAN も IMPL_LOG も作らない。**
⚠ `battle_controller.gd` は **952行**。触るのは §8 の**8箇所だけ**で、設計役が全文を書く。

### 1-2.【決定】この回のスコープは「器 ＋ `buff` / `dot` まで」

**器だけだと実機で見るものが1つも無い**（段階1と同じ「挙動不変」になる）ので、当たる効果まで入れる。
`buff` は F3 パネルの10軸に、`dot` は敵HPの継続的な減りに出る。

### 1-3.【決定】状態の器は `scripts/systems/status_registry.gd` / `class_name StatusRegistry`

`scripts/systems/` に置く。**新しいフォルダは作らない。**

⚠ **`skill_` 系の名前を付けない。** 状態はスキル以外（装備パッシブ・天候）も宿す予定で、名前が実態より狭くなる。
⚠ **名前が別系統であること自体が PLAN 7-2 の歯止めになる。** `SkillRuntime`（待ち行列）と混ぜてはいけない層なので、名前で見分けが付く形にする。

### 1-4.【決定】`dot` の端数は**切り捨て**。割り切れなければロード時に黄

`duration 5秒` × `interval 2秒` は **2回**（2.0秒・4.0秒に発火し、5.0秒で消える）。

> **発火回数 ＝ `floor(duration_sec / interval_sec)`**

**総ダメージが `multiplier × floor(duration/interval)` で暗算できる。**
⚠ 割り切れない組み合わせは `MasterDataLoader` が**黄**を出す（W10）。**無音でズレさせない。**

### 1-5.【決定】重ねがけは `stack` 欄で「独立」と「上書き」を**書き分ける**。**省略不可**

| 値 | 挙動 |
|---|---|
| `independent` | かけるたびに**別の状態が増える**。それぞれ自分の寿命で消える |
| `refresh` | 同じ状態が既にあれば、**寿命も値も新しいもので置き直す**（個数は1個のまま） |

⚠ **省略時の既定値を作らない**（`scale_from` と同じ方針・PLAN 5-2）。
既定を `independent` にすると、上書きのつもりで書き忘れたときスタックが無限に積み上がる。
既定を `refresh` にすると、独立のつもりで書き忘れたとき DoT が重ならず**ダメージが黙って半分になる**。
**どちらも実行時にエラーが出ない。書かせるのが一番安い。**

⚠ **同一性のキーは `(host_unit_id, status_id, source_unit_id)` の3つ組**（§4-4）。
**付与者が違えば別の状態。** 2人の僧侶のバフが互いを潰さない。PLAN 13-1 の「付与者ID」とも整合する。

### 1-6.【決定】検証は **Lv1 の既存2件に効果を足す**（＋チャージ用に1件）

| スキル | 誰 | 足すもの |
|---|---|---|
| `skill_power_slash` | 剣士 Lv1 | **自分に `atk` バフ 8秒**（`stack: refresh`） |
| `skill_holy_ray` | 僧侶 Lv1 | **敵に `dot` 6秒 / 2秒間隔**（`stack: independent`） |
| `skill_wide_sweep` | 剣士 Lv1 | **チャージ中だけ `def` バフ**（`until: "charge_end"`） |

**全部 Lv1。研究でレベル上限を上げずにスキル選択画面で選べる。**
⚠ **スキル件数は18件のまま。ID の新規・改名なし**（CLAUDE.md 4番の「改名するとIDの加算が黙って消える」に触れない）。

### 1-7.【決定】状態は**死亡時とウェーブ交代で全消し**。CD は現状維持

| | 扱い |
|---|---|
| **宿主が死んだ** | その宿主に付いた状態を**全部消す**（PLAN 14-4 の復活の規則と先に揃える） |
| **ウェーブ交代** | **全部消す**（待ち行列と同じ扱い） |
| **クールダウン** | ⚠ **今回は触らない。** 現状（死亡中も回る）のまま**宿題に残す** |

⚠ **CD を「死亡中は停止」に変えるのは既存の挙動変更で、状態の器とは別の変更。** 同じ回に混ぜない。

### 1-8.【決定】`until: "charge_end"` を今回入れる。`skill_end` は**器だけ**

`charge_end` は `skill_wide_sweep` で本番になる。**段階2で入れた `trigger: "charge_start"` の利用者がゼロのままにならない。**

⚠ **`until: "skill_end"` は語彙として置くが、この回では実装しない。**
剥がすのに「その発動（`cast_id`）の待ち行列が空になった」を知る必要があり、`SkillRuntime` への配線が要る。
**その配線は段階3の後半（購読）で `SkillRuntime` を触るときにまとめる。** 書いたらロード時に**黄**（W11）を出し、その効果を飛ばす。

---

## 2. 触るファイルと担当

| ファイル | 何をする | 誰が |
|---|---|---|
| `scripts/systems/status_registry.gd` | **新規**（この回の本体・§4） | AI |
| `scripts/systems/unit.gd` | 状態による補正の受け口と派生値の再計算（§5） | AI |
| `scripts/systems/skill_runtime.gd` | ⚠ **2行だけ**。器を受け取り、`_fire()` から `resolve()` へ中継する（§8-4） | AI |
| `scripts/systems/skill_resolver.gd` | `resolve()` が器を受け取る。`buff` / `dot` を当てる（§6） | AI |
| `scripts/systems/skill_schema.gd` | 語彙（`stack` / `until`）と検証 E29〜E45・W9〜W11（§7） | AI |
| `scenes/adventure/battle_controller.gd` | ⚠ **952行。触るのは8箇所だけ**（§8） | AI |
| `resources/balance/master/skills.json` | 3件に効果を足す（§9） | AI |
| `scenes/adventure/battle_debug_panel.gd` | 状態の行を1本足す（§10） | AI |
| 実機確認（§13-B） | | ⚠ **人間** |

**`.tres` も `ja.csv` も触らない。** 状態の名前は画面に出さない（F3 パネルに `status_id` をそのまま出す）。

---

## 3. 着手前に確認した実コード（2026-08-16・`grep` 済み）

| | 事実 |
|---|---|
| `unit.gd` | **185行**。`BattleUnit`。⚠ **44〜53行に「バフを入れるときはここを計算し直す関数を足すこと」と書いてある** |
| ⚠ `create()` | **78〜115行**。`max_hp` / `speed` / `attack_interval_sec` を**生成時に一度だけ**確定する。⚠ **`attack_interval_sec` の元になる base を捨てている**（104〜107行）。再計算するには保持が要る |
| `get_stat()` | **120〜124行**。⚠ **能力値を読む経路はここ1本**。F3 パネルも `SkillResolver` も全部ここを通る |
| ✅ `atk_multiplier` | **57行**。常に1.0だが `BattleFormula.damage()` まで渡っている |
| `BattleFormula.damage()` | **62〜67行**。`power × multiplier × 100 / (100 + def)`。**除算**。負の防御は0で切る |
| `skill_resolver.gd` | **467行**。`select_targets()` / `resolve()` / `fold_charge_ratio()` |
| ⚠ `resolve()` の呼び出し元 | **`skill_runtime.gd` 323行の1箇所だけ**。⚠ **引数を増やすなら今が一番安い** |
| `resolve()` が `host` を見ている場所 | **213〜216行**。`none` 以外を `push_warning` して**その効果だけ飛ばす**。⚠ **この回でここが本番になる** |
| `_apply_damage()` | **244〜295行**。⚠ **2段構え**（PLAN 11-0）。`_step_crit_override()` / `_step_reduction()` は素通しのまま |
| `skill_runtime.gd` | **348行**。`tick()` の先頭で **`_drop_dead_users()`（使用者が死んだ要素を捨てる）** |
| `skill_schema.gd` | **401行**。`EFFECT_TYPES_KNOWN` に `buff` / `dot` あり（未実装扱い）。`HOSTS_KNOWN` 5値そろい。検証は E1〜E28 / W1〜W8 |
| `battle_controller.gd` | **952行**。`_skill_runtime` の宣言64行・生成98〜99行 |
| `_process()` | **299〜347行**。`_skill_runtime.tick(delta)` は **339行**（攻撃/移動の後・勝敗判定の前） |
| `_on_charge_button_down()` | **645〜661行**。最後に `_skill_runtime.charge_start()` |
| `_on_charge_button_up()` | **664〜680行**。⚠ **`_cancel_charge()` を通さず `_charging.clear()` を直接呼んでいる** |
| `_tick_charge()` / `_cancel_charge()` | **706〜718行 / 720〜721行**。⚠ **`_cancel_charge()` は `_charging.clear()` だけ。誰がチャージしていたかを見ていない** |
| `_enter_wave_clear()` | **753〜767行**。`clear_all()` → `_reset_party_positions()` の順 |
| `_enter_victory()` / `_enter_defeat()` | **769行 / 816行**。どちらも `_cancel_charge()` と `_skill_runtime.clear_all()` |
| ⚠ `_on_retry_pressed()` | **848〜853行** → `_init_session()`（**855〜868行**）が `BattleSession` を作り直し、866行で `_skill_runtime.reset()` |
| `battle_debug_panel.gd` | **242行**。`_controller.get_session()` で取る。`_format_unit()` は **125〜143行**で `unit.get_stat()` を毎フレーム読む |
| `get_session()` | `battle_controller.gd` **125行**。デバッグパネルの唯一の入口 |
| `skills.json` | **18件**。⚠ **`buff` / `dot` / `host` / `stack` / `until` を書いた効果は1件も無い** |
| ロード時検証のログ | `[MasterDataLoader] skills validated: 18 entries, 0 errors, 0 warnings` ⚠ **これが唯一の `print`** |
| ユニットの死 | `take_damage()` の中で `hp` が 0 になるだけ。⚠ **死亡を知らせるシグナルは無い** |

### ⚠ ドキュメントと実コードのズレ（**この回では直さない。報告だけ**）

| | |
|---|---|
| `NEXT_STEPS.md` 3章「`unit.gd` 44〜53行にコメントがある」 | ✅ **正しかった**（44〜46行が該当） |
| `NEXT_STEPS.md` 3章「`skill_activation.gd` は52行」 | ✅ 正しい |
| ⚠ **PLAN 5-2 の効果の欄の表に `delivery` が無い** | 段階2で新設したのに PLAN に反映されていない（**既知の宿題2番**）。この回でも直さない |
| ⚠ **PLAN に「`resolve()` が対象IDを引数で受け取る」が書かれていない** | **既知の宿題3番**。この回で `resolve()` の引数がもう1つ増えるので、**宿題の記述を更新する必要がある**（§14） |

---

## 4. 新規：`scripts/systems/status_registry.gd`

### 4-1. 位置づけ（⚠ **PLAN 7-2 の本体**）

```
battle_controller  … 入力と表示だけ
       ↓ cast() を1回呼ぶ
SkillRuntime       … 待ち行列。寿命は「スキル発動1回ぶん」
       ↓ 効果1件ずつ
SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
       ↓ host が none 以外なら「残るもの」を登録する
StatusRegistry(ここ) … 状態。寿命は「スキルより長い」
```

⚠ **`SkillRuntime` と混ぜない。捨てる基準が正反対。**

| | 何を見て捨てるか |
|---|---|
| `SkillRuntime.tick()` | **使用者**（撃った本人）が死んだら捨てる |
| **`StatusRegistry.tick()`** | ⚠ **宿主**（付けられた側）が死んだら捨てる。**付与者の死では捨てない** |

**混ぜると、術者が死んだ瞬間に敵に付けたDoTが消える**（PLAN 7-2）。**エラーは1つも出ない。**

⚠ **`RefCounted`。ノードツリーには入れない。** `BattleController` が1体だけ持つ。

### 4-2. 状態1件の形

⚠ **持つのはIDと数字だけ**（CLAUDE.md 4番）。**マスターデータを複製しない。**

```
{
	"instance_id": int,        # 一意番号。カウンターの操作に使う
	"status_id": String,       # 同一性のキー。skills.json が書く
	"kind": String,            # KIND_BUFF / KIND_DOT
	"host": String,            # SkillSchema.HOST_UNIT / HOST_POINT / HOST_BATTLE
	"host_unit_id": String,    # host == unit のときだけ意味がある
	"host_x": float,           # host == point のときだけ意味がある
	"source_unit_id": String,  # 付与者（PLAN 13-1）
	"source_skill_id": String,
	"stack": String,           # STACK_INDEPENDENT / STACK_REFRESH
	"life": String,            # LIFE_SEC / SkillSchema.UNTIL_CHARGE_END
	"duration_sec": float,     # life == LIFE_SEC のときだけ意味がある
	"elapsed": float,          # ⚠ 時計は1本だけ（下記）
	"stat": String,            # buff
	"value": int,              # buff。⚠ int() で包む
	"damage_effect": Dictionary,   # dot が毎回 resolve() に渡す実効効果（4-7）
	"interval_sec": float,     # dot
	"fires_done": int,         # dot。今まで何発撃ったか
	"fires_total": int,        # dot。floor(duration / interval)。-1 は無制限
	"counter": int,            # 汎用カウンター（PLAN 13-1・利用者ゼロ）
}
```

> ⚠ **時計は `elapsed` の1本だけにする。寿命と周期で別々のカウントダウンを持たない。**
> 2本持つと**浮動小数の誤差が別々に積もり**、`duration 4秒` × `interval 2秒` のように
> **両方が同時に切れるはずのフレームで、最後の1発が落ちる。**
> 数字が少し減るだけなのでエラーも出ず、実機でも気づけない。
>
> - 発火するか … `elapsed >= (fires_done + 1) × interval_sec`
> - 消えるか … `elapsed >= duration_sec`
>
> **どちらも同じ1本の値から引くので、順序が入れ替わることがない。**

⚠ **`duration_sec` / `interval_sec` / `elapsed` は float のままでよい。`value` と `fires_done` / `fires_total` は `int()` で包む**（`MasterDataLoader` は数値を float で返す・CLAUDE.md 3番）。

⚠ **`source_skill_id` は持たない。** `resolve()` に渡ってくるのは効果1件ぶんで、スキルIDは含まれない。
**持たせるには `resolve()` の引数をもう1つ増やすことになるので、使う側ができるまで足さない。**

### 4-3. 公開する関数

| 関数 | 何をするか |
|---|---|
| `_init(p_session: BattleSession)` | セッションを受け取る |
| **`reset(p_session) -> void`** | ⚠ **全部捨てて、セッションを差し替える。リトライ用**（§11 の罠） |
| `add(effect, source, host_unit, session) -> bool` | 状態を1件付ける。`SkillResolver` から呼ぶ |
| `tick(delta) -> void` | 宿主の死の掃除 → 周期発火 → 寿命 → `effects_applied` を出す |
| `clear_all() -> int` | 全部捨てる。ウェーブ交代・勝敗確定 |
| `clear_for_unit(unit_id) -> int` | その宿主の状態を捨てる |
| **`end_charge(user_id) -> int`** | `life: charge_end` の状態を剥がす（§8-5） |
| `stat_mod(unit_id, stat_key) -> int` | **問い合わせ口。** そのユニットの合計補正 |
| **`query(filter: Dictionary) -> Array`** | ⚠ **問い合わせ口の本体**（4-7） |
| `count(filter) -> int` / `has(filter) -> bool` | `query()` の薄い包み |
| **`bump_counter(instance_id, delta) -> int`** | ⚠ **受け口だけ。呼び出し元ゼロ**（段階3後半の購読が使う） |
| `size() -> int` / `snapshot() -> Array` | 外から中を見る |

**シグナル**：`effects_applied(results: Array)`
⚠ **`SkillRuntime` と同じ形にする。** `battle_controller` の表示経路を1本に保つため（§8-2）。

### 4-4. `add()` — ⚠ **状態を変える前に全部の判定を終える**（CLAUDE.md 6番）

順番は**必ずこれ**。

1. `host` を読む。`unit` / `point` / `battle` 以外（`spawn` / `none`）は `push_warning` して **false を返す**（何も足さない）
2. `stack` を読む。`STACKS_KNOWN` に無ければ `push_error` して **false**
3. 寿命を読む。`duration_sec` と `until` は**排他**。どちらも無い／両方ある → `push_error` して **false**
4. `kind` ごとの欄をそろえる（`buff` は `stat` / `value`、`dot` は `damage_effect` / `interval_sec` / `fires_left`）。欠けていたら `push_error` して **false**
5. ⚠ **ここまで1つも状態を触っていないこと。** ここで初めて配列に入れる
6. `stack == refresh` なら、**同一性のキーが一致する既存を1件探して丸ごと差し替える**。無ければ新規
7. `host == unit` なら `_rebuild_unit_mods(host_unit_id)` を呼ぶ（4-5）

> ⚠ **同一性のキーは `(host_unit_id, status_id, source_unit_id)` の3つ組**（決定1-5）。
> **`status_id` だけにしないこと。** 2人の僧侶が同じバフを配ると片方が消える。

⚠ **`stack == independent` に上限を設けない**（PLAN 13-2 の「上限」は後から足せる部品）。
**上限が無い＝撃つほど積める。** これは意図通りだが、`skills.json` 側で CD と duration の関係を見ておくこと。

### 4-5. ⚠ 能力値の補正は**毎回ゼロから組み直す**（この回で一番大事）

> **`BattleUnit._stat_mods` を `+=` / `-=` で更新しない。**
> **`StatusRegistry` が自分の持つ状態から合計を組み直し、丸ごと渡す。**

```
_rebuild_unit_mods(unit_id):
	mods = {}
	自分が持つ状態のうち host == unit かつ host_unit_id == unit_id かつ kind == buff を全部足す
	unit.set_stat_mods(mods)     ← 中で refresh_derived() が走る
```

**呼ぶのは4箇所**：`add()` の最後 ／ 状態を1件消したとき ／ `clear_for_unit()` ／ `clear_all()`（全ユニットぶん）。

⚠ **差分更新にすると、剥がし忘れが「少し強いまま」として残る。エラーも出ず、F3 パネルの数字も「もっともらしい」ので気づけない。**
**組み直しなら、状態の配列が正しい限り補正は必ず正しい。ズレようがない。**

### 4-6. `tick(delta)` の中身（⚠ **順番が要件**）

```
1. 宿主の掃除
2. 時計を進める（elapsed += delta。ここ1箇所だけ）
3. 周期発火（dot）
4. 寿命が切れたものを捨てる
5. 変わったユニットの補正を組み直す
6. results があれば effects_applied を出す
```

**1. 宿主の掃除**（決定1-7）
`host == unit` で、宿主が**死んでいる**／**session に居ない**状態を捨てる。
⚠ **警告を出さない**（正常系）。⚠ **付与者は見ない。** 付与者が死んでもDoTは止まらない（PLAN 7-2）。
⚠ 死亡を知らせるシグナルが無いので毎フレーム走査する。件数は多くても数件。

**3. 周期発火**（`kind == dot`）

```
while (fires_total < 0 or fires_done < fires_total) \
		and elapsed >= float(fires_done + 1) * interval_sec:
	fires_done += 1
	発火する
```

⚠ **`while` にするのは速度8倍で1フレームに複数回跨ぐため。** `if` だと発火が落ちる。
⚠ **ループの中で `fires_done` を必ず増やすこと。** 増やさないと `interval_sec` が0のときに固まる（`interval_sec > 0` はロード時に赤・E40 で担保するが、二重に守る）。

**4. 寿命**
`life == LIFE_SEC` のものだけ `elapsed >= duration_sec` で捨てる。
`life == UNTIL_CHARGE_END` は**時間で消えない。** `end_charge()` だけが剥がす。

> ⚠ **3を4より先にやること。** `duration 4秒` × `interval 2秒` は最後の発火と寿命切れが同じフレームに来る。
> **逆順だと最後の1発が黙って消える。** 総ダメージが暗算と合わなくなる（決定1-4が壊れる）。

### 4-7. `dot` の発火は**通常のダメージ経路をそのまま通る**

```
SkillResolver.resolve({ "effects": [damage_effect] }, source_unit, _session, [host_unit_id], self)
```

⚠ **DoT 専用の式を作らない**（PLAN 11-0・式を2箇所に書かない）。
**会心もクリティカル倍率も `atk_multiplier` も、通常のスキルダメージと同じように乗る。**

⚠ `damage_effect` は `add()` の時点で組み立てて持つ。**`skills.json` に書ける欄しか含まない**（PLAN 7-3 の歯止め）。

```
{ "type": "damage", "multiplier": ..., "attack_type": ..., "scale_from": ... }
```

⚠ **`scale_from` は発火のたびに評価される。** 付与者が死んでいても `session` に残っているので能力値は読める。
**付与者が `session` から見つからない場合だけ、その状態を捨てる**（警告なし。ウェーブ交代で敵が消えた場合に来る）。

⚠ **`self`（器そのもの）を `resolve()` に渡すのは循環しない。** 渡す効果は `damage` なので、`resolve()` は器を触らない。

### 4-8. 問い合わせ口は `query()` の1本（⚠ **PLAN 13-1「DLCの幅を決めるのはここ」**）

```
query({ "host": ..., "host_unit_id": ..., "status_id": ..., "source_unit_id": ..., "kind": ... }) -> Array
```

**書いたキーだけで絞る。書かないキーは見ない。** `count()` / `has()` / `stat_mod()` はこれを使う。

⚠ **「◯◯で絞る関数」を1個ずつ増やさないこと。** 条件（段階3後半）が要求するのは
「毒が付いた敵に追加」「デバフの数だけ強く」「**自分が付けた**毒だけ強化」で、**全部この1本の引数の違いでしかない。**

### 4-9. ⚠ 今回作るが**利用者がゼロ**のもの（**段階3の後半で作り直さないこと**）

| 受け口 | いつ使われるか |
|---|---|
| `host: point`（`host_x`）／`host: battle` | **段階3の後半**（条件＝オーラ・購読＝罠）。⚠ **器が3種とも取れる形であることが PLAN 20章5番** |
| `bump_counter()` / `counter` 欄 | 同上（コンボ・N回攻撃ごと） |
| `query()` の `source_unit_id` 絞り | 同上（自分が付けた毒だけ強化） |
| `clear_for_unit()` | ⚠ **呼び出し元ゼロ。** 死亡の掃除は `tick()` の `_drop_dead_hosts()` がやる（死亡シグナルが無いため）。**死亡を知らせる仕組みが入ったらこちらに寄せる** |
| `stat_mod()` / `count()` / `has()` | 条件（段階3の後半）が使う。⚠ **`_rebuild_unit_mods()` は `stat_mod()` を使わない**（全軸を1回で組むため） |
| `SkillSchema.UNTIL_SKILL_END` | 剥がす配線が未実装（決定1-8）。**書くと黄が出てその効果は飛ぶ** |

---

## 5. `scripts/systems/unit.gd`（**185行。3箇所を触る**）

### 5-1. 補正の受け口を足す

```gdscript
# 状態による能力値の補正。⚠ StatusRegistry だけが書く。
#
# ⚠ ここを += / -= で更新しないこと。StatusRegistry が自分の持つ状態から
#   毎回ゼロから組み直したものを、丸ごと受け取る（PLAN 13-1）。
#   差分更新にすると剥がし忘れが「少し強いまま」として残り、エラーも出ず、
#   F3 パネルの数字ももっともらしいので気づけない。
var _stat_mods: Dictionary = {}
```

### 5-2. `get_stat()` を「素 ＋ 補正」にする（**120〜124行**）

⚠ **能力値を読む経路はここ1本。** ここを直せば **F3 パネルも `scale_from` も `BattleFormula` も全部バフ込みになる。** 呼び出し元を洗う必要が無い。

```gdscript
func get_stat(stat_key: String) -> int:
	if not _stats.has(stat_key):
		push_error("[BattleUnit] 未定義のステータス軸: %s (unit_id=%s)" % [stat_key, unit_id])
		return 0
	# ⚠ 0 で切る。負の防御は BattleFormula 側でも切られるが、
	#   負の atk が式に入ると表示まで意味が変わる。
	return maxi(0, int(_stats[stat_key]) + int(_stat_mods.get(stat_key, 0)))
```

### 5-3. 派生値を計算し直す関数を足す（⚠ **44〜53行のコメントが要求していたもの**）

```gdscript
func set_stat_mods(mods: Dictionary) -> void:
	_stat_mods = mods.duplicate()
	refresh_derived()


# 派生値を今の実効ステータスから計算し直す。
#
# ⚠ max_hp は計算し直さない。hp 軸のバフを禁じているため（ロード時に赤・E36）。
#   max_hp が動くと現在HPのクランプと割合計算（sort: lowest_hp / hp_ratio）が
#   同時に動く。それは別の回でやる。
# ⚠ attack_range はマスター由来で能力値に依存しないので、ここには出てこない。
func refresh_derived() -> void:
	speed = float(get_stat(GameStateKeys.STAT_SPD))
	attack_interval_sec = BattleFormula.attack_interval(
		_base_attack_interval_sec, get_stat(GameStateKeys.STAT_ATKSPD)
	)
```

### 5-4. ⚠ `create()` が base を捨てている（**104〜107行**）

`attack_interval_sec` は `atkspd` 適用済みの実効値で、**元の base はどこにも残っていない。**
再計算するには保持が要る。**フィールドを1本足し、`create()` で入れる。**

```gdscript
# マスターの attack_interval_sec（atkspd 適用前）。refresh_derived() が使う。
var _base_attack_interval_sec: float = 0.0
```

```gdscript
	unit._base_attack_interval_sec = float(p_source.get("attack_interval_sec", 0))
	unit.attack_interval_sec = BattleFormula.attack_interval(
		unit._base_attack_interval_sec,
		unit.get_stat(GameStateKeys.STAT_ATKSPD)
	)
```

⚠ **`create()` の中で `get_stat()` を呼ぶのは今と同じ**（`_stat_mods` が空なので値は変わらない）。

---

## 6. `scripts/systems/skill_resolver.gd`（**引数が1つ増える。分岐は1箇所で足す**）

### 6-1. `resolve()` の引数

```gdscript
static func resolve(
		skill_data: Dictionary, user: BattleUnit, session: BattleSession,
		target_ids: Array, registry: RefCounted
) -> Array:
```

⚠ **既定値を作らない（`null` 許容にしない）。** 許すと、渡し忘れたときに `buff` / `dot` が黙って飛ぶ。
呼び出し元は **`skill_runtime.gd` 323行の1箇所だけ**なので、増やす代償は1行。

> ⚠ **型を `StatusRegistry` と書かないこと。`RefCounted` のまま受ける。**
> `status_registry.gd` は DoT の発火で `SkillResolver.resolve()` を呼ぶ（§4-7）。
> ここで `StatusRegistry` を名指しすると**2つのファイルが相互参照になり、`Cyclic reference` のパースエラーを踏みうる**
> （`battle_formula.gd` 冒頭が「`BattleUnit` を参照しないこと」と警告しているのと同じ形）。
> ⚠ **Godot を起動できないので、踏むかどうかを確かめられない。踏みようがない形にする。**
>
> **代償は `registry.add()` が動的呼び出しになること。** 呼ぶのは `_apply_status()` の2行だけ。

⚠ **契約は変わらない**（PLAN 7-3）：**時間を持たず、次のフレームを知らず、ノードを触らない。**
器は `BattleSession` と同じく「渡される入れ物」で、`resolve()` はそこに1件登録して終わる。**時間を進めるのは器の側。**

⚠ **入口は2つのまま**（`select_targets()` / `resolve()`）。
⚠ **歯止めも無傷**：器は `skill_data` の中ではなく引数で横から渡る（`target_ids` と同じ形）。

### 6-2. `host` の分岐（**213〜216行を作り替える**）

| `host` | どうする |
|---|---|
| `none` | 今まで通り。`damage` / `heal` を当てる |
| `unit` / `point` / `battle` | **`registry.add()` に渡す**（対象ごとに1件） |
| `spawn` | `push_warning` して**その効果を飛ばす**（段階6） |

⚠ **`type: buff` / `dot` に `host: none` は書けない**（残らない状態は意味を持たない）。ロード時に赤（E29）、resolver でも `push_error` して飛ばす。
⚠ **`type: damage` / `heal` に `host` を書いた場合も赤。** 「ダメージが残る」は意味を持たない。

### 6-3. `buff` / `dot` を当てる

`EFFECT_TYPES_IMPLEMENTED` に `buff` / `dot` を足したうえで、`resolve()` の効果分岐に1本足す。

```gdscript
elif effect_type == SkillSchema.EFFECT_BUFF or effect_type == SkillSchema.EFFECT_DOT:
	for t: BattleUnit in targets:
		registry.add(effect, user, t, session)
```

⚠ **対象0体なら何も起きない。警告を出さない**（正常系・PLAN 4-2）。
⚠ **`chance` は今回も読まない**（既存の黄をそのまま残す）。
⚠ **`buff` に `multiplier` を流用しない**（PLAN 5-2）。`buff` が読むのは `stat` / `value`。

### 6-4. ⚠ チャージ倍率は `buff` の `value` に掛からない

`fold_charge_ratio()`（**428〜440行**）が触るのは `multiplier` だけ。**`value` は素通し。**

- `dot` … `multiplier` を持つので**チャージで伸びる**
- `buff` … `value` を持つので**チャージで伸びない**

⚠ **これは PLAN 5-3 の「ためてもデバフの秒数は伸びない」と同じ向きで、意図通り。**
`skill_wide_sweep` の `def` バフはチャージ時間に関係なく一定になる。

---

## 7. `scripts/systems/skill_schema.gd`（**語彙 ＋ 検証**）

### 7-1. 足す語彙

```gdscript
# --- effects[].type（段階3で当たるようになるもの） ---
const EFFECT_BUFF: String = "buff"
const EFFECT_DOT: String = "dot"
```
⚠ **`EFFECT_TYPES_KNOWN` の文字列リテラルを const に差し替える**（今は `"buff"` と直書き。2本目の一覧を作らない）。
⚠ **`EFFECT_TYPES_IMPLEMENTED` に `EFFECT_BUFF` / `EFFECT_DOT` を足す** → W4 が buff / dot に出なくなる。

```gdscript
# --- effects[].stack（重ねがけ規則・PLAN 13-2） ---
# ⚠ 省略時の既定値を作らない（決定1-5）。書き忘れが無音で挙動を変えるため。
const STACK_INDEPENDENT: String = "independent"
const STACK_REFRESH: String = "refresh"
const STACKS_KNOWN: Array = [STACK_INDEPENDENT, STACK_REFRESH]

# --- effects[].until（秒数以外の寿命・PLAN 13-3） ---
const UNTIL_CHARGE_END: String = "charge_end"
const UNTIL_SKILL_END: String = "skill_end"   # 器だけ。剥がす配線は段階3の後半
const UNTILS_KNOWN: Array = [UNTIL_CHARGE_END, UNTIL_SKILL_END]
```

### 7-2. 足す検証（**赤**）

⚠ **メッセージには必ず `skill_id` と `effects[n]` を含める**（既存の `_err` / `_warn` がやっている）。

| # | 条件 |
|---|---|
| **E29** | `type` が `buff` / `dot` なのに `host` が無い、または `host: none` |
| **E30** | `type` が `damage` / `heal` なのに `host` を書いている（残らないものに宿主は無い） |
| **E31** | `type` が `buff` / `dot` で、`duration_sec` も `until` も無い |
| **E32** | `duration_sec` と `until` の両方がある（**排他**） |
| **E33** | `duration_sec` が正の数値でない |
| **E34** | `until` が `UNTILS_KNOWN` に無い |
| **E35** | `stack` が無い、または `STACKS_KNOWN` に無い（⚠ **省略不可**・決定1-5） |
| **E36** | `status_id` が無い、または空文字 |
| **E37** | `type: buff` の `stat` が10軸（`GameManager.get_stat_keys()`）に無い |
| **E38** | ⚠ `type: buff` の `stat` が `hp`（`max_hp` を再計算しないため禁止・§5-3） |
| **E39** | `type: buff` の `value` が整数でない（`0` も禁止＝何も起きない状態を書かせない） |
| **E40** | `type: dot` の `interval_sec` が無い、または正の数値でない |
| **E41** | `type: dot` の `multiplier` が数値でない |
| **E42** | `type: dot` に `scale_from` が無い（`damage` と同じ扱い） |
| **E43** | `type: dot` の `attack_type` が `attack_types_known()` に無い |
| **E44** | ⚠ `activation` が `charge` でないのに `until: "charge_end"` を書いている |
| **E45** | ⚠ `activation` が `charge` でないのに `trigger: "charge_start"` を書いている |

> ⚠ **E44 / E45 は「無音で消えない・無音で発火しない」を防ぐもの。**
> `until: "charge_end"` は剥がす経路がチャージ終了しか無いので、instant スキルに書くと**永久に残る。**
> `trigger: "charge_start"` は `charge_start()` からしか流れないので、instant スキルに書くと**一度も発火しない。**
>
> ⚠ **E45 は段階2で開いたままだった穴**（段階2の完了条件には入っていない）。**同じファイルの同じ関数なので、この回で塞ぐ。**
> ⚠ **これはスコープ外の「ついでに」に見えるので、不要なら §1 に【却下】として書き足すこと。**

### 7-3. 足す検証（**黄**）

| # | 条件 | 文面の趣旨 |
|---|---|---|
| **W9** | `host` が `point` / `battle` | 器には載るが、**参照する仕組み（条件・購読）は段階3の後半。今は何も起きない** |
| **W10** | `duration_sec` が `interval_sec` で割り切れない | **端数は切り捨て。発火は `floor(duration/interval)` 回**（決定1-4） |
| **W11** | `until: "skill_end"` | **今回は未実装。その効果は飛ばされる**（決定1-8） |

### 7-4. 直す既存の検証

| | どう変える |
|---|---|
| **W4**（`type` が未実装） | `EFFECT_TYPES_IMPLEMENTED` に `buff` / `dot` が入るので**自動的に出なくなる。文面は触らない** |
| **W6**（`host != none` は段階3） | ⚠ **文面を変える。** `unit` は実装済み。`point` / `battle` は W9、`spawn` は「段階6。飛ばされる」 |

⚠ **W9 / W10 / W11 は §9 の3件のデータでは1つも出ない**（`point` / `battle` を書かず、`6 ÷ 2 = 3` は割り切れ、`skill_end` を書かないため）。
**ロードログの `0 warnings` は保たれる**（§13-A）。

---

## 8. `scenes/adventure/battle_controller.gd`（⚠ **952行。触るのは8箇所だけ**）

### 8-1. 宣言（**64行の下**）

```gdscript
# 状態の器（段階3）。buff / dot / 罠を持つ。
# ⚠ SkillRuntime と混ぜないこと。捨てる基準が正反対（PLAN 7-2）。
var _status: StatusRegistry = null
```

### 8-2. 生成（**98〜99行を書き替える**）

⚠ **器を先に作ること。** `SkillRuntime` が器を引数に取るようになる（§8-4）。

```gdscript
	_status = StatusRegistry.new(_session)
	_status.effects_applied.connect(_on_skill_effects_applied)

	_skill_runtime = SkillRuntime.new(_session, _status)
	_skill_runtime.effects_applied.connect(_on_skill_effects_applied)
```

⚠ **`_skill_runtime` と同じシグナルに繋ぐ。** DoT のダメージ表示が `_pop_damage` の1本を通る。
**表示の経路を2本にしないこと。**

### 8-3. `_process()` に tick を1行（**339行の直後**）

```gdscript
	_skill_runtime.tick(delta)

	# 3-2. 状態（buff の寿命・dot の周期発火）
	#
	# ⚠ 待ち行列の直後・勝敗判定の前。DoT の止めの一撃が同じフレームの
	#   勝敗判定に反映される。後ろに置くと「死んでいるのに1フレーム戦闘が続く」。
	# ⚠ 状態ガードの内側であること。結果画面やウェーブ間で DoT を進めない。
	# ⚠ バフの効き始めは tick の位置と関係ない。付いた瞬間に set_stat_mods() が
	#   走るので、同じフレームの続きから効く。ここで効くのは寿命と周期だけ。
	_status.tick(delta)
```

### 8-4. 器を `SkillRuntime` に持たせる（⚠ **`_fire_skill()` は触らない**）

`resolve()` を呼ぶのは `SkillRuntime._fire()`（`skill_runtime.gd` 323行）なので、器は `SkillRuntime` が持つ。
**`_init` / `reset()` の引数に足す**か、**`cast()` の引数に足す**かの2択。

> **決定：`SkillRuntime._init(p_session, p_registry)` と `reset(p_session, p_registry)` で持たせる。**
> `cast()` / `charge_start()` / `tick()` / `notify_event()` の**4つの入口すべてが `_fire()` を通る**（PLAN 6-5）。
> **`_fire()` が引数なしで読めるところに置かないと、発火経路ごとに器を運ぶことになり、「経路は1本」という決定が形骸化する。**

**`skill_runtime.gd` の変更は2行だけ**（`var _registry` の保持と、323行の `resolve()` に渡す引数）。
**`battle_controller.gd` 側は §8-2 と §8-8 の2箇所だけ**で、`_fire_skill()`（608〜631行）は**1行も触らない。**

### 8-5. チャージ終了で剥がす（**2箇所**・決定1-8）

**`_cancel_charge()`（720〜721行）を書き替える。**

```gdscript
# チャージを取り消す。⚠ until: "charge_end" の状態もここで剥がす。
# ⚠ _charging を clear する前に誰がチャージしていたかを読むこと。
#   clear してからでは剥がす相手が分からず、状態が永久に残る（エラーは出ない）。
func _cancel_charge() -> void:
	var entry: Dictionary = _charging.get("entry", {})
	var user: BattleUnit = entry.get("user", null)
	if user != null and _status != null:
		_status.end_charge(user.unit_id)
	_charging.clear()
```

⚠ **`_tick_charge()` / `_enter_victory()` / `_enter_defeat()` の3つの呼び出し元がこれ1本でまとめて片付く。**

**`_on_charge_button_up()`（664〜680行）は `_cancel_charge()` を通っていない。** `_charging.clear()` の直後に1行足す。

```gdscript
	_charging.clear()
	# ⚠ _fire_skill() より前に剥がす。チャージ中だけの状態が、
	#   チャージ後の一撃に乗らないようにする。
	if user != null:
		_status.end_charge(user.unit_id)
```

⚠ **`_cancel_charge()` を呼ぶ形に統一しない。** `_on_charge_button_up()` は取り消しではなく成立なので、
まとめると「取り消し」の意味が2つになる（1章の病気）。

### 8-6. ウェーブ交代（**763行の隣**）

```gdscript
	_skill_runtime.clear_all()
	# ⚠ 状態もここで捨てる（決定1-7）。待ち行列と同じく _reset_party_positions() より前。
	_status.clear_all()
	_reset_party_positions()
```

### 8-7. 勝敗確定（**775行 / 821行の隣**）

`_enter_victory()` / `_enter_defeat()` の `_skill_runtime.clear_all()` の隣に `_status.clear_all()`。
⚠ **理由は待ち行列と同じ**：結果画面が出たあとに DoT のダメージ数値が出ないようにする。

### 8-8. リトライ（**866行**）

866行の `_skill_runtime.reset(_session)` を**2行に置き換える。**

```gdscript
	# ⚠ 器を先に差し替える。忘れると、リトライ後の状態が前の戦闘のユニットを
	#   宿主に持ち、補正の組み直しが空振りする。エラーは1つも出ない。
	_status.reset(_session)
	_skill_runtime.reset(_session, _status)
```

⚠ **順番が要件。** 器を先に差し替えないと、`SkillRuntime` に**古い器を渡すことになる。**

### 8-9. デバッグパネルの入口（**125行の `get_session()` の隣**）

```gdscript
func get_status_registry() -> StatusRegistry:
	return _status
```

⚠ **検証用。リリース前に消すもの**（§14 の宿題）。

---

## 9. `resources/balance/master/skills.json`（**3件に効果を足す**）

⚠ **インデントはタブ。** ⚠ **スキルIDの新規・改名なし。18件のまま。**
⚠ **数値は検証で見えることを優先した暫定値。バランス調整は宿題**（既存の「12スキルのバランス調整」と同じ枠）。

### 9-1. `skill_power_slash`（剣士 Lv1・`atk` バフ）

`effects[]` の**末尾**に足す。

```json
{
	"type": "buff",
	"host": "unit",
	"target": { "team": "self" },
	"status_id": "status_power_slash_atk_up",
	"stat": "atk",
	"value": 6,
	"duration_sec": 8.0,
	"stack": "refresh"
}
```

⚠ **`target` の上書きが要る。** スキル本体の `target` は `team: enemy` なので、書かないと敵にバフが付く。
⚠ **`team: self` は `mode` / `sort` / `count` を書けない**（E10）。
⚠ **`stack: refresh`。** CD 6秒 / duration 8秒なので、撃ち続けても**1本のまま寿命が延びる**。
Lv1 の `atk` は 14〜18 なので、**F3 パネルで `atk 16` → `atk 22` に見える。**

### 9-2. `skill_holy_ray`（僧侶 Lv1・`dot`）

```json
{
	"type": "dot",
	"host": "unit",
	"delivery": "magic",
	"status_id": "status_holy_burn",
	"multiplier": 0.3,
	"attack_type": "magic",
	"scale_from": "mag",
	"duration_sec": 6.0,
	"interval_sec": 2.0,
	"stack": "independent"
}
```

⚠ **`6 ÷ 2 = 3` は割り切れるので W10 は出ない。発火は3回**（2.0 / 4.0 / 6.0 秒）。
⚠ **4-6 の順番（発火 → 寿命）が守られていないと、6.0秒の3発目が消える。** ここが実機で効く。
⚠ `skill_holy_ray` の `target` は `sort: all`（敵全体）なので、**DoT も敵全体に付く。**
⚠ **`stack: independent`。** CD 12秒 / duration 6秒なので普通は重ならない。
**重なりを見るには F3 の `S`（CDリセット）で2連続撃つ**（§13-B）。

### 9-3. `skill_wide_sweep`（剣士 Lv1・チャージ中の `def` バフ）

```json
{
	"type": "buff",
	"host": "unit",
	"trigger": "charge_start",
	"target": { "team": "self" },
	"status_id": "status_wide_sweep_guard",
	"stat": "def",
	"value": 20,
	"until": "charge_end",
	"stack": "refresh"
}
```

⚠ **`activation: charge` のスキルなので E44 / E45 に当たらない。**
⚠ **`duration_sec` を書かないこと**（`until` と排他・E32）。
Lv1 の `def` は 3〜6。`BattleFormula.damage()` は `× 100 / (100 + def)` なので、
**通るダメージが約96% → 約79% に落ちる。** ボタンを押しっぱなしにしている間だけ。

---

## 10. `scenes/adventure/battle_debug_panel.gd`（**状態の行を1本足す**）

⚠ **状態は画面に何も出ない。** アイコンもラベルも無いので、
**「黙って剥がれた」「二重に付いた」「消えない」が実機でも見えない。**

`_format_unit()`（**125〜143行**）が返す2行のあとに、**状態がある行だけ**3行目を足す。

```
    状態: status_holy_burn (4.0s/2発) status_holy_burn (6.0s/3発)
```

- 取得は `_controller.get_status_registry().query({ "host": "unit", "host_unit_id": unit.unit_id })`
- **状態が0件のユニットには行を出さない**（毎フレーム全ユニットに空行が出ると読めなくなる）
- `until` 系は秒数の代わりに `(until:charge_end)` と出す
- ⚠ **同じ `status_id` を「x2」とまとめない。1件ずつ並べる。**
  独立スタックは**それぞれ別の寿命を持つ**のが要点で、まとめると残り秒数が1つしか出せず、
  **「本当に2本あるのか、1本を二重に数えているのか」が区別できない**
- ⚠ **`status_id` をそのまま出す。翻訳キーを引かない**（`ja.csv` を触らない・検証用）

⚠ **`remove_child()` してから `queue_free()`** の規則（CLAUDE.md 5番）はここには関係しない。
**このパネルは Label のテキストを毎フレーム差し替えているだけで、ノードを作り直していない。**

---

## 11. ⚠ この回で事故りそうな点（**名指し**）

| # | 事故 | 何が起きるか |
|---|---|---|
| **1** | ⚠ **器と待ち行列を混ぜる**（PLAN 7-2） | **術者が死んだ瞬間に、敵に付けたDoTが消える。** `StatusRegistry.tick()` は**宿主**を見る。`SkillRuntime.tick()` の `_drop_dead_users()`（**使用者**を見る）をコピーしない |
| **2** | ⚠ **補正を差分更新する** | 剥がし忘れが「少し強いまま」残る。**エラーが出ず、数字ももっともらしい。**§4-5 の組み直しを崩さない |
| **3** | ⚠ **`stack` の同一性を `status_id` だけで見る** | 2人の僧侶が同じバフを配ると片方が消える。**キーは3つ組**（決定1-5） |
| **4** | ⚠ **周期発火より先に寿命を判定する** | **最後の1発が黙って消える。** 総ダメージが暗算と合わなくなる（§4-6） |
| **5** | ⚠ **`create()` が base を捨てている**（`unit.gd` 104〜107行） | `_base_attack_interval_sec` を足さないと、`atkspd` バフを付けるたびに攻撃間隔が**さらに割られて累積で速くなる**（§5-4） |
| **6** | ⚠ **リトライで `BattleSession` が作り直される**（`_init_session()`） | `_status.reset()` を忘れると、状態が前の戦闘のユニットを宿主に持つ。**エラーは1つも出ない**（§8-8） |
| **7** | ⚠ **`_cancel_charge()` が `_charging.clear()` を先にやる** | 剥がす相手が分からなくなり、`until: "charge_end"` の状態が**永久に残る**（§8-5） |
| **8** | ⚠ **`_on_charge_button_up()` が `_cancel_charge()` を通っていない** | チャージを**成立**させたときだけ剥がし漏れる。**取り消したときは消えるので、余計に気づきにくい**（§8-5） |
| **9** | ⚠ **ダメージの不変条件**（PLAN 11-0） | DoT 専用の式を書かない。`_apply_damage()` の2段構えをそのまま通す（§4-7）。**数値の確定は1回だけ** |
| **10** | ⚠ **正常系に警告を付ける** | 対象0体・宿主の死・ウェーブ交代の全消しは**全部正常系。警告を出さない**（出力パネルが埋まると本物の異常が見えなくなる） |
| **11** | ⚠ **`int()` の包み忘れ**（CLAUDE.md 3番） | `value` と `fires_left` は `int()`。`duration_sec` / `interval_sec` は float のままでよい |
| **12** | ⚠ **`while` で `fires_left` を減らし忘れる** | `interval_sec` が0のときに固まる。E40 が赤で守るが、二重に守る（§4-6） |
| **13** | **編集したら `grep` で当たったことを確認する**（CLAUDE.md 2番） | 「戦闘だけ反映されない」で1タスク溶かした事故がある。**この回も戦闘の中心を触る**（§12） |

---

## 12. 編集後に必ず走らせる `grep`（**0件でないこと**）

```
grep -n "class_name StatusRegistry"        scripts/systems/status_registry.gd
grep -n "_stat_mods"                       scripts/systems/unit.gd
grep -n "_base_attack_interval_sec"        scripts/systems/unit.gd
grep -n "func refresh_derived"             scripts/systems/unit.gd
grep -n "registry.add"                     scripts/systems/skill_resolver.gd
grep -n "_registry"                        scripts/systems/skill_runtime.gd
grep -n "STACK_INDEPENDENT\|UNTIL_CHARGE_END" scripts/systems/skill_schema.gd
grep -n "_status.tick\|_status.clear_all\|_status.reset\|end_charge" scenes/adventure/battle_controller.gd
grep -n "get_status_registry"              scenes/adventure/battle_debug_panel.gd
grep -n "\"type\": \"buff\"\|\"type\": \"dot\"" resources/balance/master/skills.json
```

⚠ **`StatusRegistry` の呼び出し元が `battle_controller.gd` と `skill_resolver.gd` と `skill_runtime.gd` の3つ以外に増えていないことも確認する。**

---

## 13. 完了条件

⚠ **同じことを2箇所に書かない。** ログ・ファイル・画面で分ける。

### A章：ログとファイル（**コードを読めば分かる／起動すれば出る**）

| # | 条件 |
|---|---|
| **A-1** | タイトルの「つづきから」で `[MasterDataLoader] skills validated: **18 entries, 0 errors, 0 warnings**` が出る。⚠ **件数・赤・黄の3つとも段階2から変わらない**（§7-4） |
| **A-2** | `scripts/systems/status_registry.gd` が存在し、`class_name StatusRegistry` で `RefCounted` を継承している |
| **A-3** | `StatusRegistry` の `tick()` が **宿主**の生死だけを見て捨てている。**付与者（`source_unit_id`）の生死で捨てる行が1つも無い**（§11-1） |
| **A-4** | `_stat_mods` を `+=` / `-=` する行が1つも無い。書くのは `set_stat_mods()` の1本だけで、その呼び出し元は `StatusRegistry._rebuild_unit_mods()` の1箇所（§4-5） |
| **A-5** | `StatusRegistry.tick()` の中で、**周期発火が寿命判定より先**に書かれている（§4-6） |
| **A-6** | `SkillResolver` に DoT 専用のダメージ計算が1行も無い。`_apply_damage()` を通っている（§4-7） |
| **A-7** | `SkillResolver.resolve()` の呼び出し元が `skill_runtime.gd` の1箇所と `status_registry.gd` の1箇所の**計2箇所**である |
| **A-8** | `skills.json` が **18件**のまま。`skill_id` の追加・改名・削除が無い |
| **A-9** | §12 の `grep` が**全部0件でない** |

### B章：画面（⚠ **人間が実機で見る**）

**準備**：ギルドのスキル選択画面で、剣士に `skill_power_slash` と `skill_wide_sweep`、僧侶に `skill_holy_ray` を付ける。戦闘に入って `F3`。

| # | 見るもの |
|---|---|
| **B-1** | **`skill_power_slash` を撃つ** → F3 の剣士の行で `atk` が **+6 された値**に変わり、3行目に `status_power_slash_atk_up (8.0s)` が出る。**8秒で消え、`atk` が元に戻る** |
| **B-2** | **B-1 の残り時間が4秒くらいのところで、`S`（CDリセット）を押してもう一度撃つ** → 状態は**1本のまま**で、残り秒数が **8.0 に戻る**（`stack: refresh`） |
| **B-3** | **`skill_holy_ray` を撃つ** → 敵**全員**の3行目に `status_holy_burn` が出て、**2秒ごとに3回**ダメージが跳ぶ。**3回目のあとに状態が消える**（⚠ **3回目が出ないなら §4-6 の順番が逆**） |
| **B-4** | **B-3 の途中で `S` を押して `skill_holy_ray` をもう一度撃つ** → 同じ敵の3行目に `status_holy_burn` が**2件並び、残り秒数がそれぞれ違う**。ダメージも2回ずつ跳ぶ（`stack: independent`） |
| **B-5** | **`skill_wide_sweep` のボタンを押しっぱなしにする** → 押している間だけ剣士の `def` が **+20** になり、3行目に `status_wide_sweep_guard (until:charge_end)` が出る。**指を離すと消える** |
| **B-6** | **B-5 で押している途中に `L`（敵全滅）** → チャージが取り消され、`status_wide_sweep_guard` も**消える**（`def` が元に戻る）。⚠ **残っていたら §8-5 の剥がし漏れ** |
| **B-7** | ⚠ **`skill_holy_ray` の DoT が付いた敵が残っている状態で、僧侶を `J` / `M` で殺す** → **DoT は止まらず、最後まで敵HPを削る**（⚠ **止まったら §11-1 の混同**） |
| **B-8** | ⚠ **DoT が付いた敵が残ったままウェーブをクリアする** → 次のウェーブに移った瞬間に**状態が全部消えている**（3行目が出ない） |
| **B-9** | ⚠ **`skill_power_slash` のバフが乗った状態で `B`（強制敗北）→「もう一度」** → リトライ後の剣士の `atk` が**素の値に戻っている**（⚠ **バフが残っていたら §8-8 のリセット漏れ**） |
| **B-10** | **`skill_wide_sweep` をジャストで撃つ** → 倍率のボーナスは今まで通り効く。⚠ **`def` バフの値はチャージ時間で変わらない**（§6-4） |
| **B-11** | **DoT が敵に止めを刺す** → その場でウェーブが進む。⚠ **「HP0なのに1フレーム戦闘が続く」が起きない**（§8-3） |

### ⚠ B章に入れないもの（**UIから到達できない／将来コードを変えたときに見る項目**）

| | いつ見るか |
|---|---|
| `host: point` / `host: battle` の状態が正しく紐づくか | **段階3の後半**（条件・購読が入ったとき）。**今は `skills.json` に1件も無い** |
| `bump_counter()` が正しく数えるか | 同上（呼び出し元がゼロ） |
| `query()` の `source_unit_id` 絞り | 同上 |
| `until: "skill_end"` | **剥がす配線が無い**（決定1-8）。書くと黄が出てその効果が飛ぶ |
| W9 / W10 / W11 の黄が出るか | §9 の3件では出ない。**将来 `point` を書く回・割り切れない `dot` を書く回に見る** |

---

## 14. 増える宿題（**`PROJECT_STATUS.md` に足す**）

| # | 宿題 |
|---|---|
| **1** | ⚠ **`until: "skill_end"` が未実装**（語彙と黄だけ）。剥がすには `SkillRuntime` に「その `cast_id` の待ち行列が空か」を聞く配線が要る。**段階3の後半で `SkillRuntime` を触るときにまとめる**（決定1-8） |
| **2** | ⚠ **`type: buff` の `stat` に `hp` を書けない**（E38）。`max_hp` を動かすと、現在HPのクランプと `sort: lowest_hp` / `hp_ratio` が同時に動く。**最大HPバフを入れる回で解く** |
| **3** | ⚠ **`stack` の5部品のうち4つが未実装**（上限・消え方・再付与・閾値。PLAN 13-2）。**`independent` に上限が無いので、CD より duration が長いスキルは無限に積める** |
| **4** | ⚠ **状態のUIが無い**（F3 パネルの3行目だけ）。**独立スタックはUIが先に音を上げる**（PLAN 13-2）。画面に出す回で決める |
| **5** | ⚠ **PLAN 5-2 の効果の欄の表に `stack` / `status_id` / `until` / `host` の必須条件が無い。** `delivery` が無いのと同じ穴（**既存の宿題2番に合流**） |
| **6** | ⚠ **既存の宿題3番の記述を更新する。** `resolve()` の引数は `(skill_data, user, session, target_ids, **registry**)` の5つになった |
| **7** | ⚠ **`get_status_registry()` は検証用。** デバッグパネルと一緒にリリース前に消す（**既存の宿題11番に合流**） |
| **8** | ⚠ **`skill_power_slash` / `skill_holy_ray` / `skill_wide_sweep` の新しい数値は暫定**（`value: 6` / `multiplier: 0.3` / `value: 20`）。**既存の「12スキルのバランス調整」に合流** |
| **9** | **死亡中にCDが回る**（決定1-7 で今回は触らないと決めた）。PLAN 14-4 の推奨は「停止」 |
| **10** | ⚠ **E45（instant スキルに `trigger: "charge_start"`）は段階2で開いたままだった穴。** この回で塞ぐ（§7-2） |
| **11** | ⚠ **`SkillResolver.resolve()` の `registry` が `RefCounted` 型**（相互参照を避けるため・§6-1）。**`add()` の呼び違いを静的に捕まえられない。** 状態を作る経路が増えるときに見直す |
| **12** | **`unit_id` からユニットを引く `_find_unit()` が3ファイルに同じ形で3本ある**（`skill_resolver` / `skill_runtime` / `status_registry`）。`BattleSession` に寄せるかは別途 |

---

## 15. この回でやらないこと

- **購読**（10章）・**条件**（毎フレーム評価）・**回復/状態付与/死亡の介入点**（11-1）・**パッシブ**・**コンボ**・**復活**
- **変数表の戦闘/状態の群**（`elapsed_sec` / `stack:<id>` / `combo_count`）
- ⚠ **横断ルール「反応から生まれた行動は、さらなる反応を生まない」**（10-2）。**購読の初回実装に含める。この回では購読を作らないのでまだ来ない**
- **`dispel` / `cancel`**（`cancel_by_delivery()` の呼び出し元はゼロのまま）
- **`mode: area`**（段階4）／**`phases[]` / `recast`**（段階5）／**`spawn`**（段階6）
- **アニメーション本体**（`event:◯◯` の合図を出す側は今回も居ない）
- **`scale_from` に積を書けるようにすること**（器の穴。PLAN 側で決める）
- **`target.range`**（座標定数の回）
- **通常攻撃を `effects[]` に乗せること**（PLAN 21章の担当外）
- **クールダウンの挙動変更**（決定1-7）

---

## 16. Git

EXEC を書き終えたあとのコミット。⚠ **ハッシュはコミット後に `PROJECT_STATUS.md` の Git章の表へ追記する。**

```
docs(skill): 段階3前半の EXEC を起こす（状態の器と buff/dot）
```
